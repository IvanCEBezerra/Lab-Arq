// =============================================================================
// pl_alu_ctrl.sv
// Unidade de Controle da ALU -- RV32I pipelined (P&H secao 4.4)
//
// Entradas (do estagio EX -- registrador ID/EX):
//   ALUOp[1:0] : codigo do controlador principal
//     2'b00 : Load/Store  -> forcar ADD
//     2'b01 : Branch BEQ  -> forcar SUB
//     2'b10 : R-type      -> decodificar via Funct3/Funct7
//   Funct7[6:0], Funct3[2:0] : campos da instrucao
//   Funct3: valores declarados em assembly.py
// Saida Operation[3:0] -> pl_alu.sv:
//   4'd01 ADD  4'd02 SUB  4'd04 OR  4'd05 AND  4'd06 SLL 
//   4'd07 SRL  4'd08 SRA  4'd11 SLT 4'd12 SLTU
// =============================================================================

`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,
    input  logic [6:0] Funct7,
    input  logic [2:0] Funct3,
    output logic [3:0] Operation
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
        case (ALUOp)
            2'b00: Operation = ALU_ADD;   // Load / Store -> ADD

            2'b01: Operation = ALU_SUB;   // Branch BEQ  -> SUB

            2'b10: begin                // R-type: decodificar Funct
                case (Funct3)
                    3'b000: Operation = Funct7[5] ? ALU_SUB : ALU_ADD; // SUB ou ADD
                    3'b001: Operation = ALU_SLL;
                    3'b010: Operation = ALU_SLT;
                    3'b011: Operation = ALU_SLTU;
                    3'b100: Operation = ALU_XOR;         
                    3'b101: Operation =  Funct7[5] ? ALU_SRA : ALU_SRL; // shift-right arimtetico ou logico
                    3'b110: Operation = ALU_OR; 
                    3'b111: Operation = ALU_AND;  
                    default: Operation = ALU_ADD;
                endcase
            end

            default: Operation = 4'd01;
        endcase
    end

endmodule
