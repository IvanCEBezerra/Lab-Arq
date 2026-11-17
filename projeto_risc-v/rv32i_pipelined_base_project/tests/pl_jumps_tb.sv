`timescale 1ns/1ps
module pl_jumps_tb;
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
    function automatic [31:0] jal(input integer rd, imm);
        jal = {imm[20], imm[10:1], imm[11], imm[19:12], rd[4:0], 7'h6f};
    endfunction
    function automatic [31:0] halt();
        halt = 32'h00000063; // beq x0,x0,0
    endfunction
    task automatic check(input integer regno, input logic [31:0] want);
        if (dut.datapath.regfile.rf[regno] !== want) begin
            $display("FAIL x%0d: got %h expected %h", regno,
                dut.datapath.regfile.rf[regno], want);
            errors++;
        end
    endtask
    always @(posedge clk) begin
        if (rst_n && wb_write && (wb_rd == 2 || wb_rd == 3 || wb_rd == 4)) begin
            $display("FAIL wrong-path write x%0d = %h", wb_rd, wb_data);
            poison_writes++;
        end
    end
    initial begin
        #1;
        // JAL +16: discard two younger instructions; link must be forwarded.
        dut.datapath.imem.rom[0] = addi(1, 0, 5);
        dut.datapath.imem.rom[1] = jal(5, 12); // PC 4 -> PC 16
        dut.datapath.imem.rom[2] = addi(2, 0, 99);
        dut.datapath.imem.rom[3] = addi(3, 0, 99);
        dut.datapath.imem.rom[4] = addi(6, 5, 1);
        dut.datapath.imem.rom[5] = jal(7, 16); // PC 20 -> PC 36
        dut.datapath.imem.rom[6] = addi(10, 9, 1); // negative jump target
        dut.datapath.imem.rom[7] = halt();
        dut.datapath.imem.rom[8] = addi(4, 0, 99);
        dut.datapath.imem.rom[9] = jal(9, -12); // PC 36 -> PC 24
        dut.datapath.imem.rom[10] = addi(4, 0, 99);
        dut.datapath.imem.rom[11] = addi(4, 0, 99);
        #19 rst_n = 1;
        repeat (65) @(negedge clk);
        check(1, 5);
        check(5, 8); check(6, 9); check(7, 24);
        check(9, 40); check(10, 41);
        if (poison_writes != 0) errors++;
        if (errors) $fatal(1, "JAL FAILED: %0d mismatches", errors);
        $display("PASS JAL forward/backward, link forwarding, two-instruction flush");
        $finish;
    end
endmodule
