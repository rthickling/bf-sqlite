#!/usr/bin/env bash
# pager.sh - Shell pager for BrainFuck SQLite engine
# Reads raw bytes from .db via dd, returns hex-encoded via od/tr
# Protocol: H = header, R <page_size> <page_no> = read page, W <page_size> <page_no> = write page
set -euo pipefail

DB="${1:?Usage: $0 <path/to/database.db>}"
REQ="${REQ:-pager.req}"
RES="${RES:-pager.res}"
USE_STDOUT=

# When REQ is - or /dev/stdin, read from stdin (avoids fifo timing issues)
USE_STDIN=
if [ "$REQ" = "-" ] || [ "$REQ" = "/dev/stdin" ]; then
  USE_STDIN=1
  exec 4<&0
fi

if [ "$RES" = "-" ] || [ "$RES" = "/dev/stdout" ]; then
  USE_STDOUT=1
elif [ ! -n "$USE_STDIN" ]; then
  if [ ! -p "$REQ" ]; then
    rm -f "$REQ"
    mkfifo "$REQ"
  fi
  if [ ! -p "$RES" ]; then
    rm -f "$RES"
    mkfifo "$RES"
  fi
elif [ ! -p "$RES" ]; then
  rm -f "$RES"
  mkfifo "$RES"
fi

cleanup() {
  if [ -z "$USE_STDOUT" ]; then
    rm -f "$RES"
  fi
  if [ -z "$USE_STDIN" ]; then
    rm -f "$REQ"
  fi
}
trap cleanup EXIT

read_line() {
  if [ -n "$USE_STDIN" ]; then
    IFS= read -r line <&4 || return $?
  else
    IFS= read -r line < "$REQ" || return $?
  fi
}
read_chunk() {
  if [ -n "$USE_STDIN" ]; then
    IFS= read -r chunk <&4 || return $?
  else
    IFS= read -r chunk < "$REQ" || return $?
  fi
}
emit_response() { if [ -n "$USE_STDOUT" ]; then cat; else cat > "$RES"; fi; }

while true; do
  if ! read_line; then
    break
  fi
  [ -n "${line:-}" ] || break
  set -- $line
  cmd="${1:-}"

  case "$cmd" in
    H)
      { dd if="$DB" bs=100 count=1 status=none | od -An -tx1 -v | tr -d ' \n'; printf '\n'; } | emit_response
      ;;

    R)
      page_size="${2:?Missing page_size}"
      page_no="${3:?Missing page_no}"
      skip=$((page_no - 1))
      { dd if="$DB" bs="$page_size" skip="$skip" count=1 status=none | od -An -tx1 -v | tr -d ' \n'; printf '\n'; } | emit_response
      ;;

    W)
      page_size="${2:?Missing page_size}"
      page_no="${3:?Missing page_no}"
      # Read hex in chunks (LINE_MAX often 2048; page hex = page_size*2 chars)
      hexlen=$((page_size * 2))
      hex=""
      while [ ${#hex} -lt "$hexlen" ]; do
        read_chunk || break
        hex="${hex}${chunk}"
      done
      printf '%s' "$hex" | xxd -r -p | dd of="$DB" bs="$page_size" seek=$((page_no - 1)) conv=notrunc status=none
      printf 'OK\n' | emit_response
      ;;

    *)
      printf 'ERR unknown command\n' | emit_response
      ;;
  esac
done

exit 0
