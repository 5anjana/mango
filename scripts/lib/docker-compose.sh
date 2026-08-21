#!/usr/bin/env bash
# Resolve docker compose command on Pi OS (plugin vs docker-compose v1).

set -euo pipefail

docker_compose() {
  export MANGO_AIOSTREAMS_DATA_DIR="${MANGO_AIOSTREAMS_DATA_DIR:-$HOME/.local/share/mango/aiostreams/data}"
  export MANGO_AIOMETADATA_DATA_DIR="${MANGO_AIOMETADATA_DATA_DIR:-$HOME/.local/share/mango/aiometadata/data}"
  export MANGO_AIOMETADATA_REDIS_DIR="${MANGO_AIOMETADATA_REDIS_DIR:-$HOME/.local/share/mango/aiometadata/redis}"
  export MANGO_NEXOTV_DATA_DIR="${MANGO_NEXOTV_DATA_DIR:-$HOME/.local/share/mango/nexotv/data}"
  export MANGO_NEXOTV_FREE_DATA_DIR="${MANGO_NEXOTV_FREE_DATA_DIR:-$HOME/.local/share/mango/nexotv-free/data}"
  export MANGO_NEXOTV_NEWS_DATA_DIR="${MANGO_NEXOTV_NEWS_DATA_DIR:-$HOME/.local/share/mango/nexotv-news/data}"
  export MANGO_NEXOTV_CARTOONS_DATA_DIR="${MANGO_NEXOTV_CARTOONS_DATA_DIR:-$HOME/.local/share/mango/nexotv-cartoons/data}"
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi
  echo "docker compose not found — run: bash scripts/m4-addons/bootstrap-docker.sh" >&2
  exit 1
}
