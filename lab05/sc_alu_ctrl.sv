`timescale 1ns / 1ps

// =============================================================================
// sc_alu_ctrl.sv
// Unidade de Controle da ALU - RISC-V Monociclo
//
// Recebe o sinal ALUOp de 2 bits da unidade de controle principal e os campos
// funct7 e funct3 da instrucao para gerar o codigo de operacao de 4 bits
// para a ALU.
//
// Codificacao do sinal ALUOp:
//   2'b00 : Load / Store -> forca soma (calculo de endereco base + offset)
//   2'b01 : Branch BEQ   -> forca subtracao (para comparacao rs1 - rs2)
//   2'b10 : Tipo-R       -> decodifica conforme Funct7[5] e Funct3
//
// Codigo de operacao para a ALU (sc_alu.sv):
//   4'd01 : ADD
//   4'd02 : SUB
//   4'd04 : OR
//   4'd05 : AND
//   4'd11 : SLT
//
// Tabela de decodificacao para instrucoes do Tipo-R:
//   Funct7   | Funct3 | Instrucao
//   0000000  |  000   | ADD
//   0100000  |  000   | SUB  (Funct7[5] = 1 diferencia SUB de ADD)
//   0000000  |  110   | OR
//   0000000  |  111   | AND
//   0000000  |  010   | SLT
// =============================================================================

module sc_alu_ctrl (
    input  logic [1:0] ALUOp,
    input  logic [6:0] Funct7,
    input  logic [2:0] Funct3,
    output logic [3:0] Operation
);

    always_comb begin
        case (ALUOp)
            2'b00: Operation = 4'd01; // Load / Store -> ADD

            2'b01: Operation = 4'd02; // Branch BEQ  -> SUB

            2'b10: begin              // Tipo-R: decodifica usando Funct7 e Funct3
                case (Funct3)
                    // Funct7[5]=1 indica SUB; Funct7[5]=0 indica ADD
                    3'h0: Operation = Funct7[5] ? 4'd02 : 4'd01;
                    3'h6: Operation = 4'd04; // OR
                    3'h7: Operation = 4'd05; // AND
                    3'h2: Operation = 4'd11; // SLT
                    default: Operation = 4'd01;
                endcase
            end

            default: Operation = 4'd01;
        endcase
    end

endmodule
