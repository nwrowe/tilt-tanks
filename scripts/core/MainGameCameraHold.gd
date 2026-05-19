extends "res://scripts/core/MainGame.gd"

# Small gameplay-polish facade for global post-explosion camera hold.
# MainGame.gd already has the camera-hold variables and camera-target priority;
# this layer makes every explosion path start a short hold, not only cluster
# paths, while leaving projectile, weapon, and match behavior unchanged.

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
	super._explode_realtime_weapon(pos, weapon)
	_start_global_explosion_camera_hold(pos)

func _start_global_explosion_camera_hold(pos: Vector2) -> void:
	if pos == Vector2.INF:
		return
	cluster_camera_hold_pos = pos
	cluster_camera_hold_timer = GLOBAL_EXPLOSION_CAMERA_HOLD_TIME
	manual_camera_active = false
