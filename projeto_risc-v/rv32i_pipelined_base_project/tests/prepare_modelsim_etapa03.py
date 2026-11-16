#!/usr/bin/env python3
"""Gera imagens isoladas para simular a etapa 3 no ModelSim."""
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parent.parent
RUN = PROJECT / 'modelsim' / 'etapa03'


def main():
    RUN.mkdir(parents=True, exist_ok=True)
    original = (PROJECT / 'assembler' / 'etapa03_test.asm').read_text()
    (RUN / 'test.asm').write_text(original + 'beq x0,x0,0\n')
    subprocess.run([sys.executable, str(PROJECT / 'assembler' / 'assembler.py'),
                    str(RUN / 'test.asm')], cwd=RUN, check=True)
    program = (RUN / 'program.hex').read_text().splitlines()
    if not 0 < len(program) <= 256:
        raise ValueError(f'Programa excede a ROM de 256 palavras: {len(program)}')
    (RUN / 'program.hex').write_text('\n'.join(program + ['00000013'] * (256 - len(program))) + '\n')
    (RUN / 'data.hex').write_text('00000000\n' * 256)
    print(f'Preparado: {RUN} ({len(program)} instrucoes, ROM/RAM de 256 palavras).')
    print('O golden.txt legado nao e usado: etapa03_tb verifica o estado final.')


if __name__ == '__main__':
    main()
