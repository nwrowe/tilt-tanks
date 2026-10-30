#!/usr/bin/env python3
"""Guard the active Godot scene's inheritance chain against regression.

Usage:
    python3 tests/check_inheritance_depth.py --max-depth 14
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCENE = ROOT / "scenes" / "Main.tscn"


def active_script() -> pathlib.Path:
    content = SCENE.read_text(encoding="utf-8")
    result = re.search(
        r'\[ext_resource\s+type="Script"\s+path="res://([^"]+)"',
        content,
    )
    if result is None:
        raise ValueError("Main scene has no Script ext_resource")
    return ROOT / result.group(1)


def inheritance_chain(start: pathlib.Path) -> list[pathlib.Path]:
    chain: list[pathlib.Path] = []
    seen: set[pathlib.Path] = set()
    current = start
    while True:
        if not current.is_file():
            raise FileNotFoundError(f"Missing inheritance ancestor: {current}")
        if current in seen:
            raise ValueError(f"Cycle in inheritance chain: {current}")
        seen.add(current)
        chain.append(current)
        source = current.read_text(encoding="utf-8")
        match = re.search(r'^\s*extends\s+"res://([^"]+)"', source, re.M)
        if match is None:
            if not re.search(r'^\s*extends\s+Node2D\b', source, re.M):
                raise ValueError(f"Unexpected inheritance root: {current}")
            break
        current = ROOT / match.group(1)
    return chain


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-depth", type=int, default=14)
    args = parser.parse_args()
    try:
        chain = inheritance_chain(active_script())
    except (OSError, ValueError) as error:
        print(f"FAIL: cannot determine active Godot inheritance: {error}", file=sys.stderr)
        return 1
    print(f"Active game inheritance: {len(chain)} scripts")
    for index, path in enumerate(chain, 1):
        source = path.read_text(encoding="utf-8")
        methods = len(re.findall(r"^func\s+", source, re.M))
        print(f"{index:2}. {path.relative_to(ROOT)} — {methods} functions")
    if len(chain) > args.max_depth:
        print(
            f"FAIL: {len(chain)} layers exceed allowed {args.max_depth}; "
            "new gameplay features should use composition",
            file=sys.stderr,
        )
        return 1
    print(f"PASS: inheritance depth {len(chain)} <= {args.max_depth}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
