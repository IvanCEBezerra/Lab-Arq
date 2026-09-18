`timescale 1ns / 1ps

// =============================================================================
// sc_regfile.sv
// Banco de Registradores (32 registradores de 32 bits) - RISC-V Monociclo
//
// Leituras : assincronas (combinacionais) - dados disponiveis imediatamente
// Escritas : sincronas na borda de subida do clock
//
// O registrador x0 e fixado em zero conforme a especificacao RISC-V:
//   - Leituras em x0 sempre retornam zero
//   - Escritas em x0 sao descartadas
// =============================================================================

module sc_regfile (
    input  logic        clk,
    input  logic        RegWrite,   // habilita gravacao no registrador rd
    input  logic [4:0]  rs1,        // endereco do primeiro registrador fonte
    input  logic [4:0]  rs2,        // endereco do segundo registrador fonte
    input  logic [4:0]  rd,         // endereco do registrador de destino
    input  logic [31:0] WriteData,  // dado a ser gravado em rd
    output logic [31:0] ReadData1,  // dado lido de rs1
    output logic [31:0] ReadData2   // dado lido de rs2
);

    logic [31:0] regs [31:0];

    // Inicializacao dos registradores com zero para simulacao no ModelSim
    initial begin
        for (int i = 0; i < 32; i++)
            regs[i] = 32'b0;
    end

    // -------------------------------------------------------------------------
    // Leituras assincronas
    // Se o registrador selecionado for x0 (endereco 0), retorna 0 diretamente
    // -------------------------------------------------------------------------
    assign ReadData1 = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
    assign ReadData2 = (rs2 == 5'b0) ? 32'b0 : regs[rs2];

    // -------------------------------------------------------------------------
    // Escrita sincrona na borda de subida do clock
    // Garante que x0 nunca seja sobrescrito (rd != 0)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (RegWrite && rd != 5'b0)
            regs[rd] <= WriteData;
    end

endmodule
