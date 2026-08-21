# Resolve the couch TV user and home without assuming /home/aman.
# shellcheck shell=bash

mango_tv_user() {
  local user="${MANGO_TV_USER:-}"
  if [[ -z "$user" && "$(id -u)" -eq 0 ]]; then
    user="${SUDO_USER:-}"
  fi
  if [[ -z "$user" ]]; then
    user="${USER:-$(id -un 2>/dev/null || true)}"
  fi
  if [[ -z "$user" || "$user" == "root" ]]; then
    echo "mango-user: cannot resolve TV user (set MANGO_TV_USER)" >&2
    return 1
  fi
  if ! mango_user_exists "$user"; then
    echo "mango-user: user ${user} does not exist" >&2
    return 1
  fi
  printf '%s\n' "$user"
}

mango_user_exists() {
  local user="$1"
  if command -v getent >/dev/null 2>&1; then
    getent passwd "$user" >/dev/null 2>&1
    return
  fi
  if MANGO_LOOKUP_USER="$user" python3 -c 'import os, pwd; pwd.getpwnam(os.environ["MANGO_LOOKUP_USER"])' >/dev/null 2>&1; then
    return 0
  fi
  [[ "$user" == "$(id -un 2>/dev/null || true)" ]]
}

mango_tv_home() {
  local user="${1:-}"
  if [[ -z "$user" ]]; then
    user="$(mango_tv_user)" || return 1
  fi
  local home=""
  if command -v getent >/dev/null 2>&1; then
    home="$(getent passwd "$user" | awk -F: '{print $6}')"
  elif home="$(MANGO_LOOKUP_USER="$user" python3 -c 'import os, pwd; print(pwd.getpwnam(os.environ["MANGO_LOOKUP_USER"]).pw_dir)' 2>/dev/null)"; then
    :
  else
    home="${HOME:-}"
  fi
  if [[ -z "$home" || ! -d "$home" ]]; then
    echo "mango-user: home for ${user} is missing" >&2
    return 1
  fi
  printf '%s\n' "$home"
}

mango_export_tv_identity() {
  local user home
  user="$(mango_tv_user)" || return 1
  home="$(mango_tv_home "$user")" || return 1
  export MANGO_TV_USER="$user"
  export USER="$user"
  export HOME="$home"
  export XAUTHORITY="${XAUTHORITY:-$home/.Xauthority}"
}

mango_gamepad_mac() {
  local mac="${MANGO_GAMEPAD_BT_MAC:-}"
  if [[ -z "$mac" ]]; then
    echo "mango-user: set MANGO_GAMEPAD_BT_MAC to this device's 8BitDo MAC" >&2
    return 1
  fi
  printf '%s\n' "$mac"
}

mango_pi_ip() {
  local ip="${MANGO_PI_IP:-}"
  if [[ -n "$ip" ]]; then
    printf '%s\n' "$ip"
    return 0
  fi
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "$ip" ]]; then
    echo "mango-user: cannot resolve LAN IP (set MANGO_PI_IP)" >&2
    return 1
  fi
  printf '%s\n' "$ip"
}

mango_pi_host() {
  printf '%s\n' "${MANGO_PI_HOST:-$(hostname).local}"
}
