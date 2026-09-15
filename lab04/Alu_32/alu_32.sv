// alu_32.sv
// ALU de 32 bits com saída de 33 bits (Soma + Carry Out)
// Projetada para a versão refinada do multiplicador (Patterson & Hennessy)

module alu_32 (
    input  logic [31:0] a,    // Metade superior do registrador de produto (32 bits)[cite: 2]
    input  logic [31:0] b,    // Multiplicando (32 bits)[cite: 2]
    output logic [32:0] sum   // Resultado de 33 bits (32 bits de soma + 1 bit de Carry Out)[cite: 2]
);

    // A adição de dois vetores de 32 bits atribui o Carry Out no 33º bit (sum[32])
    assign sum = a + b;

endmodule