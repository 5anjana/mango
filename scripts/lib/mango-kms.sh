#!/usr/bin/env bash
# KMS presentation: during VOD playback mpv drives the HDMI output itself
# through DRM on its own virtual terminal while the X session (launcher) stays
# parked on its VT. X on this Pi (Xorg 21.1 modesetting + glamor, no TearFree)
# either stalls vsynced page flips to ~1/3 rate or, with the one-row-short copy
# window, tears mid-scan. DRM atomic flips do neither: measured 0 drops,
# vsync-ratio 1.00, jitter 0.009 at 4K23.98 (2026-11-10).
#
# Sourced by mpv-play.sh and restore-launcher-after-playback.sh. Everything is
# env-overridable so a test host without /dev/dri can exercise the path:
#   MANGO_MPV_PRESENT      kms (default) | x11   — x11 keeps the copy window
#   MANGO_MPV_DRM_DEVICE   /dev/dri/cardN        — default: the vc4 card
#   MANGO_MPV_KMS_VT       VT mpv plays on       — default 1
#   MANGO_MPV_X_VT         VT X lives on         — default: from the Xorg args
#   MANGO_MPV_CHVT         command used to switch — default "sudo -n chvt"

kms_drm_device() {
  if [[ -n "${MANGO_MPV_DRM_DEVICE:-}" ]]; then
    printf '%s\n' "$MANGO_MPV_DRM_DEVICE"
    return 0
  fi
  local card
  for card in /dev/dri/card*; do
    [[ -c "$card" ]] || continue
    if grep -qs '^DRIVER=vc4' "/sys/class/drm/$(basename "$card")/device/uevent"; then
      printf '%s\n' "$card"
      return 0
    fi
  done
  return 1
}

kms_playback_vt() {
  printf '%s\n' "${MANGO_MPV_KMS_VT:-1}"
}

kms_x_vt() {
  if [[ -n "${MANGO_MPV_X_VT:-}" ]]; then
    printf '%s\n' "$MANGO_MPV_X_VT"
    return 0
  fi
  local vt
  vt="$(ps -o args= -C Xorg 2>/dev/null | grep -oE '(^| )vt[0-9]+' | head -n 1 | tr -dc '0-9')"
  printf '%s\n' "${vt:-7}"
}

kms_active_vt() {
  tr -dc '0-9' </sys/class/tty/tty0/active 2>/dev/null
}

kms_chvt() {
  local target="$1"
  # shellcheck disable=SC2086
  ${MANGO_MPV_CHVT:-sudo -n chvt} "$target" >/dev/null 2>&1
}

kms_wait_vt() {
  local target="$1" attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    [[ "$(kms_active_vt)" == "$target" ]] && return 0
    sleep 0.1
  done
  [[ -z "${MANGO_MPV_CHVT:-}" ]] || return 0
  return 1
}

kms_available() {
  [[ "${MANGO_MPV_PRESENT:-kms}" == "kms" ]] || return 1
  local dev chvt_cmd
  dev="$(kms_drm_device)" || return 1
  [[ -c "$dev" && -r "$dev" && -w "$dev" ]] || return 1
  chvt_cmd="${MANGO_MPV_CHVT:-sudo -n chvt}"
  command -v "${chvt_cmd%% *}" >/dev/null 2>&1 || return 1
  if [[ -z "${MANGO_MPV_CHVT:-}" ]]; then
    command -v chvt >/dev/null 2>&1 || return 1
    sudo -n true >/dev/null 2>&1 || return 1
  fi
  return 0
}

# Switch away from X so it drops DRM master; mpv then opens the device as
# master. The console on the playback VT is cleared first so no login text
# shows between the switch and mpv's first frame.
kms_take_display() {
  local target
  target="$(kms_playback_vt)"
  if [[ "$(kms_active_vt)" != "$target" ]]; then
    kms_chvt "$target" || return 1
    kms_wait_vt "$target" || return 1
  fi
  printf '\033[?25l\033[2J\033[H' >"/dev/tty${target}" 2>/dev/null || true
  return 0
}

# Idempotent: safe to call from every stop/restore path.
kms_return_display() {
  local target
  target="$(kms_x_vt)"
  [[ -r /sys/class/tty/tty0/active ]] || return 0
  [[ "$(kms_active_vt)" == "$target" ]] && return 0
  kms_chvt "$target" || return 1
  kms_wait_vt "$target"
}

kms_mode_preference() {
  local width="$1" height="$2"
  local mode_4k="${MANGO_MPV_MATCH_4K_MODE:-3840x2160}"
  local mode_hd="${MANGO_MPV_MATCH_HD_MODE:-1920x1080}"
  if [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] \
    && { [[ "$width" -ge 3000 ]] || [[ "$height" -ge 1600 ]]; }; then
    printf '%s\n%s\n' "$mode_4k" "$mode_hd"
  else
    printf '%s\n%s\n' "$mode_hd" "$mode_4k"
  fi
}

# "WxH@R" for mpv --drm-mode, picked like the X path: 4K panel mode for 4K
# sources, 1080p otherwise, refresh from choose-display-rate.py (film keeps
# 24 Hz, 25/30 fps go to 50/60).
kms_drm_mode_for() {
  local width="$1" height="$2" fps="$3"
  local dev modes mode rates rate
  [[ -n "$fps" && "$fps" != "0" ]] || return 1
  dev="$(kms_drm_device)" || return 1
  modes="$(mpv --no-config --drm-device="$dev" --drm-mode=help 2>/dev/null \
    | grep -oE '[0-9]+x[0-9]+@[0-9.]+Hz' | sed 's/Hz$//' | sort -u)"
  [[ -n "$modes" ]] || return 1
  while IFS= read -r mode; do
    [[ -n "$mode" ]] || continue
    rates="$(printf '%s\n' "$modes" | awk -F@ -v m="$mode" '$1 == m { print $2 }' | tr '\n' ' ')"
    [[ -n "${rates// /}" ]] || continue
    # shellcheck disable=SC2086
    rate="$(python3 "${MANGO_REPO_DIR:-$HOME/mango}/scripts/lib/choose-display-rate.py" "$fps" $rates 2>/dev/null || true)"
    [[ -n "$rate" ]] || continue
    printf '%s@%s\n' "$mode" "$rate"
    return 0
  done < <(kms_mode_preference "$width" "$height")
  return 1
}
