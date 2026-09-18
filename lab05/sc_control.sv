`timescale 1ns / 1ps

// =============================================================================
// sc_control.sv
// Unidade de Controle Principal - RISC-V Monociclo
// Decodifica o opcode da instrucao e gera os sinais de controle para o datapath.
//
// Instrucoes suportadas:
//   - Tipo-R (0110011): add, sub, and, or, slt
//   - lw     (0000011): carrega palavra da memoria
//   - sw     (0100011): armazena palavra na memoria
//   - beq    (1100011): desvio se igual
// =============================================================================

module sc_control (
    input  logic [6:0] Opcode,
    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic [1:0] ALUOp
);

    // Opcodes do RISC-V (RV32I)
    localparam R_TYPE = 7'b0110011; // add, sub, and, or, slt
    localparam LOAD   = 7'b0000011; // lw
    localparam STORE  = 7'b0100011; // sw
    localparam BRANCH = 7'b1100011; // beq

    always_comb begin
        // Valores padrao para evitar inferencia de latch e garantir seguranca
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;

        case (Opcode)
            R_TYPE: begin
                ALUSrc   = 1'b0; // segundo operando vem do registrador (rs2)
                MemtoReg = 1'b0; // dado que vai pro regfile vem da ALU
                RegWrite = 1'b1; // escreve no registrador de destino (rd)
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                Branch   = 1'b0;
                ALUOp    = 2'b10; // operacao determinada por funct3 e funct7
            end

            LOAD: begin
                ALUSrc   = 1'b1; // segundo operando e o imediato (offset)
                MemtoReg = 1'b1; // dado escrito no registrador vem da memoria de dados
                RegWrite = 1'b1; // habilita escrita no regfile
                MemRead  = 1'b1; // habilita leitura da memoria de dados
                MemWrite = 1'b0;
                Branch   = 1'b0;
                ALUOp    = 2'b00; // soma base + offset
            end

            STORE: begin
                ALUSrc   = 1'b1; // segundo operando e o imediato (offset)
                MemtoReg = 1'b0;
                RegWrite = 1'b0; // nao escreve no banco de registradores
                MemRead  = 1'b0;
                MemWrite = 1'b1; // habilita escrita na memoria de dados
                Branch   = 1'b0;
                ALUOp    = 2'b00; // soma base + offset
            end

            BRANCH: begin
                ALUSrc   = 1'b0; // compara registradores rs1 e rs2
                MemtoReg = 1'b0;
                RegWrite = 1'b0;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                Branch   = 1'b1; // sinaliza instrucao de branch condicional
                ALUOp    = 2'b01; // subtracao para checar se sao iguais (Zero flag)
            end

            default: begin
                // Mantem valores seguros (tudo desabilitado)
                ALUSrc   = 1'b0;
                MemtoReg = 1'b0;
                RegWrite = 1'b0;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                Branch   = 1'b0;
                ALUOp    = 2'b00;
            end
        endcase
    end

endmodule

