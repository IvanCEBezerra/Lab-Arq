`timescale 1ns / 1ps

// =============================================================================
// sc_imem.sv
// Memoria de Instrucoes (ROM) - RISC-V Monociclo
//
// Capacidade   : 256 palavras x 32 bits (1 KB)
// Inicializacao: arquivo "program.hex" (formato $readmemh)
//
// Leitura assincrona (combinacional):
//   O registrador de PC fornece o endereco e a instrucao fica disponivel
//   imediatamente, sem depender de borda de clock, permitindo que a execucao
//   ocorra inteiramente dentro do mesmo ciclo de clock.
//
// Mapeamento de enderecos:
//   O PC e um endereco de bytes (incrementa de 4 em 4).
//   O endereco de palavras conectado a esta memoria e pc[9:2] (8 bits).
// =============================================================================

module sc_imem (
    input  logic [7:0]  addr,    // endereco da palavra (conectar pc[9:2])
    output logic [31:0] instr    // palavra de instrucao de 32 bits
);

    logic [31:0] rom [0:255];

    initial begin
        // Inicializa todas as posicoes com instrucao NOP (addi x0, x0, 0)
        for (int i = 0; i < 256; i++) rom[i] = 32'h00000013;
        // Carrega o programa em hexadecimal
        $readmemh("program.hex", rom);
    end

    // Leitura combinacional direta
    assign instr = rom[addr];

endmodule
