#!/usr/bin/env bash
# Run mango-tv-pad as root for evdev grab — recover the couch user after sudo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../lib/mango-user.sh
source "$REPO_DIR/scripts/lib/mango-user.sh"

mango_export_tv_identity
export DISPLAY="${DISPLAY:-:0}"

if [[ -f "${HOME}/.cache/mango/diag/session.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${HOME}/.cache/mango/diag/session.env"
  set +a
fi

exec /usr/bin/python3 "${HOME}/mango/scripts/m1-foundation/pad/mango-tv-pad.py"
