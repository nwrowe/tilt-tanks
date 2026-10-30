extends RefCounted
class_name OnlineDuelSnapshotDecoder

## Decode the fields shared by full and motion packets. Runtime side effects,
## interpolation, terrain geometry, projectile transitions and RPCs stay in
## the game node. Do not return untyped arrays for strongly typed player data.
static func decode_common(snapshot: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"tank_health": OnlineDuelCodec.int_array(snapshot.get("tank_health", fallback["tank_health"]), fallback["tank_health"]),
		"player_angles": OnlineDuelCodec.float_array(snapshot.get("player_angles", fallback["player_angles"]), fallback["player_angles"]),
		"player_power_percents": OnlineDuelCodec.float_array(snapshot.get("player_power_percents", fallback["player_power_percents"]), fallback["player_power_percents"]),
		"player_powers": OnlineDuelCodec.float_array(snapshot.get("player_powers", fallback["player_powers"]), fallback["player_powers"]),
		"current_player": int(snapshot.get("current_player", fallback["current_player"])),
		"angle_deg": float(snapshot.get("angle_deg", fallback["angle_deg"])),
		"power_percent": float(snapshot.get("power_percent", fallback["power_percent"])),
		"power": float(snapshot.get("power", fallback["power"])),
		"wind": float(snapshot.get("wind", fallback["wind"])),
		"turn_timer": float(snapshot.get("turn_timer", fallback["turn_timer"])),
		"game_over": bool(snapshot.get("game_over", fallback["game_over"])),
		"selected_weapon": str(snapshot.get("selected_weapon", fallback["selected_weapon"])),
		"projectile_active": bool(snapshot.get("projectile_active", fallback["projectile_active"])),
		"explosion_pos": OnlineDuelCodec.unpack_vec2(snapshot.get("explosion_pos", fallback["explosion_pos"])),
		"explosion_timer": float(snapshot.get("explosion_timer", fallback["explosion_timer"])),
		"hotseat_turn_start_pending": bool(snapshot.get("hotseat_turn_start_pending", fallback["hotseat_turn_start_pending"])),
		"pending_advance_after_explosion_hold": bool(snapshot.get("pending_advance_after_explosion_hold", fallback["pending_advance_after_explosion_hold"])),
		"cluster_camera_hold_timer": float(snapshot.get("cluster_camera_hold_timer", fallback["cluster_camera_hold_timer"])),
		"cluster_camera_hold_pos": OnlineDuelCodec.unpack_vec2(snapshot.get("cluster_camera_hold_pos", fallback["cluster_camera_hold_pos"]))
	}
