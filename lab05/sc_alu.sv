`timescale 1ns / 1ps

// =============================================================================
// sc_alu.sv
// Unidade Logica e Aritmetica (ALU) de 32 bits para RISC-V Monociclo
//
// Operacoes suportadas:
//   4'd01 : ADD  (soma - instrucao add e calculo de endereco para lw/sw)
//   4'd02 : SUB  (subtracao - instrucao sub e comparacao para beq)
//   4'd04 : OR   (operacao logica OU)
//   4'd05 : AND  (operacao logica E)
//   4'd11 : SLT  (set on less than - comparacao com sinal)
//
// Saida Zero: vai para nivel alto (1) quando ALUResult == 0.
//   -> Utilizada na logica de desvio do beq (desvia se rs1 - rs2 == 0)
// =============================================================================

module sc_alu #(
    parameter DATA_W = 32,
    parameter OP_W   = 4
) (
    input  logic [DATA_W-1:0] SrcA,
    input  logic [DATA_W-1:0] SrcB,
    input  logic [OP_W-1:0]   Operation,
    output logic [DATA_W-1:0] ALUResult,
    output logic              Zero
);

    always_comb begin
        case (Operation)
            4'd01:   ALUResult = signed'(SrcA) + signed'(SrcB);        // ADD (soma)
            4'd02:   ALUResult = signed'(SrcA) - signed'(SrcB);        // SUB (subtracao)
            4'd04:   ALUResult = SrcA | SrcB;                          // OR (ou logico)
            4'd05:   ALUResult = SrcA & SrcB;                          // AND (e logico)
            4'd11:   ALUResult = 32'(signed'(SrcA) < signed'(SrcB));   // SLT (menor que)
            default: ALUResult = 32'b0;
        endcase
    end

    // Flag Zero: ativa quando o resultado da operacao for zero
    assign Zero = (ALUResult == 32'b0);

endmodule
