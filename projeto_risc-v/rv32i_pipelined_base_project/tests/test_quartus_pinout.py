"""Quartus must recognize the pin assignments as real bus nodes."""
from pathlib import Path
import re
import unittest

QSF = Path(__file__).resolve().parents[1] / "quartus" / "pl_top.qsf"


class QuartusPinoutTest(unittest.TestCase):
    def test_bus_nodes_are_not_wrapped_in_literal_braces(self):
        qsf = QSF.read_text(encoding="utf-8")
        self.assertNotRegex(qsf, r"-to\s+\{(?:SW|KEY|LEDG|LEDR)\[")
        self.assertEqual(len(re.findall(r'^set_location_assignment\s+PIN_\w+\s+-to\s+\S+$', qsf, re.M)), 52)


if __name__ == '__main__':
    unittest.main()
