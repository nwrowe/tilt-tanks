extends RefCounted
class_name OnlineDuelCommandValidator

## Pure host-side authorization and payload normalization. The game remains
## responsible for its RPC entry points and executing accepted commands.

static func can_start_turn(
	sender_id: int,
	guest_peer_id: int,
	current_player: int,
	guest_player: int,
	start_prompt_active: bool
) -> bool:
	return (
		guest_peer_id > 0
		and sender_id == guest_peer_id
		and current_player == guest_player
		and start_prompt_active
	)

static func can_fire(
	sender_id: int,
	guest_peer_id: int,
	current_player: int,
	guest_player: int,
	shot_blocked: bool
) -> bool:
	return (
		guest_peer_id > 0
		and sender_id == guest_peer_id
		and current_player == guest_player
		and not shot_blocked
	)

static func normalize_fire(
	payload: Dictionary,
	default_angle: float,
	default_percent: float,
	min_angle: float,
	max_angle: float,
	min_percent: float,
	max_percent: float,
	loadout: WeaponLoadout,
	default_weapon: String
) -> Dictionary:
	var raw_angle: Variant = payload.get("angle", default_angle)
	var raw_percent: Variant = payload.get("power_percent", default_percent)
	if not (raw_angle is float or raw_angle is int):
		return {}
	if not (raw_percent is float or raw_percent is int):
		return {}
	var requested_angle: float = float(raw_angle)
	var requested_percent: float = float(raw_percent)
	if is_nan(requested_angle) or is_inf(requested_angle):
		return {}
	if is_nan(requested_percent) or is_inf(requested_percent):
		return {}
	return {
		"angle": clampf(requested_angle, min_angle, max_angle),
		"power_percent": clampf(requested_percent, min_percent, max_percent),
		"weapon": OnlineDuelCodec.safe_requested_weapon(payload, loadout, default_weapon)
	}
