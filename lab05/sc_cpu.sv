`timescale 1ns / 1ps

// =============================================================================
// sc_cpu.sv
// CPU RISC-V Monociclo
//
// Conecta a unidade de controle principal (sc_control) com o caminho de dados
// (sc_datapath).
//
// Instrucoes suportadas:
//   - Tipo-R (opcode 0110011): add, sub, and, or, slt
//   - Tipo-I (opcode 0000011): lw
//   - Tipo-S (opcode 0100011): sw
//   - Tipo-B (opcode 1100011): beq
// =============================================================================

module sc_cpu (
    input  logic        clk,
    input  logic        rst_n,    // reset assincrono ativo em nivel baixo

    // Sinais de observabilidade
    output logic [31:0] PC
);

    // -------------------------------------------------------------------------
    // Sinais de controle gerados pela unidade de controle
    // -------------------------------------------------------------------------
    logic [6:0] opcode;
    logic       ALUSrc;
    logic       MemtoReg;
    logic       RegWrite;
    logic       MemRead;
    logic       MemWrite;
    logic       Branch;
    logic [1:0] ALUOp;

    // -------------------------------------------------------------------------
    // Instanciacao da Unidade de Controle
    // -------------------------------------------------------------------------
    sc_control ctrl (
        .Opcode   (opcode),
        .ALUSrc   (ALUSrc),
        .MemtoReg (MemtoReg),
        .RegWrite (RegWrite),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .Branch   (Branch),
        .ALUOp    (ALUOp)
    );

    // -------------------------------------------------------------------------
    // Instanciacao do Caminho de Dados (Datapath)
    // -------------------------------------------------------------------------
    sc_datapath datapath (
        .clk       (clk),
        .rst_n     (rst_n),
        .ALUSrc    (ALUSrc),
        .MemtoReg  (MemtoReg),
        .RegWrite  (RegWrite),
        .MemRead   (MemRead),
        .MemWrite  (MemWrite),
        .Branch    (Branch),
        .ALUOp     (ALUOp),
        .Opcode    (opcode),
        .PC        (PC)
    );

endmodule
