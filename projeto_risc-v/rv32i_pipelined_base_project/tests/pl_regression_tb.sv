`timescale 1ns/1ps
module pl_regression_tb;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    wire [31:0] pc, wb_data, mem_data;
    wire [4:0] wb_rd;
    wire wb_write, mem_write;
    wire [7:0] mem_addr;
    wire [17:0] ledr;
    wire [8:0] ledg;
    wire tx;
    integer errors = 0;
    pl_cpu dut (.clk(clk), .rst_n(rst_n), .PC(pc), .SW(18'b0),
        .KEY_IO(4'hf), .LEDR(ledr), .LEDG(ledg), .UART_TXD(tx),
        .UART_RXD(1'b1), .wb_reg_write(wb_write), .wb_reg_dst(wb_rd),
        .wb_reg_data(wb_data), .mem_wr_en(mem_write),
        .mem_wr_addr(mem_addr), .mem_wr_data(mem_data));
    task automatic check(input integer regno, input logic [31:0] want);
        if (dut.datapath.regfile.rf[regno] !== want) begin
            $display("FAIL x%0d got %h expected %h", regno,
                dut.datapath.regfile.rf[regno], want);
            errors++;
        end
    endtask
    initial begin
        #20 rst_n = 1;
        repeat (80) @(negedge clk);
        check(1, 10); check(2, 20); check(3, 30); check(4, 10);
        check(5, 10); check(6, 30); check(7, 30); check(8, 20);
        if (dut.datapath.dmem.ram[2] !== 32'd30) begin
            $display("FAIL RAM[2] got %h expected 30", dut.datapath.dmem.ram[2]);
            errors++;
        end
        if (errors) $fatal(1, "BASE REGRESSION FAILED: %0d mismatches", errors);
        $display("PASS base program: LW, SW, ADD, AND, BEQ, forwarding and load-use");
        $finish;
    end
endmodule
