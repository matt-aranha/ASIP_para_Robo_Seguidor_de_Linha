// =========================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'banco_reg_asip.v'
// Autores:        Mateus Aranha
// Data Criação:   08 de Julho de 2026
// =========================================================================================
// Descrição:
// Banco de Registradores contendo 4 registradores de 8 bits.
// Possui leitura combinacional dupla (assíncrona) e escrita sequencial (síncrona).
// O Registrador R0 é fisicamente travado em zero (Hardwired to Zero) para auxiliar
// operações lógicas e de movimentação de dados.
// =========================================================================================
// Referências:
// 1. PATTERSON, D. A.; HENNESSY, J. L. Computer Organization and Design:
//    The Hardware/Software Interface. 5. ed. Elsevier, 2014. (Cap. 2 -
//    Princípio de Design 3 e o uso do Registrador Zero constante).
// =========================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|-----------------------------------------------------------
// 08/07/2026  | Mateus Aranha  | Criação do módulo base.
// 08/07/2026  | Mateus Aranha  | Implementação da trava física do R0.
// 09/07/2026  | Mateus Aranha  | Correção de atribuições no bloco de reset.
// =========================================================================================


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
	output wire [7:0] dado_lido_1,							// Saída de 8 bits correspondente ao 'end_leitura_1'.
	output wire [7:0] dado_lido_2								// Saída de 8 bits correspondente ao 'end_leitura_2'.
	);
	
	
	// ======================================================
	// Declaração de Memória Interna (4 'gavetas' de 8 bits):
	// ======================================================
	reg [7:0] registradores [0:3];												// obs: 'reg' cria um array chamado 'registradores' com 4 posições (de 0 a 3), onde cada posição tem 8 bits.
	
	
	// ===============================
	// Leitura (Lógica Combinacional):
	// ===============================
	assign dado_lido_1 = registradores[end_leitura_1];
	assign dado_lido_2 = registradores[end_leitura_2];
	
	
	// ============================
	// Escrita (Lógica Sequencial):
	// ============================
	always @(posedge clk or posedge reset) begin
		if (reset == 1'b1) begin
			registradores [0] <= 8'b00000000;
			registradores [1] <= 8'b00000000;
			registradores [2] <= 8'b00000000;
			registradores [3] <= 8'b00000000;
		end
		
		else if (reg_write == 1'b1 && end_escrita != 2'b00) begin				// O argumento do If diz: Só grave o dado SE o 'reg_write' for == 1 E o endereço de destino for != 0.
			registradores[end_escrita] <= dado_escrita;								// O objetivo disso é fazer o 'hardwired to zero' no R0 (Travar ele em 0). Falar sobre as vantagens disso na apresentação!!!
		end
			
	end
	
endmodule
