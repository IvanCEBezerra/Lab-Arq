// =============================================================================
// pl_control.sv
// Unidade de Controle Principal -- RV32I pipelined (P&H secao 4.4)
//
// Decodifica o opcode de 7 bits (estagio ID) e gera os sinais de controle
// que serao propagados pelos registradores de pipeline.
//
// Instrucoes suportadas:
//   R-type  (0110011): add, sub, and, or, slt, sll, srl, sra, sltu, xor
//   I-type  (0010011): addi, andi, ori, slti, slli, srli, srai
//   I-type  (0000011): lw
//   S-type  (0100011): sw
//   B-type  (1100011): beq
//   U-type  (0110111): lui
//   U-type  (0010111): auipc
//
// Tabela de sinais de controle:
//   Sinal     | R-type | I-type (0010011) | lw | sw | beq | lui | auipc
//   ----------|--------|------------------|----|----|-----|-----|------
//   ALUSrcA   |   00   |        00        | 00 | 00 |  00 |  10 |  01   00=reg, 01=pc, 10=zero
//   ALUSrc    |    0   |         1        |  1 |  1 |   0 |   1 |   1   0=reg, 1=imm
//   MemtoReg  |    0   |         0        |  1 |  - |   - |   0 |   0   0=ALU, 1=mem
//   RegWrite  |    1   |         1        |  1 |  0 |   0 |   1 |   1
//   MemRead   |    0   |         0        |  1 |  0 |   0 |   0 |   0
//   MemWrite  |    0   |         0        |  0 |  1 |   0 |   0 |   0
//   Branch    |    0   |         0        |  0 |  0 |   1 |   0 |   0
//   ALUOp[1:0]|   10   |        11        | 00 | 00 |  01 |  00 |  00
// =============================================================================

`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,
    output logic [1:0] ALUSrcA,
    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic [1:0] ALUOp
);

    localparam R_TYPE = 7'b0110011;
    localparam I_TYPE = 7'b0010011; // ADDI, ANDI, ORI, SLTI, SLLI, SRLI, SRAI
    localparam LOAD   = 7'b0000011; // LW
    localparam STORE  = 7'b0100011; // SW
    localparam BRANCH = 7'b1100011; // BEQ
    localparam LUI    = 7'b0110111; // LUI
    localparam AUIPC  = 7'b0010111; // AUIPC

    always_comb begin
        ALUSrcA  = 2'b00;
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;

        case (Opcode)
            R_TYPE: begin
                ALUSrcA  = 2'b00;
                ALUSrc   = 1'b0;
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end
            I_TYPE: begin
                ALUSrcA  = 2'b00;
                ALUSrc   = 1'b1;
                MemtoReg = 1'b0;
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end
            LOAD: begin
                ALUSrcA  = 2'b00;
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end
            STORE: begin
                ALUSrcA  = 2'b00;
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end
            BRANCH: begin
                ALUSrcA  = 2'b00;
                Branch   = 1'b1;
                ALUOp    = 2'b01;
            end
            LUI: begin
                ALUSrcA  = 2'b10; // seleciona constante 0 na entrada SrcA
                ALUSrc   = 1'b1;  // seleciona ImmExt na entrada SrcB
                MemtoReg = 1'b0;  // dado escrito em rd vem da ALU
                RegWrite = 1'b1;  // habilita escrita em rd
                ALUOp    = 2'b00; // operacao ADD: 0 + ImmExt = ImmExt
            end
            AUIPC: begin
                ALUSrcA  = 2'b01; // seleciona PC na entrada SrcA
                ALUSrc   = 1'b1;  // seleciona ImmExt na entrada SrcB
                MemtoReg = 1'b0;  // dado escrito em rd vem da ALU
                RegWrite = 1'b1;  // habilita escrita em rd
                ALUOp    = 2'b00; // operacao ADD: PC + ImmExt
            end
            default: ; // sinais permanecem em zero (seguro)
        endcase
    end

endmodule
