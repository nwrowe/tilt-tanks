#!/usr/bin/env python3
"""Reject identical duplicate method implementations in active scene ancestry.

Sibling or helper methods are outside this scope. Overrides with distinct logic
(including intentional super handoffs) remain valid. Uses the actual Main.tscn
inheritance chain rather than historical architecture diagrams.
"""
import pathlib
import re

from check_inheritance_depth import active_script, inheritance_chain


def methods(path: pathlib.Path) -> dict[str, str]:
    source = path.read_text(encoding="utf-8")
    starts = list(re.finditer(r"^func\s+(\w+)\s*\(", source, re.M))
    bodies = {}
    for i, match in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(source)
        block = source[match.end():end]
        # Header may wrap; compare the actual body from the first indented line.
        body_lines = block.splitlines()
        first = next((n for n, line in enumerate(body_lines)
                      if line.startswith("\t") or line.startswith("    ")), len(body_lines))
        normalized = "\n".join(
            line.strip() for line in body_lines[first:]
            if line.strip() and not line.strip().startswith("#")
        )
        if normalized:
            bodies[match.group(1)] = normalized
    return bodies


def main() -> int:
    ancestry = inheritance_chain(active_script())
    seen: dict[tuple[str, str], pathlib.Path] = {}
    duplicates = []
    for path in ancestry:
        for name, body in methods(path).items():
            key = name, body
            if key in seen:
                duplicates.append((name, seen[key], path))
            else:
                seen[key] = path
    if duplicates:
        for name, first, second in duplicates:
            print(f"FAIL: duplicate inherited method {name}: "
                  f"{first.relative_to(ancestry[0].parents[2])} / "
                  f"{second.relative_to(ancestry[0].parents[2])}")
        return 1
    print(f"PASS: no identical inherited method bodies across {len(ancestry)} active layers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
