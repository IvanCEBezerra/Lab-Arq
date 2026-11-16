"""Keep stage 3 instruction decode and store wiring free of unused duplicates."""
from pathlib import Path
import re
import unittest

SRC = Path(__file__).resolve().parents[1] / 'src'


class Stage3WiringTest(unittest.TestCase):
    def test_jal_immediate_has_one_case_arm(self):
        source = (SRC / 'pl_sign_ext.sv').read_text()
        self.assertEqual(len(re.findall(r'^\s*JAL\s*:', source, re.MULTILINE)), 1)

    def test_store_has_only_the_connected_mask_and_data_path(self):
        source = (SRC / 'pl_datapath.sv').read_text()
        self.assertEqual(len(re.findall(r'case\s*\(ex_mem\.funct3\)', source)), 2)
        self.assertIn('.ByteEnable(ram_byte_enable)', source)
        self.assertIn('.WriteData (ram_write_data)', source)


if __name__ == '__main__':
    unittest.main()
