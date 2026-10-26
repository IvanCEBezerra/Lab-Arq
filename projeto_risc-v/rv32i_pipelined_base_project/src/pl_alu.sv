// =============================================================================
// pl_alu.sv
// Unidade Logica e Aritmetica de 32 bits -- RV32I pipelined
//
// Codificacao de operacao (Operation[3:0]):
//   4'd01 : ADD  -- adicao com sinal
//   4'd02 : SUB  -- subtracao com sinal  (BEQ usa Zero)
//   4'd03 : XOR  -- OU exclusivo
//   4'd04 : OR   -- OU bit a bit
//   4'd05 : AND  -- E bit a bit
//   4'd06 : SLL  -- shift-left-logical deslocamento logico a esquerda
//   4'd07 : SRL  -- shift-right-logical deslocamento logico a direita
//   4'd08 : SRA  -- shift-right-arithmetic deslocamento arimtetico a direita
//   4'd11 : SLT  -- set-less-than com sinal
//   4'd12 : SLTU  -- set-less-than-unsigned sem sinal
// =============================================================================

`timescale 1ns / 1ps

module pl_alu (
    input  logic [31:0] SrcA,
    input  logic [31:0] SrcB,
    input  logic [3:0]  Operation,
    output logic [31:0] ALUResult,
    output logic        Zero
);

// Renomeacao do operation para melhor identificacao
localparam [3:0] ALU_ADD  = 4'd01;
localparam [3:0] ALU_SUB  = 4'd02;
localparam [3:0] ALU_XOR  = 4'd03;
localparam [3:0] ALU_OR   = 4'd04;
localparam [3:0] ALU_AND  = 4'd05;
localparam [3:0] ALU_SLL  = 4'd06;
localparam [3:0] ALU_SRL  = 4'd07;
localparam [3:0] ALU_SRA  = 4'd08;
localparam [3:0] ALU_SLT  = 4'd11;
localparam [3:0] ALU_SLTU = 4'd12;

    always_comb begin
        case (Operation)
            ALU_ADD:   ALUResult = $signed(SrcA) + $signed(SrcB);
            ALU_SUB:   ALUResult = $signed(SrcA) - $signed(SrcB);
            ALU_XOR:   ALUResult = SrcA ^SrcB;
            ALU_OR:    ALUResult = SrcA | SrcB;
            ALU_AND:   ALUResult = SrcA & SrcB;
            ALU_SLL:   ALUResult = SrcA << SrcB[4:0];
            ALU_SRL:   ALUResult = SrcA >> SrcB[4:0];
            ALU_SRA:   ALUResult = $signed(SrcA) >>> SrcB[4:0];
            ALU_SLT:   ALUResult = 32'($signed(SrcA) < $signed(SrcB));
            ALU_SLTU:  ALUResult = 32'(SrcA < SrcB);
            default: ALUResult = 32'b0;
        endcase
    end

    assign Zero = (ALUResult == 32'b0);

endmodule
