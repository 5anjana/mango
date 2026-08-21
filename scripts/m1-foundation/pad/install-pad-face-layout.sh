#!/usr/bin/env bash
# Persist a face-button layout for mango-tv-pad. sudo-stripped systemd env
# cannot carry this, so the router sources /etc/mango/pad.env as root.
#
# Usage:
#   sudo MANGO_PAD_FACE_LAYOUT=abxy-swap bash scripts/m1-foundation/pad/install-pad-face-layout.sh
#   sudo MANGO_PAD_FACE_LAYOUT=nintendo bash scripts/m1-foundation/pad/install-pad-face-layout.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../lib/mango-user.sh
source "$REPO_DIR/scripts/lib/mango-user.sh"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run: sudo $0" >&2
  exit 1
fi

layout="${MANGO_PAD_FACE_LAYOUT:-}"
layout="${layout,,}"
case "$layout" in
  nintendo) ;;
  abxy-swap|swap-abxy|zero2) layout="abxy-swap" ;;
  *)
    echo "Set MANGO_PAD_FACE_LAYOUT to nintendo or abxy-swap" >&2
    exit 1
    ;;
esac

install -d -m 0755 /etc/mango
cat >/etc/mango/pad.env <<EOF
# mango pad face layout — installed $(date -u +%Y-%m-%dT%H:%MZ)
# nintendo = 8BitDo Micro; abxy-swap = 8BitDo Zero 2 Switch HID
MANGO_PAD_FACE_LAYOUT=${layout}
EOF
chmod 0644 /etc/mango/pad.env

TV_USER="$(mango_tv_user)"
if [[ -n "$TV_USER" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --machine="${TV_USER}@" --user restart mango-tv-pad.service 2>/dev/null \
    || true
fi

echo "✓ wrote /etc/mango/pad.env (MANGO_PAD_FACE_LAYOUT=${layout})"
echo "  Restart mango-tv-pad if the user unit did not pick it up."
