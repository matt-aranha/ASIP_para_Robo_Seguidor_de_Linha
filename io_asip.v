// =========================================================================================
// Instituição:    Universidade Federal de Sergipe (UFS)
// Disciplina:     Sistemas Digitais - Prof. Ph.D. Calebe Micael e Prof. Ph.D. Rodolfo Botto
// Projeto:        ASIP para Robô Seguidor de Linha
// Arquivo:        'io_asip.v'
// Autores:        Mateus Aranha
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
// 12/07/2026  | Mateus Aranha  | Inserção do reset assíncrono para proteção da Ponte H.
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
	// Contador de 24 bits para gerar o intervalo de busca:						==> responsável pelo comportamento de busca, pois o valor de 'oscilador_busca' alterna entre 1 e 0 a cada 200ms, fazendo o robô buscar a linha de forma autônoma.
	// ====================================================
	reg [23:0] contador_busca;
	reg oscilador_busca;

	always @(posedge clk or posedge reset) begin
		 if (reset == 1'b1) begin
			  contador_busca <= 24'd0;
			  oscilador_busca <= 1'b0;
		 end
		 
		 else begin
			  // 10.000.000 de ciclos a 50MHz equivalem a exatamente 200ms (0.2s)
			  if (contador_busca >= 24'd10000000) begin
					contador_busca <= 24'd0;
					oscilador_busca <= ~oscilador_busca; // Alterna o bit entre 0 e 1
			  end else begin
					contador_busca <= contador_busca + 24'd1;
			  end
		 end
	end
	
	
endmodule
