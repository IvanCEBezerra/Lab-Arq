`timescale 1ns/1ps
module pl_jalr_tb;
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
    integer poison_writes = 0;
    pl_cpu dut (.clk(clk), .rst_n(rst_n), .PC(pc), .SW(18'b0),
        .KEY_IO(4'hf), .LEDR(ledr), .LEDG(ledg), .UART_TXD(tx),
        .UART_RXD(1'b1), .wb_reg_write(wb_write), .wb_reg_dst(wb_rd),
        .wb_reg_data(wb_data), .mem_wr_en(mem_write),
        .mem_wr_addr(mem_addr), .mem_wr_data(mem_data));
    function automatic [31:0] addi(input integer rd, rs1, imm);
        addi = {imm[11:0], rs1[4:0], 3'b000, rd[4:0], 7'h13};
    endfunction
    function automatic [31:0] jalr(input integer rd, rs1, imm);
        jalr = {imm[11:0], rs1[4:0], 3'b000, rd[4:0], 7'h67};
    endfunction
    function automatic [31:0] lw(input integer rd, rs1, imm);
        lw = {imm[11:0], rs1[4:0], 3'b010, rd[4:0], 7'h03};
    endfunction
    task automatic check(input integer regno, input logic [31:0] want);
        if (dut.datapath.regfile.rf[regno] !== want) begin
            $display("FAIL x%0d: got %h expected %h", regno,
                dut.datapath.regfile.rf[regno], want);
            errors++;
        end
    endtask
    always @(posedge clk) begin
        if (rst_n && wb_write && (wb_rd == 4 || wb_rd == 11 || wb_rd == 12)) begin
            $display("FAIL wrong-path write x%0d = %h", wb_rd, wb_data);
            poison_writes++;
        end
    end
    initial begin
        #1;
        dut.datapath.dmem.ram[0] = 56;
        dut.datapath.imem.rom[0] = addi(1, 0, 20);
        dut.datapath.imem.rom[1] = jalr(5, 1, 1); // 21 & ~1 = 20; link=8, forwarded rs1
        dut.datapath.imem.rom[2] = addi(4, 0, 99);
        dut.datapath.imem.rom[3] = addi(11, 0, 99);
        dut.datapath.imem.rom[4] = addi(12, 0, 99);
        dut.datapath.imem.rom[5] = addi(6, 5, 1);
        dut.datapath.imem.rom[6] = addi(2, 0, 41);
        dut.datapath.imem.rom[7] = jalr(7, 2, -1); // 41-1=40; link=32
        dut.datapath.imem.rom[8] = addi(4, 0, 99);
        dut.datapath.imem.rom[9] = addi(11, 0, 99);
        dut.datapath.imem.rom[10] = addi(8, 7, 1);
        dut.datapath.imem.rom[11] = lw(3, 0, 0);
        dut.datapath.imem.rom[12] = jalr(9, 3, 1); // load-use stall, 57 & ~1 = 56
        dut.datapath.imem.rom[13] = addi(12, 0, 99);
        dut.datapath.imem.rom[14] = addi(10, 9, 1);
        dut.datapath.imem.rom[15] = 32'h00000063;
        #19 rst_n = 1;
        repeat (75) @(negedge clk);
        check(1, 20); check(2, 41); check(3, 56);
        check(5, 8); check(6, 9); check(7, 32);
        check(8, 33); check(9, 52); check(10, 53);
        if (poison_writes != 0) errors++;
        if (errors) $fatal(1, "JALR FAILED: %0d mismatches", errors);
        $display("PASS JALR forwarded rs1, negative I-imm, bit0 mask, load-use, link and flush");
        $finish;
    end
endmodule
