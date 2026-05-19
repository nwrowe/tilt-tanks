extends "res://scripts/core/MainGame.gd"

# Small gameplay-polish facade for global post-explosion camera hold.
# MainGame.gd already has the camera-hold variables and camera-target priority;
# this layer makes player-relevant explosions start a short hold, while realtime
# AI explosions do not pull the camera away from the human player.

const GLOBAL_EXPLOSION_CAMERA_HOLD_TIME: float = 0.50

func _process(delta: float) -> void:
	super._process(delta)
	# Older cluster-specific paths can set a longer hold. Clamp global post-
	# explosion hold to the desired short pause before returning to player focus.
	if cluster_camera_hold_timer > GLOBAL_EXPLOSION_CAMERA_HOLD_TIME:
		cluster_camera_hold_timer = GLOBAL_EXPLOSION_CAMERA_HOLD_TIME

func _explode(pos: Vector2) -> void:
	super._explode(pos)
	_start_global_explosion_camera_hold(pos)

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	super._explode_turn_weapon(pos, weapon, advance_after)
	_start_global_explosion_camera_hold(pos)

func _explode_realtime_weapon(pos: Vector2, weapon: String) -> void:
	# Keep the base explosion/damage behavior, but do not start camera hold here.
	# Realtime camera hold is owner-aware in _update_all_realtime_projectiles().
	super._explode_realtime_weapon(pos, weapon)

func _update_all_realtime_projectiles(delta: float) -> void:
	if rt_projectiles.is_empty():
		return
	var remaining: Array[Dictionary] = []
	var cluster_focus_sum: Vector2 = Vector2.ZERO
	var cluster_focus_n: int = 0
	var had_human_cluster_children: bool = false
	var last_human_cluster_explosion: Vector2 = Vector2.INF
	var had_human_explosion: bool = false
	var last_human_explosion: Vector2 = Vector2.INF

	for shell: Dictionary in rt_projectiles:
		var stepped: Dictionary = ProjectileManager.step_shell(shell, gravity, wind, delta)
		var owner: int = int(stepped.get("owner", HUMAN_PLAYER_INDEX))
		var weapon: String = str(stepped.get("weapon", WEAPON_STANDARD))
		var split_done: bool = bool(stepped.get("split", false))
		var pos: Vector2 = stepped.get("pos", Vector2.ZERO)
		var vel: Vector2 = stepped.get("vel", Vector2.ZERO)

		if weapon == WEAPON_CLUSTER and not split_done and vel.y >= 0.0:
			_spawn_realtime_cluster_children(owner, pos, vel)
			if owner == HUMAN_PLAYER_INDEX:
				realtime_cluster_focus_pos = pos
				realtime_cluster_focus_count = _weapon_child_count(weapon)
		elif _realtime_projectile_should_explode(owner, pos):
			if owner == HUMAN_PLAYER_INDEX:
				had_human_explosion = true
				last_human_explosion = pos
				if weapon == WEAPON_CLUSTER_CHILD:
					had_human_cluster_children = true
					last_human_cluster_explosion = pos
					realtime_cluster_focus_count = maxi(0, realtime_cluster_focus_count - 1)
			_explode_realtime_weapon(pos, weapon)
		else:
			remaining.append(stepped)
			if owner == HUMAN_PLAYER_INDEX and weapon == WEAPON_CLUSTER_CHILD:
				had_human_cluster_children = true
				cluster_focus_sum += pos
				cluster_focus_n += 1

	rt_projectiles = remaining
	rt_player_shell_active = ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX)

	if cluster_focus_n > 0:
		realtime_cluster_focus_pos = cluster_focus_sum / float(cluster_focus_n)
		_start_global_explosion_camera_hold(realtime_cluster_focus_pos)
	elif had_human_cluster_children:
		if last_human_cluster_explosion != Vector2.INF:
			realtime_cluster_focus_pos = last_human_cluster_explosion
			_start_global_explosion_camera_hold(last_human_cluster_explosion)
		if realtime_cluster_focus_count <= 0:
			realtime_cluster_focus_pos = Vector2.INF
	elif had_human_explosion and last_human_explosion != Vector2.INF:
		realtime_cluster_focus_pos = Vector2.INF
		_start_global_explosion_camera_hold(last_human_explosion)
	elif not ProjectileManager.has_shell_for_owner(rt_projectiles, HUMAN_PLAYER_INDEX):
		realtime_cluster_focus_pos = Vector2.INF

func _start_global_explosion_camera_hold(pos: Vector2) -> void:
	if pos == Vector2.INF:
		return
	cluster_camera_hold_pos = pos
	cluster_camera_hold_timer = GLOBAL_EXPLOSION_CAMERA_HOLD_TIME
	manual_camera_active = false
