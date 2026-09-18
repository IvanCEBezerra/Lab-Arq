`timescale 1ns / 1ps

// =============================================================================
// sc_datapath.sv
// Caminho de Dados (Datapath) - RISC-V Monociclo
// Baseado no livro do Patterson & Hennessy (Figura 4.17)
//
// Componentes instanciados e conectados:
//   - sc_imem    : memoria de instrucoes (256 palavras, program.hex)
//   - sc_regfile : banco com 32 registradores de 32 bits (x0 = 0)
//   - sc_sign_ext: gerador de imediatos com extensao de sinal (formatos I, S, B)
//   - sc_alu_ctrl: decodificador do controle da ALU
//   - sc_alu     : unidade logica e aritmetica de 32 bits
//   - sc_dmem    : memoria de dados (256 palavras, data.hex)
//
// Multiplexadores do datapath:
//   - Mux da ALU   : ALUSrc   -> seleciona entre registrador rs2 e o imediato
//   - Mux de WB     : MemtoReg -> seleciona saida da ALU ou dado lido da memoria
//   - Mux do PC     : PCSrc    -> seleciona PC+4 ou o endereco de desvio (branch)
// =============================================================================

module sc_datapath (
    input  logic        clk,
    input  logic        rst_n,    // reset assincrono ativo em nivel baixo (zera PC)
    // Sinais de controle vindos da sc_control
    input  logic        ALUSrc,
    input  logic        MemtoReg,
    input  logic        RegWrite,
    input  logic        MemRead,
    input  logic        MemWrite,
    input  logic        Branch,
    input  logic [1:0]  ALUOp,
    // Opcode enviado para a unidade de controle
    output logic [6:0]  Opcode,
    // Valor atual do PC para o testbench / depuracao
    output logic [31:0] PC
);

    // -------------------------------------------------------------------------
    // Sinais internos
    // -------------------------------------------------------------------------
    logic [31:0] pc_reg;        // registrador do PC atual
    logic [31:0] pc_plus4;      // PC + 4 (proxima instrucao sequencial)
    logic [31:0] pc_branch;     // PC + ImmExt (alvo do desvio)
    logic [31:0] pc_next;       // proximo valor a ser carregado no PC
    logic        pc_src;        // 1 = toma o desvio (Branch & Zero)

    logic [31:0] instr;         // instrucao lida da memoria

    // Campos decodificados da instrucao
    logic [4:0]  rs1, rs2, rd;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    logic [31:0] read_data1;    // saida da porta 1 do banco de registradores (rs1)
    logic [31:0] read_data2;    // saida da porta 2 do banco de registradores (rs2)
    logic [31:0] imm_ext;       // imediato estendido para 32 bits
    logic [31:0] alu_srcb;      // segundo operando da ALU (saida do mux)
    logic [3:0]  alu_op;        // codigo de operacao da ALU
    logic [31:0] alu_result;    // resultado calculado pela ALU
    logic        zero;          // flag Zero da ALU (1 se alu_result == 0)
    logic [31:0] mem_read_data; // dado lido da memoria de dados
    logic [31:0] write_back;    // dado que sera gravado no registrador rd

    // -------------------------------------------------------------------------
    // Registrador de PC
    // Atualiza na borda de subida do clock ou zera com reset assincrono
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc_reg <= 32'b0;
        else        pc_reg <= pc_next;
    end

    assign PC = pc_reg;

    // -------------------------------------------------------------------------
    // Memoria de Instrucoes
    // Enderecamento por palavra: pc[9:2]
    // -------------------------------------------------------------------------
    sc_imem imem (
        .addr  (pc_reg[9:2]),
        .instr (instr)
    );

    // -------------------------------------------------------------------------
    // Decodificacao dos campos da instrucao (RISC-V de 32 bits)
    // -------------------------------------------------------------------------
    assign Opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // -------------------------------------------------------------------------
    // Banco de Registradores
    // -------------------------------------------------------------------------
    sc_regfile regfile (
        .clk       (clk),
        .RegWrite  (RegWrite),
        .rs1       (rs1),
        .rs2       (rs2),
        .rd        (rd),
        .WriteData (write_back),
        .ReadData1 (read_data1),
        .ReadData2 (read_data2)
    );

    // -------------------------------------------------------------------------
    // Gerador de Imediatos com Extensao de Sinal
    // -------------------------------------------------------------------------
    sc_sign_ext sign_ext (
        .Instr  (instr),
        .ImmExt (imm_ext)
    );

    // -------------------------------------------------------------------------
    // Mux para selecao do segundo operando da ALU
    // ALUSrc = 0 -> usa registrador rs2 (Tipo-R, beq)
    // ALUSrc = 1 -> usa imediato com extensao de sinal (lw, sw)
    // -------------------------------------------------------------------------
    assign alu_srcb = ALUSrc ? imm_ext : read_data2;

    // -------------------------------------------------------------------------
    // Controle da ALU (decodifica ALUOp + funct3/funct7)
    // -------------------------------------------------------------------------
    sc_alu_ctrl alu_ctrl (
        .ALUOp    (ALUOp),
        .Funct7   (funct7),
        .Funct3   (funct3),
        .Operation(alu_op)
    );

    // -------------------------------------------------------------------------
    // ALU Principal
    // -------------------------------------------------------------------------
    sc_alu alu (
        .SrcA     (read_data1),
        .SrcB     (alu_srcb),
        .Operation(alu_op),
        .ALUResult(alu_result),
        .Zero     (zero)
    );

    // -------------------------------------------------------------------------
    // Memoria de Dados
    // Enderecamento por palavra: alu_result[9:2]
    // -------------------------------------------------------------------------
    sc_dmem dmem (
        .clk       (clk),
        .MemWrite  (MemWrite),
        .addr      (alu_result[9:2]),
        .WriteData (read_data2),
        .ReadData  (mem_read_data)
    );

    // -------------------------------------------------------------------------
    // Mux de Write-Back (retorno para o registrador)
    // MemtoReg = 0 -> resultado da ALU (Tipo-R)
    // MemtoReg = 1 -> dado da memoria (lw)
    // -------------------------------------------------------------------------
    assign write_back = MemtoReg ? mem_read_data : alu_result;

    // -------------------------------------------------------------------------
    // Logica de Desvio (Branch) e calculo do proximo PC
    // BEQ e tomado quando Branch=1 E Zero=1 (rs1 == rs2 na subtracao)
    // -------------------------------------------------------------------------
    assign pc_plus4  = pc_reg + 32'd4;
    assign pc_branch = pc_reg + imm_ext;
    assign pc_src    = Branch & zero;
    assign pc_next   = pc_src ? pc_branch : pc_plus4;

endmodule
