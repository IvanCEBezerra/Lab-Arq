#!/usr/bin/env python3
"""Checagens estaticas do projeto Quartus; NAO substitui compilacao/TimeQuest."""
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "src"
EXPECTED_PORTS = ({"CLOCK_50", "UART_RXD", "UART_TXD"}
                  | {f"KEY[{i}]" for i in range(4)}
                  | {f"SW[{i}]" for i in range(18)}
                  | {f"LEDR[{i}]" for i in range(18)}
                  | {f"LEDG[{i}]" for i in range(9)})


def check(condition, message):
    if not condition:
        raise ValueError(message)


def mif(path):
    text = path.read_text(encoding="utf-8")
    check(re.search(r"\bDEPTH\s*=\s*256\s*;", text, re.I), f"{path}: DEPTH")
    check(re.search(r"\bWIDTH\s*=\s*32\s*;", text, re.I), f"{path}: WIDTH")
    for field in ("ADDRESS_RADIX", "DATA_RADIX"):
        check(re.search(rf"\b{field}\s*=\s*HEX\s*;", text, re.I), f"{path}: {field}")
    body = re.search(r"\bCONTENT\s+BEGIN\s*(.*?)\bEND\s*;", text, re.I | re.S)
    if body is None:
        raise ValueError(f"{path}: CONTENT/END")
    words = {}
    for line in body.group(1).splitlines():
        line = line.split("--", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"(?:\[([0-9a-fA-F]+)\.\.([0-9a-fA-F]+)\]|([0-9a-fA-F]+))\s*:\s*([0-9a-fA-F]{8})\s*;", line)
        if match is None:
            raise ValueError(f"{path}: entrada invalida: {line}")
        low = int(match[1] or match[3], 16)
        high = int(match[2], 16) if match[2] else low
        check(0 <= low <= high < 256, f"{path}: endereco fora da RAM")
        for addr in range(low, high + 1):
            words[addr] = int(match[4], 16)  # sobrescritas MIF permitidas
    check(len(words) == 256, f"{path}: apenas {len(words)} / 256 palavras definidas")
    return words


def main():
    qsf = (HERE / "pl_top.qsf").read_text(encoding="utf-8")
    qpf = (HERE / "pl_top.qpf").read_text(encoding="utf-8")
    check(qpf.strip() == 'PROJECT_REVISION = "pl_top"', "QPF/revision")
    check(re.search(r'^set_global_assignment -name DEVICE EP4CE115F29C7$', qsf, re.M), "device")
    check(re.search(r'^set_global_assignment -name TOP_LEVEL_ENTITY pl_top$', qsf, re.M), "top")
    assignments = re.findall(r'^set_global_assignment -name (SYSTEMVERILOG_FILE|VERILOG_FILE|SDC_FILE|MIF_FILE) (\S+)$', qsf, re.M)
    files = [name for _, name in assignments]
    check(len(files) == len(set(files)), "arquivo duplicado no QSF")
    for name in files:
        check((HERE / name).is_file(), f"arquivo ausente: {name}")
    sources = [name for kind, name in assignments if kind in ("SYSTEMVERILOG_FILE", "VERILOG_FILE")]
    expected = {"../src/" + p.name for p in SRC.glob("*.sv") if p.name not in ("pl_top_no_pll.sv", "pl_cpu_tb.sv")}
    expected.add("../src/pll_10mhz.v")
    check(set(sources) == expected, f"fontes divergentes: faltam {expected - set(sources)}, extras {set(sources) - expected}")
    check(sources[0] == "../src/pl_pipe_pkg.sv", "package deve vir primeiro")
    check(dict(assignments).get("SDC_FILE") == "pl_top.sdc", "SDC ausente")
    check({name for kind, name in assignments if kind == "MIF_FILE"} == {"instruction.mif", "data.mif"}, "MIF_FILE")
    pins = re.findall(r'^set_location_assignment (PIN_\w+) -to (\S+)$', qsf, re.M)
    check(all("{" not in name and "}" not in name for _, name in pins), "QSF: chaves literais nos nomes de pinos")
    pin_map = {name: pin for pin, name in pins}
    check(len(pins) == len(EXPECTED_PORTS) == len(pin_map), "pinos duplicados/incompletos")
    check(set(pin_map) == EXPECTED_PORTS, f"portas: faltam {EXPECTED_PORTS - set(pin_map)}; extras {set(pin_map) - EXPECTED_PORTS}")
    check(len(set(pin_map.values())) == len(pin_map), "pino fisico repetido")
    original = (HERE / "add_to_qsf.txt").read_text(encoding="utf-8")
    reference = {name: pin for pin, name in re.findall(r'^set_location_assignment (PIN_\w+) -to (\S+)$', original, re.M)}
    check(pin_map == reference, "pinagem diferente da referencia add_to_qsf.txt")
    top = (SRC / "pl_top.sv").read_text(encoding="utf-8")
    for name in ("CLOCK_50", "KEY", "SW", "LEDR", "LEDG", "UART_TXD", "UART_RXD"):
        check(re.search(rf'\b{name}\b', top), f"porta top ausente: {name}")
    for module, attr, mif_name in (("pl_imem.sv", "rom", "instruction.mif"), ("pl_dmem.sv", "ram", "data.mif")):
        text = (SRC / module).read_text(encoding="utf-8")
        check(re.search(rf'ram_init_file\s*=\s*"{re.escape(mif_name)}"\s*\*\)\s*logic\s*\[31:0\]\s*{attr}\s*\[0:255\]', text), f"atributo RAM: {module}")
    check(re.search(r'clk0_divide_by\s*=\s*5\b', (SRC / "pll_10mhz.v").read_text()), "PLL nao divide por 5")
    sdc = (HERE / "pl_top.sdc").read_text(encoding="utf-8")
    check("derive_pll_clocks" in sdc and "derive_clock_uncertainty" in sdc, "SDC PLL")
    check(re.search(r'create_clock\s+-name CLOCK_50\s+-period 20\.000', sdc), "SDC clock 50 MHz")
    standards = re.findall(r'^set_instance_assignment -name IO_STANDARD "([^"]+)" -to (\S+)$', qsf, re.M)
    check(all("{" not in port and "}" not in port for _, port in standards), "QSF: chaves literais nos nomes de IO_STANDARD")
    check(dict((port, std) for std, port in standards) == {
        "SW[*]": "2.5 V", "KEY[*]": "2.5 V", "LEDR[*]": "2.5 V", "LEDG[*]": "2.5 V",
        "CLOCK_50": "3.3-V LVTTL", "UART_RXD": "3.3-V LVTTL", "UART_TXD": "3.3-V LVTTL"}, "IO_STANDARD")
    for name in ("instruction.mif", "data.mif"):
        words = mif(HERE / name)
        check((HERE / name).read_bytes() == (HERE.parent / "mifs" / "etapa03_fpga" / name).read_bytes(), f"MIF etapa 3 diferente: {name}")
        hex_name = "program.hex" if name == "instruction.mif" else "data.hex"
        lines = (HERE / hex_name).read_text(encoding="utf-8").splitlines()
        check(len(lines) == 256 and all(re.fullmatch(r"[0-9a-fA-F]{8}", line) for line in lines), f"{hex_name}: esperado 256 palavras hexadecimais de 32 bits")
        check([int(line, 16) for line in lines] == [words[i] for i in range(256)], f"{hex_name}: diferente de {name}")
        print(f"{name}: 256 palavras x 32 bits, copia identica da etapa 3")

    print(f"OK: {len(sources)} fontes, {len(pins)} pinos, SDC, I/O standards, MIFs e HEXs (somente verificacao estatica)")


if __name__ == "__main__":
    main()
