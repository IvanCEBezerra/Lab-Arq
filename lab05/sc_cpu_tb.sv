`timescale 1ns / 1ps

// =============================================================================
// sc_cpu_tb.sv
// Testbench para a CPU RISC-V monociclo com verificacao automatica
//
// Funcionamento:
//   1. Executa a CPU ate o travamento/laco final (PC estavel por 2 ciclos).
//   2. Imprime no console cada escrita em registrador e na memoria de dados.
//   3. Gera o arquivo "output.txt" com o trace do PC e o estado final.
//   4. Compara o "output.txt" com o "golden.txt" e exibe o resultado (PASS/FAIL).
//
// Como compilar e executar no ModelSim:
//   vlib work
//   vmap work work
//   vlog -sv *.sv
//   vsim work.sc_cpu_tb
//   run -all
// =============================================================================

module sc_cpu_tb;

    // =========================================================================
    // Parametros de simulacao
    // =========================================================================
    parameter int CLK_PERIOD   = 20;   // periodo de 20 ns (clock de 50 MHz)
    parameter int RESET_CYCLES = 4;    // quantidade de ciclos com reset ativo
    parameter int MAX_CYCLES   = 60;   // limite maximo de ciclos para evitar loop infinito

    // =========================================================================
    // Sinais do DUT (Device Under Test)
    // =========================================================================
    logic        clk;
    logic        rst_n;
    logic [31:0] PC;

    sc_cpu dut (
        .clk   (clk),
        .rst_n (rst_n),
        .PC    (PC)
    );

    // =========================================================================
    // Gerador de Clock (periodo = 20 ns)
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // Contador de ciclos
    // =========================================================================
    int cycle = 0;

    // =========================================================================
    // Monitoramento das escritas no Banco de Registradores
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n &&
            dut.datapath.regfile.RegWrite &&
            dut.datapath.regfile.rd != 5'b0)
        begin
            $display("[Ciclo %3d] REG x%-2d <= %08h",
                cycle + 1,
                dut.datapath.regfile.rd,
                dut.datapath.regfile.WriteData);
        end
    end

    // =========================================================================
    // Monitoramento das escritas na Memoria de Dados (instrucao sw)
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n && dut.datapath.dmem.MemWrite) begin
            $display("[Ciclo %3d] MEM [palavra %02h] <= %08h",
                cycle + 1,
                dut.datapath.dmem.addr,
                dut.datapath.dmem.WriteData);
        end
    end

    // =========================================================================
    // Espelho da memoria de dados para dump final
    // =========================================================================
    logic [31:0] mem_shadow [0:255];

    initial begin
        for (int i = 0; i < 256; i++) mem_shadow[i] = '0;
    end

    always @(posedge clk) begin
        if (rst_n && dut.datapath.dmem.MemWrite)
            mem_shadow[dut.datapath.dmem.addr] <= dut.datapath.dmem.WriteData;
    end

    // =========================================================================
    // Geracao de formas de onda (VCD)
    // =========================================================================
    initial begin
        $dumpfile("sc_cpu_tb.vcd");
        $dumpvars(0, sc_cpu_tb);
    end

    // =========================================================================
    // Sequencia principal do teste
    // =========================================================================
    integer      fd;
    logic [31:0] prev_pc;

    initial begin
        // --- Aplicacao do reset inicial ---
        rst_n = 0;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk); // solta reset na descida para evitar metastabilidade
        rst_n = 1;

        // --- Criacao do arquivo output.txt ---
        fd = $fopen("output.txt", "w");
        if (fd == 0) begin
            $display("ERRO: Nao foi possivel criar o arquivo output.txt.");
            $finish;
        end

        // --- Executa ate atingir a condicao de parada (PC repetido) ---
        prev_pc = ~32'h0;

        while (1) begin
            @(posedge clk);
            cycle++;

            $fdisplay(fd, "CYCLE %3d  PC=%08h", cycle, PC);

            // Se o PC for igual ao do ciclo anterior, atingiu o branch de travamento (halt)
            if (PC === prev_pc) begin
                dump_state();
                break;
            end

            prev_pc = PC;

            if (cycle >= MAX_CYCLES) begin
                $display("ERRO: Limite de ciclos atingido (%0d ciclos). Halt nao detectado.", MAX_CYCLES);
                $fclose(fd);
                $finish;
            end
        end

        $fclose(fd);

        // --- Comparacao com o golden file ---
        verify_output();

        $finish;
    end

    // =========================================================================
    // Salva o estado final dos registradores e da memoria no output.txt
    // =========================================================================
    task automatic dump_state;
        logic [31:0] v;

        $fdisplay(fd, "---");
        for (int i = 0; i <= 10; i++) begin
            v = (i == 0) ? 32'h0 : dut.datapath.regfile.regs[i];
            $fdisplay(fd, "x%-2d = %08h", i, v);
        end

        $fdisplay(fd, "---");
        for (int w = 0; w <= 7; w++) begin
            $fdisplay(fd, "MEM[%2d] = %08h", w, mem_shadow[w]);
        end
    endtask

    // =========================================================================
    // Compara linha a linha output.txt com golden.txt
    // =========================================================================
    task automatic verify_output;
        integer fg, fo;
        string  lg, lo;
        int     ng, no;
        int     lineno, errs;

        fg = $fopen("golden.txt", "r");
        if (fg == 0) begin
            $display("ERRO: Arquivo golden.txt nao encontrado no diretorio de execucao.");
            return;
        end
        fo = $fopen("output.txt", "r");

        lineno = 0;
        errs   = 0;

        forever begin
            ng = $fgets(lg, fg);
            no = $fgets(lo, fo);

            if (ng == 0 && no == 0) break;

            lineno++;

            if (ng == 0) begin
                $display("  DIVERGENCIA: golden.txt terminou antes de output.txt (linha %0d)", lineno);
                errs++;
                break;
            end
            if (no == 0) begin
                $display("  DIVERGENCIA: output.txt terminou antes de golden.txt (linha %0d)", lineno);
                errs++;
                break;
            end

            if (lg != lo) begin
                errs++;
                $display("  Linha %3d INCORRETA:", lineno);
                $display("    Esperado: %s", lg.substr(0, lg.len() - 2));
                $display("    Obtido:   %s", lo.substr(0, lo.len() - 2));
            end
        end

        $fclose(fg);
        $fclose(fo);

        $display("");
        if (errs == 0)
            $display("=== PASS: Todas as %0d linhas conferem com o golden file! ===", lineno);
        else
            $display("=== FAIL: %0d divergencia(s) encontradas em %0d linhas ===", errs, lineno);
    endtask

endmodule
