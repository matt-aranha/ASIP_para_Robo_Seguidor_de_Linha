// =========================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha (Equipe de 5 integrantes)
// Arquivo:        'pc_asip.v'
// Autores:        Mateus Aranha
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
