// =====================================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'ula_asip.v'
// Autores:      	 Mateus Aranha
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
		