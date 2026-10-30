#!/usr/bin/env bash
# Run one Godot command, retain its exit status, and reject engine errors.
# Godot may report SCRIPT ERROR/ERROR to stderr yet still exit with code 0.
set -uo pipefail
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

"$@" 2>&1 | tee "$log_file"
godot_status=${PIPESTATUS[0]}

if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|FATAL:' "$log_file"; then
  echo "Godot emitted an engine error even if it returned exit 0" >&2
  exit 1
fi

exit "$godot_status"
