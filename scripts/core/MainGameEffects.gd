extends "res://scripts/core/MainGame.gd"

# Temporary effects facade during refactor.
#
# This keeps the scene using organized core scripts while moving effect math
# into scripts/effects/EffectsManager.gd. Once the remaining legacy chain is
# collapsed, these overrides should be folded back into MainGame.gd or into a
# dedicated node-based effects system.

func _update_muzzle_effects(delta: float) -> void:
	for i: int in range(barrel_recoil_timers.size()):
		barrel_recoil_timers[i] = maxf(0.0, barrel_recoil_timers[i] - delta)
	muzzle_smoke_puffs = EffectsManager.update_rising_puffs(muzzle_smoke_puffs, delta, MUZZLE_SMOKE_RISE_SPEED)
	if not muzzle_smoke_puffs.is_empty():
		queue_redraw()

func _spawn_destroyed_smoke_puff() -> void:
	if destroyed_tank_index < 0 or destroyed_tank_index >= tank_positions.size():
		return
	var base_pos: Vector2 = tank_positions[destroyed_tank_index]
	var offset: Vector2 = Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-36.0, -18.0))
	destroyed_smoke_puffs.append(EffectsManager.make_puff(
		base_pos + offset,
		DESTROYED_SMOKE_LIFETIME,
		rng.randf_range(-DESTROYED_SMOKE_DRIFT_SPEED, DESTROYED_SMOKE_DRIFT_SPEED)
	))

func _spawn_steam_puff() -> void:
	var base_pos: Vector2 = tank_positions[HUMAN_PLAYER_INDEX]
	var offset: Vector2 = Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-33.0, -22.0))
	steam_puffs.append(EffectsManager.make_puff(
		base_pos + offset,
		STEAM_PUFF_LIFETIME,
		rng.randf_range(-STEAM_PUFF_DRIFT_SPEED, STEAM_PUFF_DRIFT_SPEED)
	))

func _draw_muzzle_smoke_puffs() -> void:
	for puff: Dictionary in muzzle_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", MUZZLE_SMOKE_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, MUZZLE_SMOKE_START_RADIUS, MUZZLE_SMOKE_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.46)
		draw_circle(_world_to_screen(pos), radius, Color(0.82, 0.84, 0.80, alpha))

func _draw_destroyed_smoke_puffs() -> void:
	for puff: Dictionary in destroyed_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", DESTROYED_SMOKE_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, DESTROYED_SMOKE_START_RADIUS, DESTROYED_SMOKE_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.58)
		draw_circle(_world_to_screen(pos), radius, Color(0.78, 0.80, 0.77, alpha))

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = EffectsManager.effect_radius(age, life, STEAM_PUFF_START_RADIUS, STEAM_PUFF_END_RADIUS) * CAMERA_SCALE
		var alpha: float = EffectsManager.effect_alpha(age, life, 0.52)
		draw_circle(_world_to_screen(pos), radius, Color(0.88, 0.90, 0.86, alpha))
