#!/usr/bin/env bash
# Generate mkcert TLS for companion HTTPS (Pi or Mac).
#
# Prereq: brew install mkcert  (Mac)  |  apt install mkcert  (Pi)
# Phone: install root CA once — see docs/VOICE.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../lib/mango-user.sh
source "$REPO_DIR/scripts/lib/mango-user.sh"
CERT_DIR="${MANGO_CERT_DIR:-$HOME/.config/mango/certs}"
PI_IP="$(mango_pi_ip)" || exit 1
PI_HOST="$(mango_pi_host)"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

if ! command -v mkcert &>/dev/null; then
  echo "! mkcert not found — install mkcert first"
  exit 1
fi

mkcert -install 2>/dev/null || true
mkcert -cert-file mango-companion.pem -key-file mango-companion-key.pem \
  localhost 127.0.0.1 "$PI_IP" "$PI_HOST" 2>/dev/null || \
  mkcert -cert-file mango-companion.pem -key-file mango-companion-key.pem localhost 127.0.0.1

CAROOT="$(mkcert -CAROOT 2>/dev/null || true)"
echo "✓ certs in $CERT_DIR"
echo "  cert: $CERT_DIR/mango-companion.pem"
echo "  key:  $CERT_DIR/mango-companion-key.pem"
echo "  names: localhost 127.0.0.1 ${PI_IP} ${PI_HOST}"
if [[ -n "$CAROOT" ]]; then
  echo "  root CA: $CAROOT/rootCA.pem"
fi
echo "  orchestrator TLS: MANGO_ORCH_TLS=1 bash scripts/m5-voice/stack/start-orchestrator.sh"
echo "  companion HTTPS:  bash scripts/m5-voice/stack/serve-companion-https.sh"
