// =============================================================================
// pl_cpu_tb.sv
// Testbench -- RV32I pipelined
//
// Instancia pl_cpu diretamente (sem PLL); gera clock e reset internamente.
//
// Programa de teste (instruction.mif / program.hex):
//   000: lw  x1,  0(x0)    x1 = 10
//   001: lw  x2,  4(x0)    x2 = 20
//   002: add x3, x1, x2    x3 = 30   (forwarding MEM/WB->EX)
//   003: and x4, x3, x1    x4 = 10   (0x1E & 0x0A, forwarding EX/MEM->EX)
//   004: lw  x5,  0(x0)    x5 = 10   (provoca load-use stall em 005)
//   005: add x6, x5, x2    x6 = 30   (1 ciclo de stall)
//   006: sw  x3,  8(x0)    dmem[2] = 30
//   007: beq x1, x2, +8    NAO tomado (x1=10 != x2=20)
//   008: add x7, x1, x2    x7 = 30
//   009: beq x1, x5, +8    TOMADO (x1=x5=10) -> salta 00A, executa 00B
//   00A: add x8, x0, x0    DESCARTADO (flush)
//   00B: add x8, x1, x4    x8 = 20
//   00C: beq x0, x0,  0    halt (loop infinito)
//
// Estado esperado apos halt:
//   x1=10 x2=20 x3=30 x4=10 x5=10 x6=30 x7=30 x8=20
//   dmem[2]=30
//
// O testbench:
//   1. Monitora cada escrita no banco de registradores (estagio WB)
//   2. Monitora cada escrita na memoria de dados (estagio MEM)
//   3. Detecta uma transferencia de controle para o proprio PC
//   4. Faz dump do estado final dos registradores e da dmem
//   5. Grava output.txt e compara com golden.txt, salvo com +DUMP_ONLY
// =============================================================================

`timescale 1ns / 1ps

module pl_cpu_tb;

    // =========================================================================
    // Parametros
    // =========================================================================
    localparam CLK_PERIOD  = 100;   // 10 MHz  (100 ns)
    localparam CLK_HALF    = CLK_PERIOD / 2;
    localparam RESET_CYCLES = 4;
    localparam DEFAULT_MAX_CYCLES = 2000;


    // =========================================================================
    // Sinais do DUT
    // =========================================================================
    logic        clk, rst_n;
    logic [31:0] PC;
    logic [17:0] SW    = 18'h15555;   // chaves com padrao alternado
    logic [3:0]  KEY   = 4'hF;        // nenhum botao pressionado
    logic [17:0] LEDR;
    logic [8:0]  LEDG;
    logic        UART_TXD;
    logic        UART_RXD = 1'b1;     // linha idle

    logic        wb_reg_write;
    logic [4:0]  wb_reg_dst;
    logic [31:0] wb_reg_data;
    logic        mem_wr_en;
    logic [7:0]  mem_wr_addr;
    logic [31:0] mem_wr_data;

    // =========================================================================
    // Instancia do DUT
    // =========================================================================
    pl_cpu dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .PC           (PC),
        .SW           (SW),
        .KEY_IO       (KEY),
        .LEDR         (LEDR),
        .LEDG         (LEDG),
        .UART_TXD     (UART_TXD),
        .UART_RXD     (UART_RXD),
        .wb_reg_write (wb_reg_write),
        .wb_reg_dst   (wb_reg_dst),
        .wb_reg_data  (wb_reg_data),
        .mem_wr_en    (mem_wr_en),
        .mem_wr_addr  (mem_wr_addr),
        .mem_wr_data  (mem_wr_data)
    );

    // =========================================================================
    // Clock e reset
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    initial begin
        rst_n = 1'b0;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    end

    // =========================================================================
    // Arquivo de saida
    // =========================================================================
    integer out_fd;

    // =========================================================================
    // Monitor de escrita no banco de registradores (estagio WB)
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n && wb_reg_write && wb_reg_dst != 5'b0) begin
            $display("[WB] REG x%0d = 0x%08X", wb_reg_dst, wb_reg_data);
            $fdisplay(out_fd, "REG %2d = 0x%08X", wb_reg_dst, wb_reg_data);
        end
    end

    // =========================================================================
    // Monitor de escrita na memoria de dados (estagio MEM)
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n && mem_wr_en) begin
            $display("[MEM] dmem[%0d] = 0x%08X", mem_wr_addr, mem_wr_data);
            $fdisplay(out_fd, "MEM[%3d] = 0x%08X", mem_wr_addr, mem_wr_data);
        end
    end

    // =========================================================================
    // Deteccao de halt e execucao principal
    // =========================================================================
    logic halted, dump_only;
    logic simulation_ok = 1'b0;
    logic [31:0] halt_pc;
    integer cycle_cnt, max_cycles, report_words;
    integer i, errors;

    initial begin
        out_fd = $fopen("output.txt", "w");
        if (out_fd == 0) $fatal(1, "Nao foi possivel gravar output.txt.");
        cycle_cnt = 0;
        halted = 1'b0;
        dump_only = $test$plusargs("DUMP_ONLY");
        report_words = dump_only ? 256 : 16;
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = DEFAULT_MAX_CYCLES;
        if (max_cycles <= 0) $fatal(1, "MAX_CYCLES precisa ser positivo.");

        @(posedge rst_n);
        while (!halted && cycle_cnt < max_cycles) begin
            @(posedge clk);
            cycle_cnt++;
            if (dut.datapath.pc_src && dut.datapath.branch_target == dut.datapath.id_ex.pc) begin
                halted = 1'b1;
                halt_pc = dut.datapath.id_ex.pc;
            end
        end

        if (!halted)
            $fatal(1, "Timeout apos %0d ciclos (halt nao detectado).", max_cycles);
        // Deixa as instrucoes anteriores ao halt concluirem MEM e WB.
        repeat (2) @(negedge clk);
        #1;
        $display("Halt detectado em PC=0x%08X apos %0d ciclos.", halt_pc, cycle_cnt);

        // =====================================================================
        // Dump do estado final
        // =====================================================================
        $display("--- Estado final dos registradores ---");
        $fdisplay(out_fd, "--- estado final ---");

        // Acessa registradores diretamente via hierarquia
        for (i = 1; i < 32; i++) begin
            if (dut.datapath.regfile.rf[i] !== 32'b0) begin
                $display("  x%0d = 0x%08X", i, dut.datapath.regfile.rf[i]);
                $fdisplay(out_fd, "FINAL REG %2d = 0x%08X", i, dut.datapath.regfile.rf[i]);
            end
        end

        $display("--- Estado final da dmem (palavras nao-zero) ---");
        for (i = 0; i < report_words; i++) begin
            if (dut.datapath.dmem.ram[i] !== 32'b0) begin
                $display("  dmem[%0d] = 0x%08X", i, dut.datapath.dmem.ram[i]);
                $fdisplay(out_fd, "FINAL MEM[%3d] = 0x%08X", i, dut.datapath.dmem.ram[i]);
            end
        end

        $fclose(out_fd);

        // =====================================================================
        // Comparacao com golden.txt
        // =====================================================================
        if (dump_only) begin
            $display("Simulacao concluida: estado em output.txt.");
        end else begin
            $display("--- Comparacao com golden.txt ---");
            errors = compare_with_golden();
            if (errors != 0)
                $fatal(1, "FAIL: %0d diferenca(s) encontrada(s).", errors);
            $display("PASS: saida corresponde ao golden.");
        end
        simulation_ok = 1'b1;
        $finish;
    end

    // =========================================================================
    // Funcao de comparacao com golden.txt
    // =========================================================================
    function automatic integer compare_with_golden();
        integer gfd, ofd, gcount, ocount;
        reg [1023:0] gline, oline;
        integer errs;
        errs = 0;

        gfd = $fopen("golden.txt", "r");
        if (gfd == 0) begin
            $display("ERRO: golden.txt nao encontrado.");
            return 1;
        end
        ofd = $fopen("output.txt", "r");
        if (ofd == 0) begin
            $display("ERRO: output.txt nao pode ser aberto.");
            $fclose(gfd);
            return 1;
        end

        gcount = $fgets(gline, gfd);
        ocount = $fgets(oline, ofd);
        while (gcount > 0 || ocount > 0) begin
            if (gcount != ocount || gline != oline) begin
                $display("DIFF golden: %s  output: %s", gline, oline);
                errs++;
            end
            gcount = $fgets(gline, gfd);
            ocount = $fgets(oline, ofd);
        end

        $fclose(gfd);
        $fclose(ofd);
        return errs;
    endfunction

endmodule
