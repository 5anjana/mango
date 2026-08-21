#!/usr/bin/env bash
# Regression coverage for alternate-user (mango2) first-boot portability.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=mango-user.sh
source "$ROOT/scripts/lib/mango-user.sh"
# shellcheck source=catalog-yaml.sh
source "$ROOT/scripts/lib/catalog-yaml.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

current_user="$(id -un)"
current_home="$(python3 -c 'import os, pwd; print(pwd.getpwnam(os.environ["USER"]).pw_dir)')"
[[ "$(mango_tv_user)" == "$current_user" ]] || fail "mango_tv_user should be $current_user"
[[ "$(mango_tv_home)" == "$current_home" ]] || fail "mango_tv_home should be $current_home"
if mango_gamepad_mac >/dev/null 2>&1; then
  fail "missing MANGO_GAMEPAD_BT_MAC should fail closed"
fi
pass "user/home resolution and missing MAC fail-closed"

if grep -E '/home/aman|User=aman|E4:17:D8:EB:00:44' \
  "$ROOT/scripts/m1-foundation/ui/systemd/mango-tv-pad.service" \
  "$ROOT/scripts/m1-foundation/ui/systemd/mango-controller-link.service"; then
  fail "committed units still contain donor user or MAC"
fi
grep -q 'Environment=HOME=%h' "$ROOT/scripts/m1-foundation/ui/systemd/mango-tv-pad.service" \
  || fail "pad unit must use systemd %h"
grep -q '10-tv-user.conf' "$ROOT/scripts/m1-foundation/ui/systemd/mango-controller-link.service" \
  || fail "controller unit must require the recipient drop-in"
pass "committed units are user/MAC portable"

if grep -F '/home/aman' \
  "$ROOT/deploy/aiostreams/compose.yaml" \
  "$ROOT/deploy/aiometadata/compose.yaml" \
  "$ROOT/deploy/nexotv/compose.yaml" \
  "$ROOT/deploy/nexotv-free/compose.yaml" \
  "$ROOT/deploy/nexotv-news/compose.yaml" \
  "$ROOT/deploy/nexotv-cartoons/compose.yaml"; then
  fail "compose files still default to /home/aman"
fi
pass "compose volume defaults use HOME"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/etc"
cat >"$tmp/etc/catalog-filters.json" <<'EOF'
{"operator": true}
EOF
# Simulate /etc by copying into a fake tree is hard; test preference via env and
# by asserting the resolver function no longer contains the old "using example" branch.
if grep -q 'using config/catalog-filters.example.json' "$ROOT/scripts/lib/catalog-yaml.sh"; then
  fail "catalog-yaml still prefers the repo example over /etc"
fi
grep -q 'using operator /etc/mango/catalog-filters.json' "$ROOT/scripts/lib/catalog-yaml.sh" \
  || fail "catalog-yaml does not prefer operator filters"
export MANGO_CATALOG_FILTERS="$tmp/etc/catalog-filters.json"
REPO_DIR="$ROOT"
resolved="$(resolve_catalog_filters)"
[[ "$resolved" == "$tmp/etc/catalog-filters.json" ]] || fail "explicit MANGO_CATALOG_FILTERS lost"
pass "catalog filter resolution prefers operator state"

unit_dir="$tmp/systemd"
mkdir -p "$unit_dir"
MANGO_TEST_UNIT_DIR="$unit_dir" MANGO_YOUTUBE=0 MANGO_NIGHTLY_YOUTUBE_REFRESH=0 \
  bash "$ROOT/scripts/m3-play/playability/install-playability-timer.sh" >/dev/null
grep -q 'Environment=MANGO_NIGHTLY_YOUTUBE_REFRESH=0' "$unit_dir/mango-playability-indexer.service" \
  || fail "nightly timer did not preserve YouTube-off"
pass "nightly installer preserves YouTube-off"

if grep -E '10\.0\.0\.174|mango\.local' "$ROOT/scripts/m5-voice/stack/setup-mkcert.sh"; then
  fail "mkcert helper still hardcodes donor IP/hostname"
fi
pass "mkcert uses the current host"

echo "PASS: mango portability"
