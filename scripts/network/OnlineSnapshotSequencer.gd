extends RefCounted
class_name OnlineSnapshotSequencer

## Orders authoritative snapshots and effects. The host owns outgoing
## sequence numbers; clients reject updates older than already-applied state.
## Preserves existing legacy behavior for packets without sequence numbers.
var outgoing_sequence: int = 0
var last_full_sequence: int = -1
var last_motion_sequence: int = -1

func reset() -> void:
	outgoing_sequence = 0
	last_full_sequence = -1
	last_motion_sequence = -1

func next_outgoing_sequence() -> int:
	outgoing_sequence += 1
	return outgoing_sequence

func accept_full(snapshot: Dictionary) -> bool:
	var seq: int = int(snapshot.get("seq", -1))
	if seq < 0:
		return true
	if seq <= last_full_sequence:
		return false
	last_full_sequence = seq
	last_motion_sequence = maxi(last_motion_sequence, seq)
	return true

func accept_motion(snapshot: Dictionary) -> bool:
	var seq: int = int(snapshot.get("seq", -1))
	if seq < 0:
		return true
	if seq <= last_motion_sequence:
		return false
	last_motion_sequence = seq
	return true

func accept_fire_event(event: Dictionary) -> bool:
	var seq: int = int(event.get("seq", -1))
	if seq < 0:
		return true
	if seq <= last_full_sequence:
		return false
	last_motion_sequence = maxi(last_motion_sequence, seq)
	return true
