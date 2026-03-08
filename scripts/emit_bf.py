#!/usr/bin/env python3
"""Emit BrainFuck that prints a string.

Use this to generate BF snippets for pager commands or output.
Example: python3 scripts/emit_bf.py "H\n"  # Emits BF that prints H and newline
"""
import sys


def emit_text(text: str) -> str:
    """Return BF code that prints the given string."""
    return "".join("[-]" + "+" * ord(ch) + "." for ch in text)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 emit_bf.py <text>", file=sys.stderr)
        print("  Emits BF that prints the text. Use \\n for newline.", file=sys.stderr)
        sys.exit(1)
    text = sys.argv[1].replace("\\n", "\n")
    print(emit_text(text))


if __name__ == "__main__":
    main()
