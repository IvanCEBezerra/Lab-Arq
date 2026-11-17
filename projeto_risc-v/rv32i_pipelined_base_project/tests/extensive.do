# Execute a partir de tests/extensive/<caso> depois de gerar imagens.
# Ex.: vsim -c -do ../../extensive.do
onerror {quit -code 1}
onbreak {quit -code 1}
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv -work work ../../../src/pl_pipe_pkg.sv
foreach source [lsort [glob ../../../src/*.sv]] {
    set name [file tail $source]
    if {$name ni {pl_pipe_pkg.sv pl_cpu_tb.sv pl_top.sv pl_top_no_pll.sv}} {
        vlog -sv -work work $source
    }
}
vlog -sv -work work ../../extensive_tb.sv
set fp [open test.asm r]
set asm [read $fp]
close $fp
set halt_pc [expr {([llength [split [string trim $asm] "\n"]] - 1) * 4}]
vsim -voptargs=+acc work.extensive_tb +HALT_PC=$halt_pc
run -all
if {![info exists env(MODELSIM_GUI)]} {quit -code 0}
