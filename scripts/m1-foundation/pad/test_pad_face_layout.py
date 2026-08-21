#!/usr/bin/env python3
"""Face-button layouts stay Micro-safe unless an operator overlay swaps ABXY."""

from __future__ import annotations

import unittest

from test_pad_nav_fallback import _load_pad_with_fake_evdev


class PadFaceLayoutTests(unittest.TestCase):
    def test_nintendo_is_default(self) -> None:
        pad = _load_pad_with_fake_evdev()
        self.assertEqual(
            pad.face_button_codes(environ={}),
            {"select": 304, "audio": 305, "secondary": 307, "back": 308},
        )
        self.assertEqual(pad.BTN_B, 304)
        self.assertEqual(pad.BTN_Y, 308)
        self.assertEqual(pad.BTN_X, 307)

    def test_abxy_swap_matches_zero2_switch_hid(self) -> None:
        pad = _load_pad_with_fake_evdev()
        codes = pad.face_button_codes(layout="abxy-swap", environ={})
        self.assertEqual(
            codes,
            {"select": 305, "audio": 304, "secondary": 308, "back": 307},
        )
        aliases = pad.face_button_codes(environ={"MANGO_PAD_FACE_LAYOUT": "zero2"})
        self.assertEqual(aliases, codes)

    def test_explicit_codes_override_layout(self) -> None:
        pad = _load_pad_with_fake_evdev()
        codes = pad.face_button_codes(
            layout="nintendo",
            environ={"MANGO_PAD_BTN_SELECT": "305", "MANGO_PAD_BTN_BACK": "307"},
        )
        self.assertEqual(codes["select"], 305)
        self.assertEqual(codes["back"], 307)
        self.assertEqual(codes["secondary"], 307)


if __name__ == "__main__":
    unittest.main()
