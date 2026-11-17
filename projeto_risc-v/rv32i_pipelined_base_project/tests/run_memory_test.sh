#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
run_dir="$(mktemp -d "${TMPDIR:?Defina TMPDIR para diretorio temporario}/pl-memory-XXXXXX")"
trap 'rm -rf "$run_dir"' EXIT
# As duas memorias sao sobrescritas pelo testbench antes da liberacao do reset.
python3 - "$run_dir" <<'PY'
import pathlib, sys
run = pathlib.Path(sys.argv[1])
(run / 'program.hex').write_text('00000013\n' * 256)
(run / 'data.hex').write_text('00000000\n' * 256)
PY
src="$project/src"
# IVL_BASE permite usar uma instalacao extraida localmente do pacote .deb.
options=(-g2012 -s pl_memory_tb)
if [[ -n "${IVL_BASE:-}" ]]; then options+=(-B "$IVL_BASE"); fi
iverilog "${options[@]}" -o "$run_dir/memory.vvp" \
  "$src/pl_pipe_pkg.sv" \
  "$src/pl_alu.sv" "$src/pl_alu_ctrl.sv" "$src/pl_control.sv" \
  "$src/pl_cpu.sv" "$src/pl_datapath.sv" "$src/pl_dmem.sv" \
  "$src/pl_forward.sv" "$src/pl_hazard.sv" "$src/pl_imem.sv" \
  "$src/pl_mmio.sv" "$src/pl_regfile.sv" "$src/pl_sign_ext.sv" \
  "$src/pl_uart.sv" "$project/tests/pl_memory_tb.sv"
(cd "$run_dir" && vvp memory.vvp)
