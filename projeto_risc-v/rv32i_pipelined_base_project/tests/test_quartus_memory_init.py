"""Guard the simulation/synthesis memory images against silent Quartus ROMs."""
import importlib.util
from pathlib import Path
import re
import unittest

BASE = Path(__file__).resolve().parents[1]
QUARTUS = BASE / 'quartus'
SRC = BASE / 'src'

spec = importlib.util.spec_from_file_location('check_project', QUARTUS / 'check_project.py')
assert spec is not None and spec.loader is not None
check_project = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_project)


def synthesized_text(source):
    return re.sub(r'//\s*synthesis translate_off.*?//\s*synthesis translate_on',
                  '', source, flags=re.S)


class QuartusMemoryInitTest(unittest.TestCase):
    def test_instruction_rom_has_synthesis_visible_initialization(self):
        source = synthesized_text((SRC / 'pl_imem.sv').read_text())
        self.assertRegex(source, r'initial\b[\s\S]*?\$readmemh\("program\.hex",\s*rom\)')

    def test_instruction_image_matches_quartus_mif(self):
        words = check_project.mif(QUARTUS / 'instruction.mif')
        hex_words = (QUARTUS / 'program.hex').read_text().splitlines()
        self.assertEqual([int(word, 16) for word in hex_words],
                         [words[i] for i in range(256)])

    def test_data_ram_has_synthesis_visible_initialization(self):
        source = synthesized_text((SRC / 'pl_dmem.sv').read_text())
        self.assertRegex(source, r'initial\b[\s\S]*?\$readmemh\("data\.hex",\s*ram\)')

    def test_data_image_matches_quartus_mif(self):
        words = check_project.mif(QUARTUS / 'data.mif')
        hex_words = (QUARTUS / 'data.hex').read_text().splitlines()
        self.assertEqual([int(word, 16) for word in hex_words],
                         [words[i] for i in range(256)])


if __name__ == '__main__':
    unittest.main()
