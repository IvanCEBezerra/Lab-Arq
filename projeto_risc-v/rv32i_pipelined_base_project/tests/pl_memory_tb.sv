`timescale 1ns/1ps
// Integração CPU: somente acessos naturalmente alinhados, inclusive offsets na palavra.
module pl_memory_tb;
    logic clk = 0, rst_n = 0;
    logic [31:0] pc;
    logic [17:0] ledr;
    logic [8:0] ledg;
    logic uart_txd;
    always #5 clk = ~clk;

    pl_cpu dut (.clk(clk), .rst_n(rst_n), .PC(pc), .SW(18'h15555),
        .KEY_IO(4'hf), .LEDR(ledr), .LEDG(ledg),
        .UART_TXD(uart_txd), .UART_RXD(1'b1),
        .wb_reg_write(), .wb_reg_dst(), .wb_reg_data(),
        .mem_wr_en(), .mem_wr_addr(), .mem_wr_data());

    function automatic [31:0] ld(input int imm, rs1, f3, rd);
        ld = {12'(imm), 5'(rs1), 3'(f3), 5'(rd), 7'h03};
    endfunction
    function automatic [31:0] st(input int imm, rs1, rs2, f3);
        st = {7'(imm >> 5), 5'(rs2), 5'(rs1), 3'(f3), 5'(imm), 7'h23};
    endfunction
    function automatic [31:0] addi(input int imm, rs1, rd);
        addi = {12'(imm), 5'(rs1), 3'b000, 5'(rd), 7'h13};
    endfunction
    task automatic check(input string what, input logic [31:0] actual, expected);
        if (actual !== expected) $fatal(1, "%s: got %08x expected %08x", what, actual, expected);
        $display("PASS %s = %08x", what, actual);
    endtask

    initial begin
        #1; // $readmemh da ROM/RAM terminou
        dut.datapath.dmem.ram[0] = 32'h80ff7f01;
        dut.datapath.dmem.ram[1] = 32'h11223344;
        dut.datapath.imem.rom[0]  = ld(3, 0, 0, 1); // LB sinal negativo, byte 3
        dut.datapath.imem.rom[1]  = ld(3, 0, 4, 2); // LBU byte 3
        dut.datapath.imem.rom[2]  = ld(2, 0, 1, 3); // LH offset 2
        dut.datapath.imem.rom[3]  = ld(2, 0, 5, 4); // LHU offset 2
        dut.datapath.imem.rom[4]  = ld(1, 0, 0, 5); // LB positivo
        dut.datapath.imem.rom[5]  = ld(2, 0, 4, 6); // LBU byte 2
        dut.datapath.imem.rom[6]  = ld(0, 0, 1, 7); // LH offset 0
        dut.datapath.imem.rom[7]  = ld(0, 0, 2, 8); // LW preservado
        dut.datapath.imem.rom[8]  = st(5, 0, 2, 0); // SB altera apenas byte 1
        dut.datapath.imem.rom[9]  = st(6, 0, 4, 1); // SH altera metade alta
        dut.datapath.imem.rom[10] = ld(4, 0, 2, 9); // LW apos duas escritas
        dut.datapath.imem.rom[11] = st(12, 0, 9, 2); // SW dependente de LW
        dut.datapath.imem.rom[12] = ld(12, 0, 2, 10);
        dut.datapath.imem.rom[13] = st(8, 0, 8, 2); // SW preservado
        dut.datapath.imem.rom[14] = addi(12'h408, 0, 11);
        dut.datapath.imem.rom[15] = st(0, 11, 5, 2); // SW LEDR
        dut.datapath.imem.rom[16] = st(0, 11, 8, 0); // SB MMIO proibido
        dut.datapath.imem.rom[17] = st(0, 11, 8, 1); // SH MMIO proibido
        dut.datapath.imem.rom[18] = st(16, 0, 8, 2); // prepara palavra para demais lanes
        dut.datapath.imem.rom[19] = st(16, 0, 5, 0); // SB byte 0
        dut.datapath.imem.rom[20] = st(18, 0, 5, 0); // SB byte 2
        dut.datapath.imem.rom[21] = st(19, 0, 5, 0); // SB byte 3
        dut.datapath.imem.rom[22] = st(16, 0, 4, 1); // SH metade baixa
        dut.datapath.imem.rom[23] = addi(12'h400, 0, 13);
        dut.datapath.imem.rom[24] = ld(0, 13, 2, 12); // LW MMIO chaves intacto
        dut.datapath.imem.rom[25] = 32'h00000063; // beq x0,x0,0
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (90) @(negedge clk);
        check("LB negativo", dut.datapath.regfile.rf[1], 32'hffffff80);
        check("LBU", dut.datapath.regfile.rf[2], 32'h00000080);
        check("LH negativo", dut.datapath.regfile.rf[3], 32'hffff80ff);
        check("LHU", dut.datapath.regfile.rf[4], 32'h000080ff);
        check("LB positivo", dut.datapath.regfile.rf[5], 32'h0000007f);
        check("LBU byte 2", dut.datapath.regfile.rf[6], 32'h000000ff);
        check("LH offset 0", dut.datapath.regfile.rf[7], 32'h00007f01);
        check("LW original", dut.datapath.regfile.rf[8], 32'h80ff7f01);
        check("SB/SH sem corromper vizinhos", dut.datapath.dmem.ram[1], 32'h80ff8044);
        check("LW apos SB/SH", dut.datapath.regfile.rf[9], 32'h80ff8044);
        check("SW apos load-use", dut.datapath.regfile.rf[10], 32'h80ff8044);
        check("SW legado", dut.datapath.dmem.ram[2], 32'h80ff7f01);
        check("SW MMIO; SB/SH ignorados", {14'b0, ledr}, 32'h0000007f);
        check("SB lanes 0/2/3 e SH lane 0", dut.datapath.dmem.ram[4], 32'h7f7f80ff);
        check("LW MMIO", dut.datapath.regfile.rf[12], 32'h00015555);
        $display("PASS pl_memory_tb");
        $finish;
    end
endmodule
