# Execute a partir de rv32i_pipelined_base_project/modelsim/etapa03:
#   vsim -c -do ../../tests/etapa03_modelsim.do
# Antes: python3 tests/prepare_modelsim_etapa03.py (na raiz do subprojeto).
# program.hex e data.hex sao lidos em relacao ao diretorio corrente.
onerror {quit -code 1}
onbreak {quit -code 1}
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv -work work ../../src/pl_pipe_pkg.sv
foreach source [lsort [glob ../../src/*.sv]] {
    set name [file tail $source]
    if {$name ni {pl_pipe_pkg.sv pl_cpu_tb.sv pl_top.sv pl_top_no_pll.sv}} {
        vlog -sv -work work $source
    }
}
vlog -sv -work work ../../tests/etapa03_tb.sv
vsim -voptargs=+acc work.etapa03_tb
run -all
if {![info exists env(MODELSIM_GUI)]} {quit -code 0}
