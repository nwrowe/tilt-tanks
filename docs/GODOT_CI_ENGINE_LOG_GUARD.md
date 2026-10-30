# Strict Godot CI engine error handling

Godot sometimes emits SCRIPT ERROR or ERROR messages while returning exit
status zero. The live host/guest test already rejected such messages, but
project import, smoke tests, runtime integration, snapshot contracts,
realtime/camera tests and the short main-scene startup relied on exit
status alone.

All six standalone invocations now run through the shell wrapper
tests/check_godot_run.sh. It streams engine output, preserves the Godot
process status, and fails if the log includes SCRIPT ERROR, ERROR or FATAL.

The two-process ENet step retains its existing separate log/error check.

This is test infrastructure only. It does not alter the game. Any later
Godot warning promoted to an error must be investigated and corrected rather
than blindly removing the safeguard.
