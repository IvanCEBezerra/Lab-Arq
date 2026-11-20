"""Assembly-to-memory-image converter for the course RV32I CPU.

Original assembler by Nathalia Barbosa (@nathaliafab), 2023-06-16.
See README.md for supported syntax and usage.
"""

import argparse
import re
from pathlib import Path

# ---------------------------------------------------------------------------
# --dump mode constants
# ---------------------------------------------------------------------------
# Instruction memory: dump code always starts at word address DUMP_START.
DUMP_START = 0x80

# Data memory layout (word addresses):
#   0x000..0x01F : user data area (byte 0x000..0x07C) — sent in mem dump
#   0x078..0x07F : saves x1-x8  (bytes 0x1E0..0x1FC)  — written at runtime
#   0x080..0x086 : infrastructure constants            — initialised in data.mif
SAVES_WBASE = 0x78               # first word address of saves area
SAVES_BBASE = SAVES_WBASE * 4    # = 0x1E0 = 480  (byte offset for sw from x0)
SAVES_BEND  = (SAVES_WBASE + 8) * 4  # = 0x200 = 512  (exclusive end for loop)

INFRA_WBASE = 0x80
INFRA_BBASE = INFRA_WBASE * 4   # = 0x200 = 512  (fits in 12-bit signed imm)

NOP_WORD = "00000013"  # addi x0, x0, 0

# Register allocation in dump code:
#   x13=status tmp, x14=ptr, x15=UART addr, x16=ptr end,
#   x17=tx_busy mask, x18=step, x19=word to send,
#   x20=MMIO base, x21=LEDG, x22=CYCLE addr, x23=saves start, x24=saves end
INFRA_DATA = [
    (INFRA_WBASE + 0, 0x00000410, "UART TX/status addr      -> x15"),
    (INFRA_WBASE + 1, 0x00000200, "tx_busy mask (bit 9)     -> x17"),
    (INFRA_WBASE + 2, 0x00000004, "step = 4                 -> x18"),
    (INFRA_WBASE + 3, 0x00000400, "MMIO base 0x400          -> x20"),
    (INFRA_WBASE + 4, 0x000001FF, "LEDG all-on 0x1FF        -> x21"),
    (INFRA_WBASE + 5, SAVES_BBASE, f"saves start byte 0x{SAVES_BBASE:03X} -> x23"),
    (INFRA_WBASE + 6, SAVES_BEND,  f"saves end   byte 0x{SAVES_BEND:03X} -> x24"),
]

INSTRUCTION = {
 "lui": {
  "format": "U",
  "opcode": "0110111",
  "funct3": "",
  "funct7": ""
 },
 "auipc": {
  "format": "U",
  "opcode": "0010111",
  "funct3": "",
  "funct7": ""
 },
 "jal": {
  "format": "J",
  "opcode": "1101111",
  "funct3": "",
  "funct7": ""
 },
 "jalr": {
  "format": "I",
  "opcode": "1100111",
  "funct3": "000",
  "funct7": ""
 },
 "beq": {
  "format": "B",
  "opcode": "1100011",
  "funct3": "000",
  "funct7": ""
 },
 "bne": {
  "format": "B",
  "opcode": "1100011",
  "funct3": "001",
  "funct7": ""
 },
 "blt": {
  "format": "B",
  "opcode": "1100011",
  "funct3": "100",
  "funct7": ""
 },
 "bge": {
  "format": "B",
  "opcode": "1100011",
  "funct3": "101",
  "funct7": ""
 },
 "bltu": {
  "format": "B",
  "opcode": "1100011",
  "funct3": "110",
  "funct7": ""
 },
 "bgeu": {
  "format": "B",
  "opcode": "1100011",
  "funct3": "111",
  "funct7": ""
 },
 "lb": {
  "format": "I",
  "opcode": "0000011",
  "funct3": "000",
  "funct7": ""
 },
 "lh": {
  "format": "I",
  "opcode": "0000011",
  "funct3": "001",
  "funct7": ""
 },
 "lw": {
  "format": "I",
  "opcode": "0000011",
  "funct3": "010",
  "funct7": ""
 },
 "lbu": {
  "format": "I",
  "opcode": "0000011",
  "funct3": "100",
  "funct7": ""
 },
 "lhu": {
  "format": "I",
  "opcode": "0000011",
  "funct3": "101",
  "funct7": ""
 },
 "sb": {
  "format": "S",
  "opcode": "0100011",
  "funct3": "000",
  "funct7": ""
 },
 "sh": {
  "format": "S",
  "opcode": "0100011",
  "funct3": "001",
  "funct7": ""
 },
 "sw": {
  "format": "S",
  "opcode": "0100011",
  "funct3": "010",
  "funct7": ""
 },
 "addi": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "000",
  "funct7": ""
 },
 "slti": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "010",
  "funct7": ""
 },
 "sltiu": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "011",
  "funct7": ""
 },
 "xori": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "100",
  "funct7": ""
 },
 "ori": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "110",
  "funct7": ""
 },
 "andi": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "111",
  "funct7": ""
 },
 "slli": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "001",
  "funct7": "0000000"
 },
 "srli": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "101",
  "funct7": "0000000"
 },
 "srai": {
  "format": "I",
  "opcode": "0010011",
  "funct3": "101",
  "funct7": "0100000"
 },
 "add": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "000",
  "funct7": "0000000"
 },
 "sub": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "000",
  "funct7": "0100000"
 },
 "sll": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "001",
  "funct7": "0000000"
 },
 "slt": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "010",
  "funct7": "0000000"
 },
 "sltu": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "011",
  "funct7": "0000000"
 },
 "xor": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "100",
  "funct7": "0000000"
 },
 "srl": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "101",
  "funct7": "0000000"
 },
 "sra": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "101",
  "funct7": "0100000"
 },
 "or": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "110",
  "funct7": "0000000"
 },
 "and": {
  "format": "R",
  "opcode": "0110011",
  "funct3": "111",
  "funct7": "0000000"
 },
}


# creates the file and writes the header
REGISTER_NAMES = (
    "zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 "
    "a6 a7 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6"
).split()
REGISTERS = {f"x{index}": index for index in range(32)}
REGISTERS.update({name: index for index, name in enumerate(REGISTER_NAMES)})
REGISTERS["fp"] = 8
LOADS = {"lb", "lh", "lw", "lbu", "lhu"}
SHIFTS = {"slli", "srli", "srai"}
LABEL = re.compile(r"[A-Za-z_.$][\w.$]*")
MEMORY_OPERAND = re.compile(r"\s*([^()]*)\(\s*([^()\s]+)\s*\)\s*")
DEPTH = 256
HALT_WORD = "00000063"


def register(name):
    try:
        return REGISTERS[name.lower()]
    except KeyError:
        raise ValueError(f"Registrador inválido: {name}") from None


def number(token):
    try:
        if re.fullmatch(r"[+-]?\d+", token):
            return int(token, 10)
        return int(token, 0)
    except ValueError:
        raise ValueError(f"Imediato inválido: {token}") from None


def immediate(value, bits, allow_unsigned=False):
    low = -(1 << (bits - 1))
    high = (1 << (bits if allow_unsigned else bits - 1)) - 1
    if not low <= value <= high:
        raise ValueError(f"Imediato {value} fora do intervalo {low}..{high}")
    return value & ((1 << bits) - 1)


def memory_operand(operand):
    match = MEMORY_OPERAND.fullmatch(operand)
    if match is None:
        raise ValueError(f"Operando de memória inválido: {operand}")
    offset, base = match.groups()
    return register(base), number(offset.strip() or "0")


def parse_instruction(source):
    parts = source.strip().split(maxsplit=1)
    if not parts:
        raise ValueError("Instrução vazia")
    operands = [item.strip() for item in parts[1].split(",")] if len(parts) == 2 else []
    return parts[0].lower(), operands


def expand(mnemonic, operands):
    if mnemonic == "nop" and not operands:
        return [("addi", ["x0", "x0", "0"])]
    if mnemonic == "ret" and not operands:
        return [("jalr", ["x0", "ra", "0"])]
    if mnemonic == "j" and len(operands) == 1:
        return [("jal", ["x0", operands[0]])]
    if mnemonic == "mv" and len(operands) == 2:
        return [("addi", [*operands, "0"])]
    if mnemonic == "li" and len(operands) == 2:
        dest, literal = operands
        value = number(literal)
        if not -(1 << 31) <= value <= (1 << 32) - 1:
            raise ValueError(f"Constante de 32 bits fora do intervalo: {literal}")
        if value >= (1 << 31):
            value -= 1 << 32
        if -2048 <= value <= 2047:
            return [("addi", [dest, "x0", str(value)])]
        upper = (value + 2048) >> 12
        lower = value - (upper << 12)
        return [("lui", [dest, str(upper)]), ("addi", [dest, dest, str(lower)])]
    return [(mnemonic, operands)]


def control_offset(token, labels, pc, bits):
    if LABEL.fullmatch(token):
        if token not in labels:
            raise ValueError(f"Rótulo indefinido: {token}")
        value = labels[token] - pc
    else:
        value = number(token)
    if value % 4 != 0:
        raise ValueError(f"Deslocamento {value} deve ser múltiplo de 4 (sem instruções comprimidas)")
    return immediate(value, bits)


def encode(mnemonic, operands, labels, pc):
    info = INSTRUCTION.get(mnemonic)
    if info is None:
        raise ValueError(f"Instrução não suportada: {mnemonic}")
    fmt = info["format"]
    opcode = int(info["opcode"], 2)
    funct3 = int(info["funct3"] or "0", 2) << 12
    funct7 = int(info["funct7"] or "0", 2) << 25
    count = 2 if fmt in {"U", "J", "S"} or mnemonic in LOADS else 3
    if mnemonic == "jal" and len(operands) == 1:
        operands = ["ra", operands[0]]
    if mnemonic == "jalr" and len(operands) == 2:
        base, offset = memory_operand(operands[1])
        operands = [operands[0], f"x{base}", str(offset)]
    if len(operands) != count or not all(operands):
        raise ValueError(f"{mnemonic} requer {count} operandos")

    if fmt == "R":
        rd, rs1, rs2 = map(register, operands)
        return funct7 | rs2 << 20 | rs1 << 15 | funct3 | rd << 7 | opcode
    if fmt == "U":
        rd = register(operands[0])
        imm = immediate(number(operands[1]), 20, allow_unsigned=True)
        return imm << 12 | rd << 7 | opcode
    if fmt == "J":
        rd = register(operands[0])
        imm = control_offset(operands[1], labels, pc, 21)
        return ((imm >> 20) << 31 | ((imm >> 1) & 0x3ff) << 21 |
                ((imm >> 11) & 1) << 20 | ((imm >> 12) & 0xff) << 12 | rd << 7 | opcode)
    if fmt == "B":
        rs1, rs2 = map(register, operands[:2])
        imm = control_offset(operands[2], labels, pc, 13)
        return ((imm >> 12) << 31 | ((imm >> 5) & 0x3f) << 25 | rs2 << 20 |
                rs1 << 15 | funct3 | ((imm >> 1) & 0xf) << 8 | ((imm >> 11) & 1) << 7 | opcode)
    if fmt == "S":
        rs2 = register(operands[0])
        rs1, offset = memory_operand(operands[1])
        imm = immediate(offset, 12)
        return (imm >> 5) << 25 | rs2 << 20 | rs1 << 15 | funct3 | (imm & 31) << 7 | opcode

    rd = register(operands[0])
    if mnemonic in SHIFTS:
        rs1 = register(operands[1])
        shamt = number(operands[2])
        if not 0 <= shamt <= 31:
            raise ValueError("Deslocamento fora do intervalo 0..31")
        return funct7 | shamt << 20 | rs1 << 15 | funct3 | rd << 7 | opcode
    if mnemonic in LOADS:
        rs1, value = memory_operand(operands[1])
    else:
        rs1, value = register(operands[1]), number(operands[2])
    return immediate(value, 12) << 20 | rs1 << 15 | funct3 | rd << 7 | opcode


def translate_instruction(source):
    """Preserva a interface de tradução de uma instrução real."""
    try:
        mnemonic, operands = parse_instruction(source)
        return f"{encode(mnemonic, operands, {}, 0):032b}"
    except ValueError as error:
        print(f"Erro ao montar {source.rstrip()!r}: {error}")
        return None


def assemble(source, max_words):
    labels, instructions = {}, []
    for line_no, line in enumerate(source.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = re.split(r"#|//|;", line, maxsplit=1)[0].strip()
        try:
            while (match := re.match(rf"^({LABEL.pattern})\s*:\s*", line)):
                label = match[1]
                if label in labels:
                    raise ValueError(f"Rótulo duplicado: {label}")
                labels[label] = 4 * len(instructions)
                line = line[match.end():]
            if not line or line == ".text" or re.fullmatch(r"\.(?:globl|global)\s+[\w.$]+", line):
                continue
            for mnemonic, operands in expand(*parse_instruction(line)):
                instructions.append((line_no, mnemonic, operands))
            if len(instructions) > max_words:
                raise ValueError(f"O programa excede o limite de {max_words} palavras")
        except ValueError as error:
            raise ValueError(f"{source}:{line_no}: {error}") from error
    if not instructions:
        raise ValueError(f"{source}: nenhuma instrução encontrada")
    words = []
    for index, (line_no, mnemonic, operands) in enumerate(instructions):
        try:
            value = encode(mnemonic, operands, labels, 4 * index)
        except ValueError as error:
            raise ValueError(f"{source}:{line_no}: {error}") from error
        words.append(f"{value:08X}")
    return words


def build_dump_code():
	"""Returns the dump code (Parts 2-8) as a list of (assembly, comment).

	Designed to be placed at DUMP_START (word address 0x80).
	All internal branch offsets are PC-relative and position-independent:
	  POLL back  : beq x0,x0,-12
	  POLL fwd   : beq x13,x0,8
	  Loop back  : beq x0,x0,-32
	  Loop done  : beq x14,x16,8  (or beq x14,x0,8 for cycle poll-only)
	"""
	b = INFRA_BBASE  # byte base for infrastructure lw offsets (0x200)
	code = []

	# Part 2: save x1-x8 to dmem word addr 0x78-0x7F (bytes 0x1E0-0x1FC)
	for i in range(1, 9):
		code.append((f"sw x{i},{SAVES_BBASE + (i-1)*4}(x0)",
		             f"x{i} -> dmem[0x{SAVES_WBASE + i - 1:02X}]"))

	# Part 3: load infrastructure constants
	code.append((f"lw x15,{b+0}(x0)",  "x15 = 0x410  UART TX/status"))
	code.append((f"lw x17,{b+4}(x0)",  "x17 = 0x200  tx_busy mask"))
	code.append((f"lw x18,{b+8}(x0)",  "x18 = 4      step"))
	code.append((f"lw x20,{b+12}(x0)", "x20 = 0x400  MMIO base"))
	code.append((f"lw x21,{b+16}(x0)", "x21 = 0x1FF  LEDG all-on"))
	code.append((f"lw x23,{b+20}(x0)", "x23 = saves start"))
	code.append((f"lw x24,{b+24}(x0)", "x24 = saves end"))

	# Part 4: send cycle count (MMIO 0x414)
	code.append(("add x22,x15,x18",  "x22 = 0x414  CYCLE MMIO"))
	code.append(("lw x19,0(x22)",    "x19 = cycle count"))
	code.append(("lw x13,0(x15)",    "POLL: read UART status"))
	code.append(("and x13,x13,x17",  "      isolate tx_busy"))
	code.append(("beq x13,x0,8",     "      free? -> SEND"))
	code.append(("beq x0,x0,-12",    "      busy? -> POLL"))
	code.append(("sw x19,0(x15)",    "SEND  cycles (4 bytes hw)"))

	# Part 5: loop — send saved x1-x8
	code.append(("add x14,x23,x0",  "x14 = saves start ptr"))
	code.append(("add x16,x24,x0",  "x16 = saves end ptr"))
	# REG_LOOP:
	code.append(("lw x19,0(x14)",   "REG_LOOP: load saved reg"))
	code.append(("lw x13,0(x15)",   "POLL"))
	code.append(("and x13,x13,x17", "      isolate tx_busy"))
	code.append(("beq x13,x0,8",    "      free? -> SEND"))
	code.append(("beq x0,x0,-12",   "      busy? -> POLL"))
	code.append(("sw x19,0(x15)",   "SEND  reg (4 bytes hw)"))
	code.append(("add x14,x14,x18", "      ptr += 4"))
	code.append(("beq x14,x16,8",   "      done? skip loop-back"))
	code.append(("beq x0,x0,-32",   "      -> REG_LOOP"))

	# Part 6: loop — send dmem[0x000..0x07C]
	code.append(("add x14,x0,x0",   "x14 = 0     mem start ptr"))
	code.append(("add x16,x23,x0",  "x16 = 0x80  mem end ptr"))
	# MEM_LOOP:
	code.append(("lw x19,0(x14)",   "MEM_LOOP: load mem word"))
	code.append(("lw x13,0(x15)",   "POLL"))
	code.append(("and x13,x13,x17", "      isolate tx_busy"))
	code.append(("beq x13,x0,8",    "      free? -> SEND"))
	code.append(("beq x0,x0,-12",   "      busy? -> POLL"))
	code.append(("sw x19,0(x15)",   "SEND  mem word (4 bytes hw)"))
	code.append(("add x14,x14,x18", "      ptr += 4"))
	code.append(("beq x14,x16,8",   "      done? skip loop-back"))
	code.append(("beq x0,x0,-32",   "      -> MEM_LOOP"))

	# Part 7: light all green LEDs
	code.append(("sw x21,12(x20)", "LEDG[8:0] = 0x1FF  (addr 0x40C)"))

	# Part 8: halt
	code.append(("beq x0,x0,0", "halt: infinite loop"))

	return code


def write_images(directory, program, data=None, complete=True):
    directory.mkdir(parents=True, exist_ok=True)
    if complete:
        program = program + [NOP_WORD] * (DEPTH - len(program))
    images = [("instruction.mif", "program.hex", program)]
    if data is not None:
        images.append(("data.mif", "data.hex", data))
    header = "DEPTH = 256;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n"
    for mif_name, hex_name, words in images:
        body = "".join(f"{index:03X} : {word};\n" for index, word in enumerate(words))
        (directory / mif_name).write_text(header + body + "END;\n", encoding="ascii")
        (directory / hex_name).write_text("\n".join(words) + "\n", encoding="ascii")


def main():
    parser = argparse.ArgumentParser(description="Monta um programa para a CPU RV32I do projeto.")
    parser.add_argument("file", nargs="?", default="instructions.txt", type=Path,
                        help="Arquivo assembly de entrada")
    parser.add_argument("--output-dir", type=Path,
                        help="Destino dos quatro arquivos MIF/HEX completos")
    parser.add_argument("--dump", action="store_true",
                        help="Anexa a rotina de dump UART para a FPGA")
    args = parser.parse_args()

    try:
        program = assemble(args.file, DUMP_START - 1 if args.dump else DEPTH)
        source_words = len(program)
        if args.dump:
            directory = args.output_dir or Path(__file__).resolve().parent
            branch = encode("beq", ["x0", "x0", str(4 * (DUMP_START - source_words))], {}, 0)
            program.append(f"{branch:08X}")
            program.extend([NOP_WORD] * (DUMP_START - len(program)))
            for instruction, _ in build_dump_code():
                word = encode(*parse_instruction(instruction), {}, 0)
                program.append(f"{word:08X}")
            data = ["00000000"] * DEPTH
            for address, value, _ in INFRA_DATA:
                data[address] = f"{value:08X}"
            write_images(directory, program, data)
        elif args.output_dir is not None:
            directory = args.output_dir
            if source_words < DEPTH:
                program.append(HALT_WORD)
            write_images(directory, program, ["00000000"] * DEPTH)
        else:
            directory = Path.cwd()
            write_images(directory, program, complete=False)
        print(f"Montagem concluída: {source_words} palavras de código em {directory.resolve()}")
    except (OSError, ValueError) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
