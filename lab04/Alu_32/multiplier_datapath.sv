// multiplier_datapath.sv
// Datapath da unidade de multiplicacao (32 bits)
// Versao Refinada (Patterson & Hennessy)

module multiplier_datapath (
    input  logic        clk,
    input  logic        rst_n,

    // Entradas de dados
    input  logic [31:0] multiplicand_in,
    input  logic [31:0] multiplier_in,

    // Sinais de controle vindos da FSM
    input  logic        load,        // Carrega operandos iniciais
    input  logic        product_wr,  // Escreve soma da ALU em product_reg
    input  logic        shift_en,    // Shift right global

    // Saidas de status para a FSM
    output logic        multiplier_lsb, // LSB do produto (testa o bit do multiplicador)

    // Saida do resultado final (64 bits)
    output logic [63:0] product
);

    // -----------------------------------------------------------------------
    // Registradores internos (Versao Refinada)
    // -----------------------------------------------------------------------
    logic [31:0] multiplicand_reg; // Multiplicando fixo em 32 bits[cite: 2]
    logic [64:0] product_reg;      // 65 bits para acomodar produto + carry-out[cite: 2]

    // -----------------------------------------------------------------------
    // ALU (32 bits com saida de 33 bits)
    // -----------------------------------------------------------------------
    logic [32:0] alu_sum;          // Soma de 32+32 bits + carry-out[cite: 2]

    alu_32 alu (
        .a   (product_reg[63:32]), // Metade superior do produto[cite: 2]
        .b   (multiplicand_reg),   // Multiplicando[cite: 2]
        .sum (alu_sum)             // Resultado de 33 bits[cite: 2]
    );

    // -----------------------------------------------------------------------
    // Saidas combinacionais
    // -----------------------------------------------------------------------
    assign multiplier_lsb = product_reg[0];    // Bit LSB lido direto do produto[cite: 2]
    assign product        = product_reg[63:0]; // Saida final descartando o 65º bit[cite: 2]

    // -----------------------------------------------------------------------
    // Atualizacao dos registradores
    // -----------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            multiplicand_reg <= '0;
            product_reg      <= '0;
        end else if (load) begin
            multiplicand_reg <= multiplicand_in;
            product_reg      <= {33'b0, multiplier_in}; // Carga inicial[cite: 2]
        end else if (product_wr) begin
            product_reg[64:32] <= alu_sum;             // Escreve resultado da ALU[cite: 2]
        end else if (shift_en) begin
            product_reg <= {1'b0, product_reg[64:1]};   // Desloca tudo para a direita[cite: 2]
        end
    end

endmodule