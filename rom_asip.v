// =========================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'rom_asip.v'
// Autores:        Mateus Aranha
// Data Criação:   09 de Julho de 2026
// =========================================================================================
// Descrição:
// Memória de Instruções (ROM - Read-Only Memory). Possui 256 posições de 16 bits.
// Responsável por armazenar o firmware do processador. A memória é inicializada
// em tempo de síntese através da leitura do arquivo externo 'firmware.mif'.
// O acesso à instrução é estritamente combinacional, baseado no endereço fornecido.
// =========================================================================================
// Referências:
// 1. IEEE Standard for Verilog Hardware Description Language (IEEE Std 1364-2001).
//    Secção 17.2.8: Loading memory data from a file (Uso da System Task $readmemb).
// =========================================================================================
// Histórico de Revisões:
// Data        | Autor          | Modificação
// ------------|----------------|-----------------------------------------------------------
// 09/07/2026  | Mateus Aranha  | Criação do módulo base.
// 11/07/2026  | Mateus Aranha  | Implementação da leitura externa via $readmemb.
// =========================================================================================


module rom_asip (
	input  wire [7:0]  endereco,													// Endereço de 8 bits vindo do 'pc_asip.v'
	output wire [15:0] instrucao													// Instrução de 16 bits que irá para 'control_asip.v'
	);

	
	// =========================================================
	// Declaração de Memória Interna (256 'gavetas' de 16 bits):
	// =========================================================
	reg [15:0] memoria [0:255];
	
	
	// =========================
	// Inicialização da memória:
	// =========================
	initial begin
		$readmemb("firmware.txt", memoria);										// Essa função '$readmemb' é uma System Task do verilog, ela diz ao sintetizador para sintetizador ler a
	end																					// memória em binário que está no arquivo de texto ('firmware.txt') e gravar na matriz de memória ('memoria').
	
	
	// ===============================
	// Leitura (Lógica Combinacional):
	// ===============================
	assign instrucao = memoria[endereco];
	
endmodule
