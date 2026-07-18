// =======================================================================================================================================================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'controle_asip.v'
// Autores:        Mateus Aranha
// Data Criação:   10 de Julho de 2026
// =======================================================================================================================================================================================================================
// Descrição:
// Unidade de Controle Combinacional (Arquitetura de Ciclo Único).
// Responsável por decodificar o Opcode de 4 bits da instrução (bits [15:12]) e 
// gerar todos os sinais de controle do datapath (ULA, Banco de Reg, I/O e Muxes).
// =======================================================================================================================================================================================================================
// Referências:
// 1. PATTERSON, D. A.; HENNESSY, J. L. Computer Organization and Design.
//    5. ed. Elsevier, 2014. (Cap. 4 - Lógica da Unidade de Controle de Ciclo Único).
// =======================================================================================================================================================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// 10/07/2026  | Mateus Aranha  | Criação do módulo base e mapeamento da tabela de controle.
// 11/07/2026  | Mateus Aranha  | Ajuste de 'output wire' para 'output reg' nas portas de saída.
// 11/07/2026  | Mateus Aranha  | Remoção da entrada 'flag_zero' para acoplamento no Top-Level.
// 17/07/2026  | Mateus Aranha  | Adição do sinal 'ula_zera_a': corrige o LOADI, que estava fazendo Rd = Rd_atual + imediato em vez de Rd = imediato (carga acumulativa indevida sempre que um registrador é reutilizado).
// =======================================================================================================================================================================================================================


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