"""Codificações RV32I de shift immediate no limite do shamt."""
import importlib.util
from pathlib import Path
import unittest

ASSEMBLER = Path(__file__).resolve().parent.parent / 'assembler' / 'assembler.py'
spec = importlib.util.spec_from_file_location('local_assembler', ASSEMBLER)
assert spec is not None and spec.loader is not None
assembler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assembler)


class ShiftEncodingTest(unittest.TestCase):
    def test_maximum_shift_encodes_exactly_five_bits(self):
        for instruction, machine_word in (
            ('srai x1,x1,31', 0x41f0d093),
            ('srli x1,x1,31', 0x01f0d093),
            ('slli x1,x1,31', 0x01f09093),
            ('srai x1,x1,0', 0x4000d093),
        ):
            with self.subTest(instruction=instruction):
                bits = assembler.translate_instruction(instruction)
                self.assertEqual(len(bits), 32)
                self.assertEqual(int(bits, 2), machine_word)

    def test_shift_out_of_range_rejected(self):
        for amount in (-1, 32, 63):
            with self.subTest(amount=amount):
                self.assertIsNone(assembler.translate_instruction(
                    f'srai x1,x1,{amount}'))


if __name__ == '__main__':
    unittest.main()
