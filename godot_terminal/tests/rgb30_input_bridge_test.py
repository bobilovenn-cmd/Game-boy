#!/usr/bin/env python3
"""验证 RGB30 摇杆原始值的符号和归一化边界。"""

import importlib.util
import pathlib
import struct
import unittest


MODULE_PATH = (
    pathlib.Path(__file__).resolve().parents[1] / "deploy" / "rgb30_input_bridge.py"
)
SPEC = importlib.util.spec_from_file_location("rgb30_input_bridge", MODULE_PATH)
BRIDGE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(BRIDGE)


class Rgb30InputBridgeTest(unittest.TestCase):
    def test_input_event_value_keeps_negative_sign(self) -> None:
        payload = BRIDGE.EVENT.pack(0, 0, BRIDGE.EV_ABS, 0, -1800)
        *_, value = BRIDGE.EVENT.unpack(payload)
        self.assertEqual(value, -1800)

    def test_axis_normalization_preserves_both_directions(self) -> None:
        self.assertEqual(BRIDGE.normalize_axis_value(-1800), -1.0)
        self.assertEqual(BRIDGE.normalize_axis_value(1800), 1.0)
        self.assertEqual(BRIDGE.normalize_axis_value(-900), -0.5)
        self.assertEqual(BRIDGE.normalize_axis_value(900), 0.5)

    def test_axis_normalization_clamps_out_of_range_values(self) -> None:
        self.assertEqual(BRIDGE.normalize_axis_value(-5000), -1.0)
        self.assertEqual(BRIDGE.normalize_axis_value(5000), 1.0)


if __name__ == "__main__":
    unittest.main()
