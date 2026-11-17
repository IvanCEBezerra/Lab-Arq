`timescale 1ns/1ps
// Oracle independente: arquivos expected_regs.hex e expected_data.hex gerados
// a partir de valores arquiteturais, nunca do estado observado no DUT.
module extensive_tb;
    logic clk = 0, rst_n = 0;
    wire [31:0] pc;
    wire [17:0] ledr;
    wire [8:0] ledg;
    logic [31:0] expected_regs [0:31];
    logic [31:0] expected_data [0:255];
    integer halt_pc, failures = 0, visits = 0;
    always #5 clk = ~clk;
    pl_cpu dut (
        .clk(clk), .rst_n(rst_n), .PC(pc), .SW(18'h15555),
        .KEY_IO(4'hf), .LEDR(ledr), .LEDG(ledg), .UART_TXD(),
        .UART_RXD(1'b1), .wb_reg_write(), .wb_reg_dst(),
        .wb_reg_data(), .mem_wr_en(), .mem_wr_addr(), .mem_wr_data()
    );
    initial begin
        if (!$value$plusargs("HALT_PC=%d", halt_pc)) $fatal(1, "HALT_PC ausente");
        $readmemh("expected_regs.hex", expected_regs);
        $readmemh("expected_data.hex", expected_data);
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (180) begin
            @(negedge clk);
            if (pc == halt_pc) visits++;
        end
        if (visits < 4) begin
            $display("FAIL: halt nao visitado 4 vezes: %0d", visits);
            failures++;
        end
        for (int i = 1; i < 32; i++) begin
            if (expected_regs[i] !== 32'hxxxxxxxx &&
                dut.datapath.regfile.rf[i] !== expected_regs[i]) begin
                $display("FAIL x%0d: obtido %08h esperado %08h", i,
                         dut.datapath.regfile.rf[i], expected_regs[i]);
                failures++;
            end
        end
        for (int i = 0; i < 256; i++) begin
            if (dut.datapath.dmem.ram[i] !== expected_data[i]) begin
                $display("FAIL RAM[%0d]: obtido %08h esperado %08h", i,
                         dut.datapath.dmem.ram[i], expected_data[i]);
                failures++;
            end
        end
        if (failures) $fatal(1, "%0d divergencias", failures);
        $display("PASS oracle: registradores esperados, 256 palavras RAM, halt");
        $finish;
    end
endmodule
