#!/usr/bin/env python3

from __future__ import annotations

import ast
from pathlib import Path
import unittest

from pad_context import (
    contextual_secondary_surface,
    detached_scope_argv,
    kms_playback_visible,
    resolve_secondary_surface,
    seek_hud_reason,
    secondary_press_kind,
)


class PadContextTest(unittest.TestCase):
    def test_diag_event_accepts_contextual_kind_field(self) -> None:
        source = Path(__file__).with_name("mango-tv-pad.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        definition = next(
            node
            for node in tree.body
            if isinstance(node, ast.FunctionDef) and node.name == "diag_event"
        )
        self.assertEqual(definition.args.args[0].arg, "event_name")

    def test_visible_launcher_owns_x_over_lingering_playback(self) -> None:
        self.assertEqual(contextual_secondary_surface("launcher", True), "launcher")

    def test_visible_or_deferred_playback_owns_x(self) -> None:
        self.assertEqual(contextual_secondary_surface("mpv", True), "mpv")
        self.assertEqual(contextual_secondary_surface("other", True), "mpv")

    def test_unowned_x_stays_unowned(self) -> None:
        self.assertEqual(contextual_secondary_surface("other", False), "other")

    def test_launcher_window_owns_x_when_x11_focus_is_ambiguous(self) -> None:
        self.assertEqual(
            resolve_secondary_surface(
                "other",
                False,
                launcher_window_available=True,
                mpv_window_available=False,
            ),
            "launcher",
        )

    def test_launcher_window_beats_a_stale_playback_marker(self) -> None:
        self.assertEqual(
            resolve_secondary_surface(
                "other",
                True,
                launcher_window_available=True,
                mpv_window_available=False,
            ),
            "launcher",
        )

    def test_real_mpv_window_beats_background_launcher(self) -> None:
        self.assertEqual(
            resolve_secondary_surface(
                "other",
                True,
                launcher_window_available=True,
                mpv_window_available=True,
            ),
            "mpv",
        )

    def test_foreground_launcher_beats_lingering_mpv_window(self) -> None:
        self.assertEqual(
            resolve_secondary_surface(
                "launcher",
                True,
                launcher_window_available=True,
                mpv_window_available=True,
            ),
            "launcher",
        )

    def test_kms_playback_hides_x_while_console_is_away_from_x(self) -> None:
        # mpv presents from tty1; X (tty7) still names the frozen launcher as active.
        self.assertTrue(kms_playback_visible("tty1", "tty7", True))
        self.assertFalse(kms_playback_visible("tty7", "tty7", True))
        # No playback: a console switch alone never claims input for mpv.
        self.assertFalse(kms_playback_visible("tty1", "tty7", False))
        self.assertFalse(kms_playback_visible(None, "tty7", True))
        self.assertFalse(kms_playback_visible("", "tty7", True))

    def test_stop_runs_in_a_detached_scope_when_systemd_run_exists(self) -> None:
        argv = ["bash", "/x/mpv-stop.sh"]
        self.assertEqual(
            detached_scope_argv(argv, True),
            ["systemd-run", "--user", "--scope", "--quiet", "--collect", "--", *argv],
        )
        self.assertEqual(detached_scope_argv(argv, False), argv)

    def test_tap_and_hold_boundary(self) -> None:
        self.assertEqual(secondary_press_kind(10.0, 10.59, 0.6), "tap")
        self.assertEqual(secondary_press_kind(10.0, 10.6, 0.6), "hold")

    def test_seek_feedback_carries_exact_signed_delta(self) -> None:
        self.assertEqual(seek_hud_reason("left", 10), "seek:-10")
        self.assertEqual(seek_hud_reason("right", 30), "seek:+30")
        self.assertEqual(seek_hud_reason("left", 120), "seek:-120")
        with self.assertRaises(ValueError):
            seek_hud_reason("up", 10)


if __name__ == "__main__":
    unittest.main()
