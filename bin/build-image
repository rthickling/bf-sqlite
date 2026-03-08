#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE="${BF_SQLITE_IMAGE:-bf-sqlite}"

exec docker build -f "$PROJECT_DIR/tools/Dockerfile" -t "$IMAGE" "$PROJECT_DIR"
