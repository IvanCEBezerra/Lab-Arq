# DE2-115: CLOCK_50 = 50 MHz; ALTPLL em pll_10mhz.v gera clk_cpu = 10 MHz.
# O nome interno do PLL depende da versao do Quartus: deixar TimeQuest derivar
# os clocks gerados em vez de fixar pinos de uma hierarquia nao verificada.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_pll_clocks
derive_clock_uncertainty

# Entradas manuais/serial nao sao sincronas ao oscilador da placa.
# KEY[0] controla reset assincrono; as demais entradas sao MMIO.
set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {SW[*]}]
set_false_path -from [get_ports {UART_RXD}]
# LEDs e serial sao observados externamente, sem clock de captura correlacionado.
set_false_path -to [get_ports {LEDR[*]}]
set_false_path -to [get_ports {LEDG[*]}]
set_false_path -to [get_ports {UART_TXD}]

# Nao dispensar verificacao do report_clocks (10 MHz), de caminhos internos
# sem constraint, de slack e da inferencia/inicializacao das duas memorias.
# Estas excecoes nao substituem sincronizacao/debounce fisico das entradas.
