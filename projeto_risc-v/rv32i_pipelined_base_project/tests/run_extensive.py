#!/usr/bin/env python3
"""Gera MIF/HEX isolados e compara CPU real com oráculos arquiteturais.

python3 tests/run_extensive.py [alu|memory|control]
IVERILOG, VVP e IVL_LIB_DIR aceitos para instalação local do Icarus.
As imagens ficam em tests/extensive/<caso>/, sem tocar em quartus/.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'src'
OUT = ROOT / 'tests' / 'extensive'
MASK = 0xffffffff

CASES = {
    'alu': {
        'asm': [
            'addi x1,x0,-1', 'addi x2,x0,31', 'sll x3,x1,x2',
            'srl x4,x3,x2', 'sra x5,x3,x2', 'slt x6,x1,x2',
            'sltu x7,x1,x2', 'xor x8,x1,x3', 'add x9,x8,x4',
            'sub x10,x4,x2', 'and x11,x8,x3', 'or x12,x8,x3',
            'sll x13,x4,x2', 'srai x14,x13,31', 'srli x15,x13,31',
            'slli x16,x15,31', 'slti x17,x1,0', 'slti x18,x2,-1',
            'andi x19,x1,127', 'ori x20,x0,-2047',
            'addi x21,x0,-2047', 'lui x22,-1', 'auipc x23,0',
            'addi x0,x0,5', 'addi x24,x0,2047',
            'addi x25,x24,-2047', 'srl x26,x3,x1',
            'sra x27,x3,x1', 'add x28,x24,x25',
        ],
        'regs': {1: MASK, 2: 31, 3: 0x80000000, 4: 1,
                 5: MASK, 6: 1, 7: 0, 8: 0x7fffffff,
                 9: 0x80000000, 10: 0xffffffe2, 11: 0,
                 12: MASK, 13: 0x80000000, 14: MASK,
                 15: 1, 16: 0x80000000, 17: 1, 18: 0,
                 19: 127, 20: 0xfffff801, 21: 0xfffff801,
                 22: 0xfffff000, 23: 22 * 4, 24: 2047,
                 25: 0, 26: 1, 27: MASK, 28: 2047},
        'memory': {},
    },
    'memory': {
        'asm': [
            'lui x1,-1', 'addi x1,x1,-1', 'sw x1,0(x0)',
            'lb x2,0(x0)', 'lbu x3,1(x0)',
            'lh x4,2(x0)', 'lhu x5,2(x0)',
            'addi x6,x0,128', 'sb x6,0(x0)', 'sh x6,2(x0)',
            'lw x7,0(x0)', 'lw x8,0(x0)', 'add x9,x8,x7',
            'sw x9,4(x0)', 'lw x10,4(x0)', 'lb x11,7(x0)',
            'sh x6,6(x0)', 'lhu x12,6(x0)',
        ],
        'regs': {1: 0xffffefff, 2: MASK, 3: 0xef,
                 4: MASK, 5: 0xffff, 6: 128,
                 7: 0x0080ef80, 8: 0x0080ef80,
                 9: 0x0101df00, 10: 0x0101df00,
                 11: 1, 12: 0x80},
        'memory': {0: 0x0080ef80, 1: 0x0080df00},
    },
    'control': {
        'asm': [
            'addi x31,x0,0', 'addi x1,x0,-1', 'addi x2,x0,1',
            'blt x1,x2,12', 'addi x31,x0,99', 'addi x31,x0,99',
            'bgeu x1,x2,12', 'addi x31,x0,99', 'addi x31,x0,99',
            'bne x1,x1,12', 'addi x3,x0,7',
            'beq x3,x3,12', 'addi x31,x0,99', 'addi x31,x0,99',
            'auipc x4,0', 'addi x4,x4,21', 'jalr x5,x4,0',
            'addi x31,x0,99', 'addi x31,x0,99',
            'addi x6,x5,1', 'jal x7,12',
            'addi x31,x0,99', 'addi x31,x0,99',
            'addi x8,x7,1',
        ],
        'regs': {31: 0, 1: MASK, 2: 1, 3: 7,
                 4: 14 * 4 + 21, 5: 17 * 4,
                 6: 17 * 4 + 1, 7: 21 * 4,
                 8: 21 * 4 + 1},
        'memory': {},
    },
}


def prepare(name, case):
    target = OUT / name
    target.mkdir(parents=True, exist_ok=True)
    lines = case['asm'] + ['beq x0,x0,0']
    (target / 'test.asm').write_text('\n'.join(lines) + '\n')
    result = subprocess.run([sys.executable, str(ROOT / 'assembler/assembler.py'),
                             str(target / 'test.asm')], cwd=target,
                            text=True, capture_output=True, check=True)
    words = (target / 'program.hex').read_text().splitlines()
    if len(words) != len(lines) or len(words) > 256:
        raise ValueError(f'{name}: imagem inconsistente: {len(words)} palavras')
    mif = target / 'instruction.mif'
    contents = mif.read_text()
    if len(words) < 256:
        mif.write_text(contents.removesuffix('END;') +
                       f'[{len(words):03X}..0FF] : 00000013;  -- nop\nEND;\n')
    (target / 'program.hex').write_text(
        '\n'.join(words + ['00000013'] * (256 - len(words))) + '\n')
    (target / 'data.hex').write_text('00000000\n' * 256)
    (target / 'data.mif').write_text(
        'DEPTH = 256;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\n'
        'DATA_RADIX = HEX;\nCONTENT\nBEGIN\n'
        '[000..0FF] : 00000000;\nEND;\n')
    regs = ['xxxxxxxx'] * 32
    for reg, value in case['regs'].items():
        regs[reg] = f'{value & MASK:08x}'
    (target / 'expected_regs.hex').write_text('\n'.join(regs) + '\n')
    data = [0] * 256
    for address, value in case['memory'].items():
        data[address] = value
    (target / 'expected_data.hex').write_text(
        ''.join(f'{value & MASK:08x}\n' for value in data))
    print(f'{name}: {len(lines)} instruções; ROM/RAM de 256 palavras; '
          f'{len(case["regs"])} registradores verificados')
    return target, (len(lines) - 1) * 4


def main():
    names = sys.argv[1:] or list(CASES)
    if any(name not in CASES for name in names):
        sys.exit('Caso desconhecido; escolha alu, memory ou control')
    sources = [SRC / 'pl_pipe_pkg.sv'] + [path for path in sorted(SRC.glob('*.sv'))
                                           if path.name not in ('pl_pipe_pkg.sv', 'pl_cpu_tb.sv')]
    with tempfile.TemporaryDirectory(prefix='rv32-ext-', dir=os.environ.get('TMPDIR')) as temp:
        binary = Path(temp) / 'sim.vvp'
        cmd = [os.environ.get('IVERILOG', 'iverilog')]
        if os.environ.get('IVL_LIB_DIR'):
            cmd += ['-B', os.environ['IVL_LIB_DIR']]
        cmd += ['-g2012', '-s', 'extensive_tb', '-o', str(binary)]
        cmd += [str(source) for source in sources]
        cmd += [str(ROOT / 'tests/extensive_tb.sv')]
        compile_result = subprocess.run(cmd, text=True, capture_output=True)
        if compile_result.returncode:
            print(compile_result.stdout + compile_result.stderr, file=sys.stderr)
            return compile_result.returncode
        if compile_result.stderr:
            print(f'Icarus: {len(compile_result.stderr.splitlines())} linhas de diagnóstico',
                  file=sys.stderr)
        failures = 0
        for name in names:
            target, halt_pc = prepare(name, CASES[name])
            result = subprocess.run([os.environ.get('VVP', 'vvp'), str(binary),
                                     f'+HALT_PC={halt_pc}'],
                                    cwd=target, text=True, capture_output=True)
            print(result.stdout, end='')
            if result.returncode or 'PASS oracle:' not in result.stdout:
                print(result.stderr, file=sys.stderr)
                failures += 1
        print(f'{len(names) - failures}/{len(names)} casos aprovados')
        return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
