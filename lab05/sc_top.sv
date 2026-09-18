`timescale 1ns / 1ps

// =============================================================================
// sc_top.sv
// Modulo top-level do processador RISC-V monociclo
//
// Hierarquia do projeto:
//   sc_top
//     sc_cpu          - Nucleo da CPU (controle + datapath)
//       sc_control    - Decodificador de instrucoes / unidade de controle
//       sc_datapath   - Caminho de dados completo
//         sc_imem, sc_regfile, sc_sign_ext, sc_alu_ctrl, sc_alu, sc_dmem
//
// Placa-alvo: Altera DE2-115 (FPGA Cyclone IV E, clock de 50 MHz)
//   CLOCK_50 -> clk
//   KEY[0]   -> rst_n (reset ativo em nivel baixo)
// =============================================================================

module sc_top (
    input  logic        clk,
    input  logic        rst_n,    // reset assincrono ativo em nivel baixo (KEY[0])
    output logic [31:0] PC        // valor atual do PC (para debug e testbench)
);

    sc_cpu cpu (
        .clk   (clk),
        .rst_n (rst_n),
        .PC    (PC)
    );

endmodule
