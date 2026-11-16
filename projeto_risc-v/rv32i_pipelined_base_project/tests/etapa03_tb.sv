`timescale 1ns/1ps
module etapa03_tb;
    logic clk = 0, rst_n = 0;
    wire [31:0] pc;
    wire wb_write;
    wire [4:0] wb_rd;
    wire [31:0] wb_data;
    integer poison = 0;
    always #5 clk = ~clk;
    pl_cpu dut (
        .clk(clk), .rst_n(rst_n), .PC(pc), .SW(18'b0), .KEY_IO(4'hf),
        .LEDR(), .LEDG(), .UART_TXD(), .UART_RXD(1'b1),
        .wb_reg_write(wb_write), .wb_reg_dst(wb_rd), .wb_reg_data(wb_data),
        .mem_wr_en(), .mem_wr_addr(), .mem_wr_data()
    );
    always @(posedge clk)
        if (rst_n && wb_write && wb_rd == 14) poison = poison + 1;
    task automatic check(input string name, input logic [31:0] actual, expected);
        if (actual !== expected) $fatal(1, "%s: got %08h expected %08h", name, actual, expected);
        $display("PASS %s = %08h", name, actual);
    endtask
    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (140) @(negedge clk);
        check("x1", dut.datapath.regfile.rf[1], 32'hffffffff);
        check("LB x2", dut.datapath.regfile.rf[2], 32'hffffffff);
        check("LBU x3", dut.datapath.regfile.rf[3], 32'h000000ff);
        check("x4", dut.datapath.regfile.rf[4], 32'h00000080);
        check("LH x5", dut.datapath.regfile.rf[5], 32'hffff80ff);
        check("LHU x6", dut.datapath.regfile.rf[6], 32'h000080ff);
        check("LW x7", dut.datapath.regfile.rf[7], 32'h008080ff);
        check("JAL link x8", dut.datapath.regfile.rf[8], 32'd92);
        check("JALR link x11", dut.datapath.regfile.rf[11], 32'd112);
        check("branch not taken x15", dut.datapath.regfile.rf[15], 32'd7);
        check("RAM 0", dut.datapath.dmem.ram[0], 32'h008080ff);
        check("RAM 1", dut.datapath.dmem.ram[1], 32'd92);
        check("RAM 2", dut.datapath.dmem.ram[2], 32'd112);
        check("RAM 3", dut.datapath.dmem.ram[3], 32'd7);
        check("RAM 4", dut.datapath.dmem.ram[4], 32'h008080ff);
        check("wrong-path writes", poison, 0);
        $display("PASS etapa03 end-to-end assembled program");
        $finish;
    end
endmodule
