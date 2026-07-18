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