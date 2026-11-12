#!/usr/bin/env python3
"""Pure input-ownership decisions shared by the Mango pad router tests."""

from __future__ import annotations

import math


def contextual_secondary_surface(visible_surface: str, playback_active: bool) -> str:
    """Route X to what the user can see, then fall back to playback state."""

    if visible_surface == "launcher":
        return "launcher"
    if visible_surface == "mpv" or playback_active:
        return "mpv"
    return visible_surface


def resolve_secondary_surface(
    foreground_surface: str,
    playback_active: bool,
    *,
    launcher_window_available: bool,
    mpv_window_available: bool,
) -> str:
    """Resolve X from windows once at button-down.

    X11 can briefly report the desktop or an overlay as active while Chromium
    remains the visible couch surface. A real mpv window takes precedence over
    an available launcher window; a stale playback marker does not.
    """

    if foreground_surface in {"launcher", "mpv"}:
        return foreground_surface
    if mpv_window_available:
        return "mpv"
    if launcher_window_available:
        return "launcher"
    return contextual_secondary_surface(foreground_surface, playback_active)


def kms_playback_visible(active_vt: str | None, x_vt: str, playback_active: bool) -> bool:
    """KMS playback parks X on another VT; X's "active window" is then invisible.

    mpv owns the HDMI output from its own VT and has no X window, so every
    X-side focus probe still names the (frozen) launcher. While playback is
    active and the console is not on X's VT, the visible surface is mpv.
    """

    if not playback_active or not active_vt:
        return False
    return active_vt.strip() != x_vt.strip()


def detached_scope_argv(argv: list[str], systemd_run_available: bool) -> list[str]:
    """Run a stop/restore outside the pad's cgroup so a pad restart cannot kill it.

    mango-tv-pad.service uses KillMode=control-group; a watchdog repair of the
    pad mid-restore SIGTERMed the launcher reveal and left the TV black.
    """

    if not systemd_run_available:
        return list(argv)
    return ["systemd-run", "--user", "--scope", "--quiet", "--collect", "--", *argv]


def secondary_press_kind(started_at: float, released_at: float, hold_sec: float) -> str:
    elapsed = released_at - started_at
    reached_hold = elapsed >= hold_sec or math.isclose(
        elapsed,
        hold_sec,
        rel_tol=0.0,
        abs_tol=1e-9,
    )
    return "hold" if reached_hold else "tap"


def seek_hud_reason(direction: str, seconds: int) -> str:
    """Encode the exact signed seek delta without changing seek ownership."""

    if direction not in {"left", "right"} or seconds <= 0:
        raise ValueError("seek requires left/right and a positive step")
    signed_seconds = -seconds if direction == "left" else seconds
    return f"seek:{signed_seconds:+d}"
