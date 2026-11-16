#!/usr/bin/env python3
"""Assemble etapa 3 in scratch and execute it on the real CPU via Icarus."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parent.parent
SRC = PROJECT / 'src'
IVERILOG = os.environ.get('IVERILOG', 'iverilog')
VVP = os.environ.get('VVP', 'vvp')


def main():
    with tempfile.TemporaryDirectory(prefix='etapa03-', dir=os.environ.get('TMPDIR')) as tmp:
        run = Path(tmp)
        source = (PROJECT / 'assembler/etapa03_test.asm').read_text()
        (run / 'test.asm').write_text(source + 'beq x0,x0,0\n')
        (run / 'data.hex').write_text('00000000\n' * 256)
        subprocess.run([sys.executable, str(PROJECT / 'assembler/assembler.py'),
                        str(run / 'test.asm')], cwd=run, check=True)
        sources = [SRC / 'pl_pipe_pkg.sv'] + [p for p in sorted(SRC.glob('*.sv'))
                                             if p.name not in ('pl_pipe_pkg.sv', 'pl_cpu_tb.sv')]
        cmd = [IVERILOG]
        if os.environ.get('IVL_LIB_DIR'):
            cmd += ['-B', os.environ['IVL_LIB_DIR']]
        cmd += ['-g2012', '-s', 'etapa03_tb',
               '-o', str(run / 'sim.vvp'), *map(str, sources),
               str(PROJECT / 'tests/etapa03_tb.sv')]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode:
            print(result.stdout + result.stderr, file=sys.stderr)
            return result.returncode
        if result.stderr:
            print(f'Icarus: {len(result.stderr.splitlines())} diagnostic lines', file=sys.stderr)
        return subprocess.run([VVP, str(run / 'sim.vvp')], cwd=run).returncode


if __name__ == '__main__':
    sys.exit(main())
