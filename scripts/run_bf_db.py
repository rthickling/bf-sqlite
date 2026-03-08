#!/usr/bin/env python3
"""Run a BF executable against the pager and forward user-visible output."""

from __future__ import annotations

import os
import re
import subprocess
import sys
import threading


READ_RE = re.compile(r"R \d+ \d+\Z")
WRITE_RE = re.compile(r"W (\d+) (\d+)\Z")


def forward_program_output(program: subprocess.Popen[str], pager: subprocess.Popen[str]) -> None:
    write_hex_remaining = 0

    assert program.stdout is not None
    assert pager.stdin is not None

    try:
        for raw_line in program.stdout:
            line = raw_line.rstrip("\n")

            if write_hex_remaining > 0:
                pager.stdin.write(line + "\n")
                pager.stdin.flush()
                write_hex_remaining -= len(line)
                continue

            if line == "H" or READ_RE.fullmatch(line):
                pager.stdin.write(line + "\n")
                pager.stdin.flush()
                continue

            match = WRITE_RE.fullmatch(line)
            if match:
                pager.stdin.write(line + "\n")
                pager.stdin.flush()
                write_hex_remaining = int(match.group(1)) * 2
                continue

            sys.stdout.write(raw_line)
            sys.stdout.flush()
    finally:
        try:
            pager.stdin.close()
        except Exception:
            pass


def forward_pager_output(program: subprocess.Popen[str], pager: subprocess.Popen[str]) -> None:
    assert program.stdin is not None
    assert pager.stdout is not None

    try:
        for raw_line in pager.stdout:
            try:
                program.stdin.write(raw_line)
                program.stdin.flush()
            except BrokenPipeError:
                break
    finally:
        try:
            program.stdin.close()
        except Exception:
            pass


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: run_bf_db.py <pager.sh> <program> <database.db>", file=sys.stderr)
        return 1

    pager_script, program_path, db_path = sys.argv[1:4]

    pager_env = os.environ.copy()
    pager_env["REQ"] = "-"
    pager_env["RES"] = "-"

    pager = subprocess.Popen(
        [pager_script, db_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,
        text=True,
        bufsize=1,
        env=pager_env,
    )

    program = subprocess.Popen(
        [program_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,
        text=True,
        bufsize=1,
    )

    t_out = threading.Thread(target=forward_program_output, args=(program, pager), daemon=True)
    t_in = threading.Thread(target=forward_pager_output, args=(program, pager), daemon=True)
    t_out.start()
    t_in.start()

    program_rc = program.wait()
    t_out.join(timeout=1)

    try:
        pager.wait(timeout=5)
    except subprocess.TimeoutExpired:
        if pager.poll() is None:
            try:
                pager.terminate()
                pager.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pager.kill()
                pager.wait(timeout=2)

    t_in.join(timeout=1)
    return program_rc


if __name__ == "__main__":
    raise SystemExit(main())
