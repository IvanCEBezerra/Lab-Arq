`timescale 1ns/1ps

// End-to-end branch tests: decode, forwarding, signedness, target and two flushes.
module branches_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    wire [31:0] PC;
    wire [17:0] LEDR;
    wire [8:0] LEDG;
    wire UART_TXD, wb_reg_write, mem_wr_en;
    wire [4:0] wb_reg_dst;
    wire [31:0] wb_reg_data, mem_wr_data;
    wire [7:0] mem_wr_addr;
    pl_cpu dut (
        .clk(clk), .rst_n(rst_n), .PC(PC), .SW(18'b0), .KEY_IO(4'hf),
        .LEDR(LEDR), .LEDG(LEDG), .UART_TXD(UART_TXD), .UART_RXD(1'b1),
        .wb_reg_write(wb_reg_write), .wb_reg_dst(wb_reg_dst),
        .wb_reg_data(wb_reg_data), .mem_wr_en(mem_wr_en),
        .mem_wr_addr(mem_wr_addr), .mem_wr_data(mem_wr_data)
    );

    function automatic [31:0] addi(input [4:0] rd, rs1, input integer imm);
        addi = {12'(imm), rs1, 3'b000, rd, 7'b0010011};
    endfunction
    function automatic [31:0] branch(input [2:0] f3, input [4:0] rs1, rs2,
                                     input integer offset);
        branch = {offset[12], offset[10:5], rs2, rs1, f3,
                  offset[4:1], offset[11], 7'b1100011};
    endfunction

    integer f3, a, b, taken, load_case, loop_case, i;
    initial begin
        if (!$value$plusargs("F3=%d", f3)) $fatal(1, "F3 missing");
        if (!$value$plusargs("A=%d", a)) $fatal(1, "A missing");
        if (!$value$plusargs("B=%d", b)) $fatal(1, "B missing");
        if (!$value$plusargs("TAKEN=%d", taken)) $fatal(1, "TAKEN missing");
        if (!$value$plusargs("LOAD=%d", load_case)) load_case = 0;
        if (!$value$plusargs("LOOP=%d", loop_case)) loop_case = 0;
        #1;
        for (i = 0; i < 256; i++) dut.datapath.imem.rom[i] = 32'h00000013;
        for (i = 0; i < 32; i++) dut.datapath.regfile.rf[i] = 32'b0;
        if (loop_case != 0) begin
            // PC=12 branches backwards to PC=4 twice, then falls through.
            dut.datapath.imem.rom[0] = addi(1, 0, 0);
            dut.datapath.imem.rom[1] = addi(1, 1, 1);
            dut.datapath.imem.rom[2] = addi(2, 0, 3);
            dut.datapath.imem.rom[3] = branch(3'(f3), 1, 2, -8);
            dut.datapath.imem.rom[4] = addi(10, 0, 1);
            dut.datapath.imem.rom[5] = branch(3'b000, 0, 0, 0);
        end else begin
            dut.datapath.imem.rom[0] = addi(2, 0, b);
            if (load_case != 0) begin
                dut.datapath.dmem.ram[0] = 32'(a);
                dut.datapath.imem.rom[1] = 32'h00002083; // lw x1, 0(x0)
            end else dut.datapath.imem.rom[1] = addi(1, 0, a);
            dut.datapath.imem.rom[2] = branch(3'(f3), 1, 2, 16);
            dut.datapath.imem.rom[3] = addi(10, 0, 1); // first flushed instruction
            dut.datapath.imem.rom[4] = addi(11, 0, 1); // second flushed instruction
            dut.datapath.imem.rom[5] = addi(12, 0, 1); // fall-through only
            dut.datapath.imem.rom[6] = addi(13, 0, 1); // target at PC=24
            dut.datapath.imem.rom[7] = branch(3'b000, 0, 0, 0);
        end
        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (45) @(negedge clk);
        if (loop_case != 0) begin
            if (dut.datapath.regfile.rf[1] !== 32'd3 ||
                dut.datapath.regfile.rf[10] !== 32'd1)
                $fatal(1, "backward branch: x1=%h x10=%h PC=%h",
                       dut.datapath.regfile.rf[1], dut.datapath.regfile.rf[10], PC);
        end else begin
            if (dut.datapath.regfile.rf[1] !== 32'(a) ||
                dut.datapath.regfile.rf[2] !== 32'(b) ||
                dut.datapath.regfile.rf[10] !== 32'(!taken) ||
                dut.datapath.regfile.rf[11] !== 32'(!taken) ||
                dut.datapath.regfile.rf[12] !== 32'(!taken) ||
                dut.datapath.regfile.rf[13] !== 32'd1)
                $fatal(1, "f3=%d a=%d b=%d taken=%d x10=%h x11=%h x12=%h x13=%h",
                       f3, a, b, taken, dut.datapath.regfile.rf[10],
                       dut.datapath.regfile.rf[11], dut.datapath.regfile.rf[12],
                       dut.datapath.regfile.rf[13]);
        end
        $display("PASS f3=%0d a=%0d b=%0d taken=%0d load=%0d loop=%0d",
                 f3, a, b, taken, load_case, loop_case);
        $finish;
    end
endmodule
