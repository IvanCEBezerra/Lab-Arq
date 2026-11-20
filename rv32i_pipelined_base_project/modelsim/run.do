# Execute na raiz do projeto. Opcoes: run_dir e sim_args.
onerror {quit -code 1}
set rtl [file normalize src]
if {![info exists run_dir]} {set run_dir modelsim}
if {![info exists sim_args]} {set sim_args {}}
cd [file normalize $run_dir]
if {![file isfile program.hex] || ![file isfile data.hex]} {
    puts stderr "program.hex e data.hex sao obrigatorios em [pwd]"
    quit -code 1
}
if {![file isdirectory work]} {vlib work}
vmap work work
vlog -sv -work work [file join $rtl pl_pipe_pkg.sv]
foreach source [lsort [glob -directory $rtl *.sv]] {
    if {[file tail $source] ni {pl_pipe_pkg.sv pl_top.sv pl_top_no_pll.sv}} {
        vlog -sv -work work $source
    }
}
vsim -onfinish stop -voptargs=+acc work.pl_cpu_tb {*}$sim_args
run -all
if {[examine -radix unsigned sim:/pl_cpu_tb/simulation_ok] ne "1"} {quit -code 1}
quit -code 0
