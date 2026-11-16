#!/usr/bin/env python3
"""Compile the real CPU and run independent pipeline branch scenarios.

Set IVERILOG, VVP and optionally IVL_LIB_DIR if tools are not on PATH.
Run from any directory: python3 tests/run_branches.py [scenario-name].
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
SRC = ROOT.parent / 'src'
CASES = [
    ('beq_equal', 0, 1, 1, 1),
    ('beq_unequal', 0, 1, 2, 0),
    ('bne_unequal', 1, 1, 2, 1),
    ('bne_equal', 1, -1, -1, 0),
    ('blt_negative', 4, -1, 1, 1),
    ('blt_positive', 4, 1, -1, 0),
    ('blt_equal', 4, -1, -1, 0),
    ('blt_boundary', 4, -2048, 2047, 1),
    ('bge_negative', 5, -1, 1, 0),
    ('bge_positive', 5, 1, -1, 1),
    ('bge_equal', 5, -1, -1, 1),
    ('bge_boundary', 5, 2047, -2048, 1),
    ('bltu_negative', 6, -1, 1, 0),
    ('bltu_positive', 6, 1, -1, 1),
    ('bltu_equal', 6, 1, 1, 0),
    ('bgeu_negative', 7, -1, 1, 1),
    ('bgeu_positive', 7, 1, -1, 0),
    ('bgeu_equal', 7, 1, 1, 1),
    ('beq_load_stall', 0, 1, 1, 1, 'LOAD'),
    ('blt_load_stall', 4, -1, 1, 1, 'LOAD'),
    ('blt_backward', 4, 0, 0, 1, 'LOOP'),
    ('reserved_010', 2, 1, 1, 0),
    ('reserved_011', 3, 1, 1, 0),
]


def main():
    selected = sys.argv[1:]
    cases = [c for c in CASES if not selected or c[0] in selected]
    if not cases or any(name not in [c[0] for c in cases] for name in selected):
        sys.exit('Unknown scenario: ' + ' '.join(selected))
    iverilog = os.environ.get('IVERILOG', 'iverilog')
    vvp = os.environ.get('VVP', 'vvp')
    sources = [SRC / 'pl_pipe_pkg.sv'] + [p for p in sorted(SRC.glob('*.sv'))
                                             if p.name not in ('pl_pipe_pkg.sv', 'pl_cpu_tb.sv')]
    with tempfile.TemporaryDirectory(prefix='branches-') as temp:
        executable = Path(temp) / 'branches.vvp'
        cmd = [iverilog]
        if os.environ.get('IVL_LIB_DIR'):
            cmd += ['-B', os.environ['IVL_LIB_DIR']]
        cmd += ['-g2012', '-s', 'branches_tb', '-o', str(executable)]
        cmd += [str(p) for p in sources] + [str(ROOT / 'branches_tb.sv')]
        compile_result = subprocess.run(cmd, text=True, capture_output=True)
        if compile_result.returncode:
            print(compile_result.stdout + compile_result.stderr, file=sys.stderr)
            return compile_result.returncode
        if compile_result.stderr:
            print('Compiler diagnostics (pre-existing Icarus constant-select limitations): '
                  + str(len(compile_result.stderr.splitlines())) + ' lines', file=sys.stderr)
        failed = []
        for case in cases:
            name, funct3, a, b, taken, *flags = case
            args = [f'+F3={funct3}', f'+A={a}', f'+B={b}', f'+TAKEN={taken}']
            args.extend(f'+{flag}=1' for flag in flags)
            result = subprocess.run([vvp, str(executable), *args], cwd=ROOT,
                                    text=True, capture_output=True)
            if result.returncode or not result.stdout.startswith('PASS '):
                failed.append(name)
                print(f'FAIL {name}: {result.stdout.strip()} {result.stderr.strip()}')
            else:
                print(f'PASS {name}')
        print(f'{len(cases)-len(failed)}/{len(cases)} scenarios passed')
        return bool(failed)


if __name__ == '__main__':
    sys.exit(main())
