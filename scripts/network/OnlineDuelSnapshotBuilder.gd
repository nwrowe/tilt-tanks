extends RefCounted
class_name OnlineDuelSnapshotBuilder

## The wire schema for online state lives here, independent of RPC transport.
## Callers pass explicit runtime data, rather than giving this class a game node.
## Keep existing field names and packed Vector2 representation for compatibility.

static func build_common(state: Dictionary) -> Dictionary:
	return {
		"tank_positions": OnlineDuelCodec.pack_vec2_array(state["tank_positions"]),
		"tank_health": (state["tank_health"] as Array).duplicate(),
		"player_angles": (state["player_angles"] as Array).duplicate(),
		"player_power_percents": (state["player_power_percents"] as Array).duplicate(),
		"player_powers": (state["player_powers"] as Array).duplicate(),
		"current_player": state["current_player"],
		"angle_deg": state["angle_deg"],
		"power_percent": state["power_percent"],
		"power": state["power"],
		"wind": state["wind"],
		"turn_timer": state["turn_timer"],
		"game_over": state["game_over"],
		"selected_weapon": state["selected_weapon"],
		"projectile_active": state["projectile_active"],
		"projectile_pos": OnlineDuelCodec.pack_vec2(state["projectile_pos"]),
		"projectile_vel": OnlineDuelCodec.pack_vec2(state["projectile_vel"]),
		"turn_projectiles": (state["turn_projectiles"] as Array).duplicate(true),
		"explosion_pos": OnlineDuelCodec.pack_vec2(state["explosion_pos"]),
		"explosion_timer": state["explosion_timer"],
		"hotseat_turn_start_pending": state["hotseat_turn_start_pending"],
		"pending_advance_after_explosion_hold": state["pending_advance_after_explosion_hold"],
		"cluster_camera_hold_timer": state["cluster_camera_hold_timer"],
		"cluster_camera_hold_pos": OnlineDuelCodec.pack_vec2(state["cluster_camera_hold_pos"])
	}

static func build_full(state: Dictionary, world: Dictionary) -> Dictionary:
	var packet: Dictionary = {
		"active_world_width": world["active_world_width"],
		"active_right_start_x": world["active_right_start_x"],
		"terrain_points": OnlineDuelCodec.pack_vec2_array(world["terrain_points"]),
		"ponds": (world["ponds"] as Array).duplicate(true)
	}
	packet.merge(build_common(state))
	return packet

static func build_motion(state: Dictionary, turn_camera_pos: Vector2) -> Dictionary:
	var packet: Dictionary = build_common(state)
	packet["turn_cluster_camera_pos"] = OnlineDuelCodec.pack_vec2(turn_camera_pos)
	return packet
