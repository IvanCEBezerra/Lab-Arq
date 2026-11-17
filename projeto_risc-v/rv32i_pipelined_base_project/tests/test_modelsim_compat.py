"""Avoid implicit-net redeclarations in the ModelSim 2020.1 MMIO build."""
from pathlib import Path
import unittest


class ModelSimCompatibilityTest(unittest.TestCase):
    def test_uart_tx_byte_is_declared_before_port_connection(self):
        source = (Path(__file__).resolve().parents[1] / 'src/pl_mmio.sv').read_text()
        self.assertLess(source.index('logic [7:0] tx_byte;'),
                        source.index('.tx_data  (tx_byte)'),
                        'ModelSim 2020.1 treats the forward port reference as an implicit net')


if __name__ == '__main__':
    unittest.main()
