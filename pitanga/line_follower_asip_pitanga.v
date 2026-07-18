// =============================================================================================
// Arquivo único mesclado para simulação no Sistema de Emulação Pitanga (In-Place) - S-Board
// Contém: line_follower_asip_top (top-level) + pc_asip + controle_asip + io_asip + ula_asip
//         + rom_asip + banco_reg_asip
// Gerado a partir dos módulos originais já revisados e corrigidos (LOADI absoluto, máscara de
// sensores, alternância do modo de busca, e mapeamento direita/esquerda ajustado à fiação real).
// =============================================================================================

// ---------------------------------------------------------------------------------------------
// Módulo original: line_follower_asip_top.v
// ---------------------------------------------------------------------------------------------
module line_follower_asip_top (
	// === Entradas de Controle Global:
	input wire clk,
	input wire reset,
	
	// === Entrada dos Sensores:
	input wire [1:0] sensores_in,								// Ligados diretamente aos pinos de entrada dos dois sensores TCRT5000 (Esquerda e Direita).
	
	// === Saída dos Motores:
	output wire [3:0] motores_out								// igados aos pinos de saída que vão para a Ponte H L9110S.
	);

	 
	 
	// ===============================================
	// Fios de Interconexão do DataPath (Barramentos):
	// ===============================================
		
		// === Barramento de Instrução (16 bits):
		wire [15:0] instrucao;																	// Conecta a saída de dados da 'rom_asip' à entrada da 'controle_asip' e aos seletores de endereço do 'banco_reg_asip'.
		
		// === Sinais de Controle (1 bit, exceto ula_op com 2 bits):
		wire reg_escrever;																		// Liga/desliga escrita no banco.
		wire mem_ler;																				// Avisa o I/O para ler.
		wire mem_escrever;																		// Avisa o I/O para escrever.
		wire ula_src;																				// Seletor do Mux da ULA.
		wire mem_to_reg;																			// Seletor do Mux do Banco.
		wire branch;																				// Avisa que é uma instrução de desvio condicional.
		wire [1:0] ula_op;																		// Diz a ULA qual conta fazer.
		wire ula_zera_a;																			// [CORREÇÃO] Ativado durante o LOADI para zerar a entrada 'a' da ULA (ver 'entrada_a_ula' abaixo).
		
		// === Barramentos de Dados (8 bits):
		wire [7:0] pc_atual;																		// Saída do PC que vai para a ROM.
		wire [7:0] dado_reg_a;																	// 1/2 Dado de 8 bits que sai do Banco de Registradores.
		wire [7:0] dado_reg_b;																	// 2/2 Dado de 8 bits que sai do Banco de Registradores.
		wire [7:0] resultado_ula;																// O resultado da conta feita pela ULA.
		wire [7:0] dado_lido_io; 																// O dado dos sensores vindo do módulo de I/O.
		wire [7:0] entrada_a_ula;																// [CORREÇÃO] O dado final que vai entrar na porta A da ULA (depois de passar pelo Mux do LOADI).
		wire [7:0] entrada_b_ula;																// O dado final que vai entrar na porta B da ULA (depois de passar pelo Mux).
		wire [7:0] dado_escrever_banco;														// O dado final que vai ser gravado no Banco de Registradores (depois de passar pelo Mux).
		wire [7:0] proximo_pc;																	// O endereço calculado que vai entrar na entrada do PC para o próximo ciclo.
		
		// === Sinais de Status (1 bit):
		wire flag_zero;																			// Saída da ULA indicando se a subtração deu zero.
		wire tomar_desvio;																		// O resultado do AND entre o 'branch' e 'flag_zero'. 
		
	
	
	// ======================================
	// Multiplexadores e Porta AND do Desvio:
	// ======================================
		
		// MUX da ULA (controlado por 'ula_src'):
		assign entrada_b_ula = (ula_src == 1'b1) ? instrucao[7:0] : dado_reg_b;						// Se 'ula_src' for 1, a entrada B da ULA recebe o valor imediato (os 8 bits finais da instrução: 'instrucao[7:0]'). Se for 0, recebe o dado lido do registrador ('dado_reg_b').
		
		// [CORREÇÃO] MUX da entrada A da ULA (controlado por 'ula_zera_a'):
		assign entrada_a_ula = (ula_zera_a == 1'b1) ? 8'b00000000 : dado_reg_a;						// Se 'ula_zera_a' for 1 (só acontece no LOADI), a entrada A da ULA é forçada a zero, então 'result' = 0 + imediato = imediato puro. Se for 0, a entrada A recebe normalmente o dado do registrador de destino ('dado_reg_a'), preservando o comportamento acumulativo do ADD/SUB/AND/XOR.
		
		// MUX do Banco de Reg (controlado por mem_to_reg):
		assign dado_escrever_banco = (mem_to_reg == 1'b1) ? dado_lido_io : resultado_ula;		// Se 'mem_to_reg' for 1, o dado a ser salvo vem do módulo de I/O ('dado_lido_io' => leitura do sensor). Se for 0, vem do resultado da ULA ('resultado_ula').
		
		// MUX do PC (Somador de +1 integrado):
		assign proximo_pc = (tomar_desvio == 1'b1) ? instrucao[7:0] : (pc_atual + 8'd1);			// O 'proximo_pc' dita para onde o robô vai na próxima borda de clock. Se o 'tomar_desvio' for verdadeiro, o PC deve carregar o endereço do salto (que está na instrução). Caso contrário, o PC deve apenas somar 1 ao endereço atual (pc_atual + 1) para ler a próxima linha de código da ROM.
		
		// Porta AND do Desvio Condicional:
		assign tomar_desvio = branch & flag_zero;
	
	
	
	// =========================
	// Instanciação dos Módulos:
	// =========================
	
		// PC - Contador de Programa:
		pc_asip PC (
			.clk(clk),
			.reset(reset),
			.pc_in(proximo_pc),
			.pc_out(pc_atual)
		);
		
		// ROM - Memória de Instruçao:
		rom_asip ROM (
			.endereco(pc_atual),
			.instrucao(instrucao)
		);
		
		// CTRL - Unidade de Controle:
		controle_asip CTRL (
			.opcode(instrucao[15:12]),
			.reg_escrever(reg_escrever),
			.ula_op(ula_op),
			.mem_ler(mem_ler),
			.mem_escrever(mem_escrever),
			.ula_src(ula_src),													
			.mem_to_reg(mem_to_reg),
			.branch(branch),
			.ula_zera_a(ula_zera_a)
		);
		
		// REG - Memória de Curto Prazo:
		banco_reg_asip REG (
			.clk(clk),
			.reset(reset),
			.reg_write(reg_escrever),
         .end_leitura_1(instrucao[11:10]),   		// Reg. de Destino (leitura do operando A)
			.end_leitura_2(instrucao[9:8]),     		// Reg. de Origem (leitura do operando B)
			.end_escrita(instrucao[11:10]),     		// Reg. de Destino para a escrita do resultado
			.dado_escrita(dado_escrever_banco), 		// Vem da saída do MUX de escrita do Banco
			.dado_lido_1(dado_reg_a),           		// Alimenta a entrada A da ULA
			.dado_lido_2(dado_reg_b)            		// Alimenta o MUX de entrada B da ULA
		);
		
		// ULA - Unidade Lógica Aritmética:
		ula_asip ULA (
			.a(entrada_a_ula),            				// [CORREÇÃO] Antes conectado direto a 'dado_reg_a'; agora passa pelo MUX que zera a entrada no LOADI.
			.b(entrada_b_ula),            				// Conectado à saída do MUX da ULA (Reg B ou Imediato)
			.ula_control(ula_op),         				// Sinal de 2 bits vindo do Controle
			.result(resultado_ula),       				// Resultado vai para o MUX de escrita e para o I/O
			.flag_zero(flag_zero)         				// Flag de status para a lógica de desvio condicional
		);
		
		// I/O - Interface de Entrada / Saída:
		io_asip IO (
			.clk(clk),
			.reset(reset),
			.mem_ler(mem_ler),
			.mem_escrever(mem_escrever),
			
			// Barramentos internos de dados e endereços (8 bits)
			.endereco(instrucao[7:0]),     				// O campo de endereço é o imediato da instrução
			.dado_escrita(dado_reg_b),     				// No comando STORE, enviamos o dado do Reg B para os motores
			.dado_lido(dado_lido_io),      				// Devolve a leitura dos sensores para o MUX do Banco
			
			// Conexões físicas externas com os pinos da FPGA Cyclone II
			.sensores_in(sensores_in),     				// Ligado diretamente à porta de entrada do Top-Level
			.motores_out(motores_out)      				// Ligado diretamente à porta de saída do Top-Level
		);
		
	
endmodule


// ---------------------------------------------------------------------------------------------
// Módulo original: pc_asip.v
// ---------------------------------------------------------------------------------------------
// =========================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha (Equipe de 5 integrantes)
// Arquivo:        'pc_asip.v'
// Autores:        Mateus Aranha e Enzo Adriel
// Data Criação:   06 de Julho de 2026
// =========================================================================================
// Descrição:
// Contador de Programa (Program Counter). Registrador de 8 bits sensível à 
// borda de subida do clock com reset assíncrono. Armazena o endereço da 
// instrução atual a ser buscada na Memória ROM.
// =========================================================================================
// Referências:
// 1. CUMMINGS, C. E. Nonblocking Assignments in Verilog Synthesis, Coding 
//    Styles That Kill! SNUG, 2000. (Uso do operador '<=' para seq. logic).
// 2. BROWN, S.; VRANESIC, Z. Fundamentals of Digital Logic with Verilog Design.
//    3. ed. McGraw-Hill, 2013. (Cap. 7 - Registradores e Contadores).
// =========================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|-----------------------------------------------------------
// 06/07/2026  | Mateus Aranha  | Criação do módulo base.
// 06/07/2026  | Mateus Aranha  | Correção da notação das entradas 'clk' e 'reset'.
// 06/07/2026  | Mateus Aranha  | Correção do uso de '{}' para 'begin/end' no block if-else
// =========================================================================================


module pc_asip (
	input wire clk,								// Entrada de Controle:			Sinal de Clock (1 Bit).
	input wire reset,								// Entrada de Controle:			Sinal de Reinício do Sistema, ativado em Alto(1) (1 bit).
	input wire [7:0] pc_in,						// Entrada de Dados: 			É o próximo endereço. Ele virá do Top_Level (8 bits).
	output reg [7:0] pc_out						// Saída de Dados:				É o endereço atual (8 bits). (Obs de sintaxe: como essa variável receberá seu valor DENTRO do bloco 'always', ela deve ser declarada com 'reg', como feito com 'Result' na ULA.)
	);
	
	
	// =====================
	// Lógica Sequencial:
	// =====================
	always @(posedge clk or posedge reset) begin				// A lista de sensibilidade do bloco always tá incluindo o 'reset', pois optamos por um Reset Assíncrono (reseta o PC na mesma hora que o botão for apertado, sem esperar a borda do clock).
			// Se o reset for Alto (1), o contador é zerado e o Robô volta para a linha 0 do firmware.
			if (reset == 1'b1) begin
				pc_out <= 8'b00000000;
			end
			
			// Senão, o endereço atual é atualizado para o próximo endereço.
			else begin
				pc_out <= pc_in;
			end
			
			
			// Na ULA, como estávamos lidando com lógica combinacional, usamos o sinal de igual (=) para atribuir valores. No entanto, aqui estamos lidando com lógica sequencial acionada por clock. 
			// Em um hardware, vários registradores atualizam seus valores exatamente no mesmo instante (borda do clock). O operador '<=' (chamado de atribuição não-bloqueante) garante pra gente que
			//	o simulador avalie todas as entradas antes de atualizar todas as saídas ao mesmo tempo, simulando o comportamento elétrico real dos Flip-Flops. Usar '=' em lógica sequencial gera erros
			// de simulação chamados de 'Race Conditions', nos quais os dados 'correm' mais rápido que o clock.
			
	end
	
endmodule


// ---------------------------------------------------------------------------------------------
// Módulo original: controle_asip.v
// ---------------------------------------------------------------------------------------------
// =============================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'controle_asip.v'
// Autores:        Mateus Aranha e Enzo Adriel
// Data Criação:   10 de Julho de 2026
// =============================================================================================
// Descrição:
// Unidade de Controle Combinacional (Arquitetura de Ciclo Único).
// Responsável por decodificar o Opcode de 4 bits da instrução (bits [15:12]) e 
// gerar todos os sinais de controle do datapath (ULA, Banco de Reg, I/O e Muxes).
// =============================================================================================
// Referências:
// 1. PATTERSON, D. A.; HENNESSY, J. L. Computer Organization and Design.
//    5. ed. Elsevier, 2014. (Cap. 4 - Lógica da Unidade de Controle de Ciclo Único).
// =============================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|---------------------------------------------------------------
// 10/07/2026  | Mateus Aranha  | Criação do módulo base e mapeamento da tabela de controle.
// 11/07/2026  | Enzo Adriel    | Ajuste de 'output wire' para 'output reg' nas portas de saída.
// 11/07/2026  | Enzo Adriel    | Remoção da entrada 'flag_zero' para acoplamento no Top-Level.
// 17/07/2026  | Revisão        | Adição do sinal 'ula_zera_a': corrige o LOADI, que estava fazendo
//             |                | Rd = Rd_atual + imediato em vez de Rd = imediato (carga acumulativa
//             |                | indevida sempre que um registrador é reutilizado).
// =============================================================================================


module controle_asip (
	// === Entradas:
	input wire [3:0] opcode,													// Bits [15:12] da instrução que vem da 'rom_asip'.
	
	// === Saídas de Controle do Datapath:
	output reg reg_escrever,													// Liga ou desliga a escrita no 'banco_reg_asip'.
	output reg [1:0] ula_op,													// Diz à 'ula_asip' qual operação executar (somar, subtrair, AND ou XOR).
	output reg mem_ler,															// Ativado quando queremos ler do módulo 'io_asip'.
	output reg mem_escrever,													// Ativado quando queremos escrever no módulo 'io_asip'.
	output reg ula_src,															// Controla um MUX do top. Se for Baixo(0), a ULA recebe o dado do 'banco_reg_asip'. Se for Alto(1), a ULA recebe o valor imediato de 8 bits direto da instrução.
	output reg mem_to_reg,														// Controla outro MUX. Se for Baixo(0), o dado que vai ser gravado no 'banco_reg_asip' vem da 'ula_asip'. Se for Alto(1), vem do 'io_asip'.
	output reg branch,															// Ativado em instruções de desvio condicional (fazer o "branch if zero").
	output reg ula_zera_a														// [CORREÇÃO] Controla o MUX novo da entrada 'a' da ULA no Top-Level. Se Alto(1), força a entrada 'a' em zero, fazendo o LOADI se comportar como um carregamento de valor absoluto (Rd = imediato) em vez de um acúmulo (Rd = Rd + imediato).
	);
	
	
	// =================================
	// Conjunto de Instruções (ISA):
	// =================================
	localparam OP_LOAD	= 4'b0001;											// Lê os status dos sensores TCRT5000 (i/o no endereço 8'h10) e guarda num registrador.
	localparam OP_STORE	= 4'b0010;											// Pega um valor de um registrador e envia para a Ponte H (i/o no endereço 8'h20) para mover os motores.
	localparam OP_ADD		= 4'b0011;											// Soma dos registradores e guarda o resultado.
	localparam OP_SUB		= 4'b0100;											// Subtrai dois registradores e guarda o resultado.
	localparam OP_AND		= 4'b0101;											// Aplica uma mascará lógica de bits.
	localparam OP_XOR		= 4'b0110;											// Compara bits.
	localparam OP_BEQ		= 4'b0111;											// 'Branch on Equal' => Se a última sub deu zero (fla_zero = 1), o robô desvia o fluxo para o endereço imediato de 8 bits especificado na instrução.
	localparam OP_LOADI	= 4'b1000;											// 'Load Immediate' => Pega os 8 bits finais da instrução e salva direto no 'banco_reg_asip'.
	
	
	// =====================================
	// Decodificador (Lógica Combinacional):
	// =====================================
	always @(*) begin
		// === Condição Inicial (tudo zerado):
		reg_escrever	= 1'b0;
		ula_op			= 2'b00;
		mem_ler			= 1'b0;
		mem_escrever	= 1'b0;
		ula_src			= 1'b0;	
		mem_to_reg		= 1'b0;
		branch			= 1'b0;
		ula_zera_a		= 1'b0;
		
		// == Opcodes:
		case (opcode)
			
			// Operação LOAD:
			OP_LOAD: begin
				reg_escrever 		= 1'b1;				// Ativado.
				ula_op 				= 2'b00;				// Soma.
				mem_ler 				= 1'b1;				// Ativado.
				mem_escrever 		= 1'b0;				// Desativado.
				ula_src 				= 1'b1;				// Ativado.
				mem_to_reg 			= 1'b1;				// Ativado.
				branch 				= 1'b0;				// Desativado.
			end
			
			// Operação STORE:
			OP_STORE: begin
				reg_escrever 		= 1'b0;				// Desativado.
				ula_op 				= 2'b00;				// Soma.
				mem_ler 				= 1'b0;				// Desativado.
				mem_escrever 		= 1'b1;				// Ativado.
				ula_src 				= 1'b1;				// Ativado.
				mem_to_reg 			= 1'b0;				// Desativado (don't care).
				branch 				= 1'b0;				// Desativado.
			end
			
			// Operação ADD:
			OP_ADD: begin
				reg_escrever 		= 1'b1;				// Ativado.
				ula_op 				= 2'b00;				// Soma.
				mem_ler 				= 1'b0;				// Desativado.
				mem_escrever 		= 1'b0;				// Desativado.
				ula_src 				= 1'b0;				// Desativado.
				mem_to_reg 			= 1'b0;				// Desativado.
				branch 				= 1'b0;				// Desativado.
			end
			
			// Operação SUB:
			OP_SUB: begin
				reg_escrever 		= 1'b1;				// Ativado.
				ula_op 				= 2'b01;				// Subtração.
				mem_ler 				= 1'b0;				// Desativado.
				mem_escrever 		= 1'b0;				// Desativado.
				ula_src 				= 1'b0;				// Desativado.
				mem_to_reg 			= 1'b0;				// Desativado.
				branch 				= 1'b0;				// Desativado.
			end
			
			// Operação AND:
			OP_AND: begin
				reg_escrever 		= 1'b1;				// Ativado.
				ula_op 				= 2'b10;				// AND.
				mem_ler 				= 1'b0;				// Desativado.
				mem_escrever 		= 1'b0;				// Desativado.
				ula_src 				= 1'b0;				// Desativado.
				mem_to_reg 			= 1'b0;				// Desativado.
				branch 				= 1'b0;				// Desativado.
			end
			
			// Operação XOR:
			OP_XOR: begin
				reg_escrever 		= 1'b1;				// Ativado.
				ula_op 				= 2'b11;				// XOR.
				mem_ler 				= 1'b0;				// Desativado.
				mem_escrever 		= 1'b0;				// Desativado.
				ula_src 				= 1'b0;				// Desativado.
				mem_to_reg 			= 1'b0;				// Desativado.
				branch 				= 1'b0;				// Desativado.
			end
			
			// Operação BEQ:
			OP_BEQ: begin
				reg_escrever 		= 1'b0;				// Desativado.
				ula_op 				= 2'b01;				// Subtração.
				mem_ler 				= 1'b0;				// Desativado.
				mem_escrever 		= 1'b0;				// Desativado.
				ula_src 				= 1'b0;				// Desativado.
				mem_to_reg 			= 1'b0;				// Desativado (don't care).
				branch 				= 1'b1;				// Ativado.
			end
			
			// Operação LOADI:
			OP_LOADI: begin
				reg_escrever 		= 1'b1;  			// Ativado (grava no banco)
				ula_op       		= 2'b00; 			// Soma (passa direto)
				mem_ler      		= 1'b0;  			// Desativado
				mem_escrever 		= 1'b0;  			// Desativado
				ula_src      		= 1'b1;  			// Ativado (pega o valor de 8 bits da instrução)
				mem_to_reg   		= 1'b0;  			// Desativado (grava o valor que passou pela ULA)
				branch       		= 1'b0;  			// Desativado
				ula_zera_a   		= 1'b1;  			// [CORREÇÃO] Ativado: zera a entrada 'a' da ULA, então result = 0 + imediato = imediato (carregamento absoluto de fato).
			end
			
			default: begin 		// Pronto, Quartus! Agora me deixe em paz! Chega de warnings, por favor... ＞﹏＜
			end
			
		endcase
	end
	
endmodule


// ---------------------------------------------------------------------------------------------
// Módulo original: io_asip.v
// ---------------------------------------------------------------------------------------------
// =========================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'io_asip.v'
// Autores:        Mateus Aranha e Enzo Adriel
// Data Criação:   10 de Julho de 2026
// =========================================================================================
// Descrição:
// Interface de Entrada e Saída (I/O Mapeado em Memória).
// Responsável por interceptar acessos de leitura ao endereço 0x10 para ler os 
// sensores ópticos reflexivos TCRT5000, e interceptar acessos de escrita ao 
// endereço 0x20 para acionar a Ponte H Dupla L9110S (Motores DC).
// =========================================================================================
// Referências:
// 1. PATTERSON, D. A.; HENNESSY, J. L. Computer Organization and Design.
//    5. ed. Elsevier, 2014. (Seção: Memory-Mapped I/O Concepts).
// =========================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|-----------------------------------------------------------
// 10/07/2026  | Mateus Aranha  | Criação do módulo base.
// 10/07/2026  | Mateus Aranha  | Correção da porta 'mem_escrever' para 'input'.
// 12/07/2026  | Enzo Adriel    | Inserção do reset assíncrono para proteção da Ponte H.
// =========================================================================================


module io_asip (
	// === Sinais de Controle:
	input  wire clk,
	input  wire reset,
	input  wire mem_ler,										// Sinal vindo da unidade de controle dizendo para ler. 
	input  wire mem_escrever,								// Sinal vindo da unidade de controle dizendo para escrever.
	
	
	// === Sinais Internos:
	input  wire [7:0] endereco,							// Endereço que dirá se o processador quer 'falar' com os sensores ou com os motores.
	input  wire [7:0] dado_escrita,						// Dado vindo do processador, passando por cá, depois vai ser enviado para o motor.
	output reg  [7:0] dado_lido,							// Dado vindo do sensor, passando por cá, depois vai ser enviado para o processador.
	
	
	// === Sinais Externos:
	input  wire [1:0] sensores_in,						// Fios vindos dos dois sensores TCRT5000.
	output reg  [3:0] motores_out							// Fios indo para a Ponte H L9110S (IN1 e IN2 para o motor esquerdo, IN3 e IN4 para o motor direito). 
	);
	
	
	// [CORREÇÃO - versão Pitanga] Declarações movidas para antes do primeiro uso (o compilador da
	// Pitanga exige declare-antes-de-usar, diferente do Quartus). Limiar do contador também reduzido:
	// na DE2 o clock é de 50MHz (10.000.000 ciclos = 200ms), mas na Pitanga o clock disponível é de
	// 1Hz, então o valor original faria o oscilador levar mais de 100 dias para alternar. Aqui ele
	// alterna a cada 2 ciclos de clock (2 segundos a 1Hz), só para deixar o modo de busca visível.
	reg [23:0] contador_busca;
	reg oscilador_busca;

	// ================================================
	// Leitura (Lógica Combinacional) - Endereço 8'h10:
	// ================================================
	always @(*) begin																			// Como a ideia é ter a condição que a leitura só será feita no endereço 8'h10, é preciso utilizar um 'always @(*)' em vez de um 'assign' direto.
		if (endereco == 8'h10) begin
			dado_lido = { 5'b000000, oscilador_busca, sensores_in};				// Como o sinal 'sensores_in' tem apenas 2 bits, mas o 'dado_lido' que vai ser enviado ao processador é de 8 bits, acontece o erro "Width Mismatch". Pesquisei, e, pra resolver isso, tem que fazer a concatenação de 6 bits 0 com os 2 bits do sinal 'sensores_in' (cada um dos dois bits representam um sensor óptico). att: agora que implementei um modo de "varredura" quando nenhum dos sensores detectarem a linha preta, foi criado um novo reg de 1 bit, no qual seu valor alterna entre 0 e 1 a cada 200ms. Dessa forma, o robô irá buscar a linha girando um pouco para um lado e depois para o outro lado.
		end
		
		else begin
			dado_lido = 8'b00000000;														// Se o endereço não for o do sensor, o I/O retorna zero (8'b00000000).
		end
	end
	
	
	// =============================================
	// Escrita (Lógica Sequencial) - Endereço 8'h20:
	// =============================================
	always @(posedge clk or posedge reset) begin
		if (reset == 1'b1) begin
			motores_out <= 4'b0000;															// Medida de segurança que para os motores se o 'reset' for pressionado.
		end
		
		else if ( (mem_escrever == 1'b1) && (endereco == 8'h20) ) begin		// Se 'mem_escrever' estiver em Alto(1) e o 'endereco' for o dos motores, permite a escrita :D.
			motores_out <= dado_escrita[3:0];											// => como 'dado_escrita' tem 8 bits, mas a Ponte H tem 4 pinos físicos, só vamos utilizar os 4 bits menos significativos e descartar os 4 MSB. Por isso 'dado_escrita[3:0]' e não ele inteiro (isso se chama "fatiar barramento").
		end
	end
	
	
	// ====================================================
	// Contador para gerar o intervalo de busca:						==> responsável pelo comportamento de busca, pois o valor de 'oscilador_busca' alterna a cada 2 ciclos de clock, fazendo o robô buscar a linha de forma autônoma.
	// ====================================================

	always @(posedge clk or posedge reset) begin
		 if (reset == 1'b1) begin
			  contador_busca <= 24'd0;
			  oscilador_busca <= 1'b0;
		 end
		 
		 else begin
			  // [CORREÇÃO - versão Pitanga] Limiar reduzido de 10.000.000 (200ms a 50MHz, valor da DE2)
			  // para 2 (2 segundos a 1Hz, clock da Pitanga), só para o modo de busca ficar visível.
			  if (contador_busca >= 24'd2) begin
					contador_busca <= 24'd0;
					oscilador_busca <= ~oscilador_busca; // Alterna o bit entre 0 e 1
			 end else begin
					contador_busca <= contador_busca + 24'd1;
			 end
		 end
	end
	
	
endmodule


// ---------------------------------------------------------------------------------------------
// Módulo original: ula_asip.v
// ---------------------------------------------------------------------------------------------
// =====================================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'ula_asip.v'
// Autores:      	 Mateus Aranha e Enzo Adriel
// Data Criação:   06 de Julho de 2026
// =====================================================================================================
// Descrição:
// Unidade Lógica e Aritmética (ULA) de 8 bits com arquitetura de ciclo único.
// Executa as operações matemáticas (ADD, SUB) e lógicas (AND, XOR) sobre 
// dois operandos de 8 bits, gerando o resultado e uma flag de Zero.
// =====================================================================================================
// Referências:
// 1. IEEE Standard for Verilog Hardware Description Language (IEEE Std 1364-2001).
//		(Para as regras de sintaxe de listas de portas e operadores bit a bit vs lógicos).
// 2. Digital Design and Computer Architecture (Harris & Harris, 2012). (Corrobora a escolha
//		de larguras de dados menores (como 8 bits) para microcontroladores focados em I/O reativo simples.
// =====================================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|-----------------------------------------------------------------------
// 06/07/2026  | Mateus Aranha  | Criação do módulo e bloco always.
// 07/07/2026  | Mateus Aranha  | Correção do operador NOR para XOR bit a bit.
// =====================================================================================================


module ula_asip (
	input wire [7:0] a, 							// Entrada de Dado: 				Operando A (8 Bits).
	input wire [7:0] b,							// Entrada de Dado:				Operando B (8 Bits). 
	input wire [1:0] ula_control,				// Entrada de Controle: 		Diz qual instrução a ULA deve fazer.
	output reg [7:0] result,					// Saída de Dados: 				Resultado da operação (8 Bits).	(Obs de sintaxe: como essa variável receberá seu valor DENTRO do bloco 'always', ela deve ser declarada com 'reg'.)
	output wire flag_zero						// Saída de Status: 				É a Flag para controle de Fluxo. Ela deve emitir nível lógico Alto(1) sempre que 'Result' estiver em Baixo(0).
	);
	
	
	// =====================
	// Lógica Combinacional:
	// =====================
	always @(*) begin
		case (ula_control)
			// === Adição (ULA_Control = 00):
			2'b00: result = a + b;
		
			// === Subtração (ULA_Control = 01):	
			2'b01: result = a - b;
			
			// === AND(ULA_Control = 10):
			2'b10: result = a & b;
		
			// === XOR (ULA_Control = 11):
			2'b11: result = a ^ b;
			
			// === Tratamento de Segurança (Importante para evitar criar memórias [latches] indesejados):
			default: result = 8'b00000000;
		endcase
	end
	
	// Se 'Result' estiver em Baixo(0), Flag_Zero vai para Alto(0), senão, permanece em Baixo(0).
	assign flag_zero = (result == 8'b00000000) ? 1'b1 : 1'b0;																		// Obs: descobri que há uma forma ainda mais enxuta do que os operadores ternários, que é o operador unitário ==> "assign Flag_Zero = ~|Result". Isso faz um NOR com todos os bits do 'Result', resultando em '1' apensa de todos forem '0'. Massa :D!
	
	
endmodule
		

// ---------------------------------------------------------------------------------------------
// Módulo original: rom_asip.v (ADAPTADO para a Pitanga: sem 'initial'/$readmemb, ROM combinacional)
// ---------------------------------------------------------------------------------------------
module rom_asip (
	input  wire [7:0]  endereco,										// Endereço de 8 bits vindo do 'pc_asip.v'
	output reg  [15:0] instrucao										// Instrução de 16 bits que irá para 'control_asip.v'
	);

	// =====================================================================================
	// [CORREÇÃO - versão Pitanga] A Pitanga não suporta a diretiva 'initial' (usada na versão
	// para a DE2 para carregar a memória via $readmemb a partir de 'firmware.txt'). Por isso,
	// nesta versão o firmware é escrito diretamente como uma tabela combinacional (case),
	// sem nenhuma memória a ser inicializada. Os valores abaixo são exatamente os mesmos 28
	// instruções do firmware.txt já corrigido (LOADI absoluto, máscara de sensores em R3,
	// alternância do modo de busca via R2, giro direita/esquerda ajustado à fiação real).
	// =====================================================================================
	always @(*) begin
		case (endereco)
			8'd0  : instrucao = 16'b0001010000010000;
			8'd1  : instrucao = 16'b1000110000000011;
			8'd2  : instrucao = 16'b0101110110000000;
			8'd3  : instrucao = 16'b1000100000000001;
			8'd4  : instrucao = 16'b0111111000010000;
			8'd5  : instrucao = 16'b1000100000000010;
			8'd6  : instrucao = 16'b0111111000001101;
			8'd7  : instrucao = 16'b1000100000000011;
			8'd8  : instrucao = 16'b0111111000010011;
			8'd9  : instrucao = 16'b1000100000000100;
			8'd10 : instrucao = 16'b0101100110000000;
			8'd11 : instrucao = 16'b0111100000010110;
			8'd12 : instrucao = 16'b0111000000011001;
			8'd13 : instrucao = 16'b1000010000001000;
			8'd14 : instrucao = 16'b0010000100100000;
			8'd15 : instrucao = 16'b0111000000000000;
			8'd16 : instrucao = 16'b1000010000000010;
			8'd17 : instrucao = 16'b0010000100100000;
			8'd18 : instrucao = 16'b0111000000000000;
			8'd19 : instrucao = 16'b1000010000001010;
			8'd20 : instrucao = 16'b0010000100100000;
			8'd21 : instrucao = 16'b0111000000000000;
			8'd22 : instrucao = 16'b1000010000000010;
			8'd23 : instrucao = 16'b0010000100100000;
			8'd24 : instrucao = 16'b0111000000000000;
			8'd25 : instrucao = 16'b1000010000001000;
			8'd26 : instrucao = 16'b0010000100100000;
			8'd27 : instrucao = 16'b0111000000000000;
			default: instrucao = 16'b0000000000000000;			// Qualquer endereço fora do firmware retorna instrução nula (NOP inofensivo).
		endcase
	end

endmodule


// ---------------------------------------------------------------------------------------------
// Módulo original: banco_reg_asip.v (ADAPTADO para a Pitanga: sem array de memória, mux explícito)
// ---------------------------------------------------------------------------------------------
module banco_reg_asip (
	// === Sinais de Controle: 
	input wire clk,
	input wire reset,
	input wire reg_write,										// Sinal que virá da unidade de controle. Se Alto(1), o banco permite gravar um dado. Por sua vez, se Baixo(0), o banco protege os dados atuais ('se tranca').
	
	// === Sinais de Endereçamento:
	input wire [1:0] end_leitura_1,							// Determina qual Reg vai para entrada A da ULA.
	input wire [1:0] end_leitura_2,							// Determina qual Reg vai para entrada B da ULA.
	input wire [1:0] end_escrita,								// Determina qual Reg vai guardar o resultado da conta / leitura do sensor.
	
	// === Barramentos de Dados:
	input  wire [7:0] dado_escrita,							// Valor de 8 bits chegando da ULA (ou do I/O).
	output reg  [7:0] dado_lido_1,							// Saída de 8 bits correspondente ao 'end_leitura_1'.
	output reg  [7:0] dado_lido_2								// Saída de 8 bits correspondente ao 'end_leitura_2'.
	);
	
	
	// =====================================================================================
	// [CORREÇÃO - versão Pitanga] A Pitanga não suporta declaração de memória (array de reg,
	// ex.: 'reg [7:0] registradores [0:3];') — só suporta vetores simples. Por isso, os 4
	// registradores viraram 4 'reg' separados (r1, r2, r3; R0 não tem reg próprio, é sempre
	// zero), e o endereçamento vira lógica de mux explícita (case) em vez de indexação de
	// array. O comportamento é idêntico ao original, R0 continua travado em zero.
	// =====================================================================================
	reg [7:0] r1;
	reg [7:0] r2;
	reg [7:0] r3;
	
	
	// ===============================
	// Leitura (Lógica Combinacional):
	// ===============================
	always @(*) begin
		case (end_leitura_1)
			2'b00: dado_lido_1 = 8'b00000000;			// R0 travado em zero
			2'b01: dado_lido_1 = r1;
			2'b10: dado_lido_1 = r2;
			2'b11: dado_lido_1 = r3;
		endcase
	end
	
	always @(*) begin
		case (end_leitura_2)
			2'b00: dado_lido_2 = 8'b00000000;			// R0 travado em zero
			2'b01: dado_lido_2 = r1;
			2'b10: dado_lido_2 = r2;
			2'b11: dado_lido_2 = r3;
		endcase
	end
	
	
	// ============================
	// Escrita (Lógica Sequencial):
	// ============================
	always @(posedge clk or posedge reset) begin
		if (reset == 1'b1) begin
			r1 <= 8'b00000000;
			r2 <= 8'b00000000;
			r3 <= 8'b00000000;
		end
		
		else if (reg_write == 1'b1) begin								// O 'case' abaixo já garante o 'hardwired to zero' do R0: como não existe 'branch' de escrita pra 2'b00, uma escrita endereçada a R0 simplesmente não tem efeito nenhum.
			case (end_escrita)
				2'b01: r1 <= dado_escrita;
				2'b10: r2 <= dado_escrita;
				2'b11: r3 <= dado_escrita;
				default: ; // end_escrita == 2'b00 (R0): não faz nada, R0 continua travado em zero.
			endcase
		end
			
	end
	
endmodule
