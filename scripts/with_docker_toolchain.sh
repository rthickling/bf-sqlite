#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE="${BF_SQLITE_IMAGE:-bf-sqlite}"

docker_args=(run --rm -v "$PROJECT_DIR:/work" -w /work)

if [ -t 0 ]; then
  docker_args+=(-i)
fi
if [ -t 1 ]; then
  docker_args+=(-t)
fi

exec docker "${docker_args[@]}" "$IMAGE" "$@"
