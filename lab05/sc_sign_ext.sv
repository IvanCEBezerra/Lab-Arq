`timescale 1ns / 1ps

// =============================================================================
// sc_sign_ext.sv
// Gerador de Imediatos com Extensao de Sinal - RISC-V Monociclo
//
// Identifica o opcode da instrucao para extrair os bits do campo imediato e
// estende o sinal para 32 bits.
//
// Formatos suportados:
//
//   Tipo-I (lw):
//     imm[11:0] = inst[31:20]
//     ImmExt    = { {20{inst[31]}}, inst[31:20] }
//
//   Tipo-S (sw):
//     imm[11:5] = inst[31:25]
//     imm[4:0]  = inst[11:7]
//     ImmExt    = { {20{inst[31]}}, inst[31:25], inst[11:7] }
//
//   Tipo-B (beq):
//     imm[12]   = inst[31]
//     imm[11]   = inst[7]
//     imm[10:5] = inst[30:25]
//     imm[4:1]  = inst[11:8]
//     imm[0]    = 0 (desvios sao alinhados a multiplos de 2 bytes)
//     ImmExt    = { {19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0 }
// =============================================================================

module sc_sign_ext (
    input  logic [31:0] Instr,   // palavra de instrucao de 32 bits
    output logic [31:0] ImmExt   // imediato estendido para 32 bits
);

    localparam LOAD   = 7'b0000011; // lw  (Tipo-I)
    localparam STORE  = 7'b0100011; // sw  (Tipo-S)
    localparam BRANCH = 7'b1100011; // beq (Tipo-B)

    always_comb begin
        case (Instr[6:0])
            LOAD: begin
                // Tipo-I: imediato de 12 bits localizado em Instr[31:20]
                ImmExt = {{20{Instr[31]}}, Instr[31:20]};
            end

            STORE: begin
                // Tipo-S: imediato dividido entre Instr[31:25] e Instr[11:7]
                ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
            end

            BRANCH: begin
                // Tipo-B: imediato com bits embaralhados e bit 0 sempre 0
                ImmExt = {{19{Instr[31]}}, Instr[31], Instr[7],
                          Instr[30:25], Instr[11:8], 1'b0};
            end

            default: begin
                ImmExt = 32'b0;
            end
        endcase
    end

endmodule
