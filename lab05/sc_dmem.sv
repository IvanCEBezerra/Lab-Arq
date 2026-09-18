`timescale 1ns / 1ps

// =============================================================================
// sc_dmem.sv
// Memoria de Dados (RAM) - RISC-V Monociclo
//
// Capacidade   : 256 palavras x 32 bits (1 KB)
// Inicializacao: arquivo "data.hex" (formato $readmemh)
//
// Leituras:
//   Assincronas/combinacionais (assign ReadData = ram[addr]).
//   Assim que o endereco da ALU se estabiliza, o dado de leitura fica pronto.
//
// Escritas (instrucao sw):
//   Sincronas na borda de subida do clock quando MemWrite estiver ativo.
//
// Mapeamento de enderecos:
//   A ALU calcula um endereco de bytes; o endereco de palavras e alu_result[9:2].
// =============================================================================

module sc_dmem (
    input  logic        clk,
    input  logic        MemWrite,    // 1 = escreve WriteData no endereco (sw)
    input  logic [7:0]  addr,        // endereco da palavra: alu_result[9:2]
    input  logic [31:0] WriteData,   // dado para escrita (vindo de rs2)
    output logic [31:0] ReadData     // dado lido da memoria (combinacional)
);

    logic [31:0] ram [0:255];

    initial begin
        // Zera a memoria inicialmente
        for (int i = 0; i < 256; i++) ram[i] = 32'h0;
        // Carrega os dados iniciais do arquivo
        $readmemh("data.hex", ram);
    end

    // Leitura assincrona
    assign ReadData = ram[addr];

    // Escrita sincrona na borda de subida do clock
    always @(posedge clk) begin
        if (MemWrite)
            ram[addr] <= WriteData;
    end

endmodule
