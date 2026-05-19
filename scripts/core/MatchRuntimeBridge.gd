extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

# Transitional bridge for wiring MatchState / MatchController into the active
# game without changing gameplay ownership all at once. MatchController now owns
# simple turn advancement and mirrors active projectile, explosion, health, and
# winner state for the current runtime.

var match_state: MatchState = MatchState.new()
var match_controller: MatchController = MatchController.new(match_state)

func reset_match() -> void:
	super.reset_match()
	_sync_match_state_from_runtime()

func _advance_turn() -> void:
	_sync_match_state_from_runtime()
	current_player = match_controller.advance_turn(TURN_TIME_LIMIT)
	_load_current_player_settings()
	turn_timer = match_state.turn_timer
	mobile_left_pressed = false
	mobile_right_pressed = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()
	_sync_match_state_from_runtime()

func _end_turn_without_shot() -> void:
	_save_runtime_current_player_settings()
	_advance_turn()

func _update_projectile(delta: float) -> void:
	super._update_projectile(delta)
	_sync_projectile_state_to_match_controller()

func _explode(pos: Vector2) -> void:
	super._explode(pos)
	_sync_match_state_from_runtime()

func _apply_explosion_damage(pos: Vector2) -> void:
	super._apply_explosion_damage(pos)
	_sync_health_state_to_match_controller()

func _apply_weapon_damage(pos: Vector2, weapon: String) -> void:
	super._apply_weapon_damage(pos, weapon)
	_sync_health_state_to_match_controller()

func _save_runtime_current_player_settings() -> void:
	if current_player < 0 or current_player >= player_angles.size():
		return
	player_angles[current_player] = angle_deg
	player_powers[current_player] = power
	if "player_power_percents" in self:
		player_power_percents[current_player] = power_percent
	match_controller.save_current_player_settings(angle_deg, power, power_percent if "power_percent" in self else 0.0)

func _sync_projectile_state_to_match_controller() -> void:
	if projectile_active:
		match_controller.set_projectile(projectile_pos, projectile_vel)
	else:
		match_controller.clear_projectile()
	if explosion_pos != Vector2.INF and explosion_timer > 0.0:
		match_controller.set_explosion(explosion_pos, explosion_timer)
	elif explosion_timer <= 0.0:
		match_controller.clear_explosion()

func _sync_health_state_to_match_controller() -> void:
	for player: int in range(tank_health.size()):
		match_controller.set_health(player, int(tank_health[player]))
	game_over = match_state.game_over

func _sync_match_state_from_runtime() -> void:
	match_state.current_player = current_player
	match_state.tank_positions = tank_positions.duplicate()
	match_state.tank_health = tank_health.duplicate()
	match_state.player_angles = player_angles.duplicate()
	match_state.player_powers = player_powers.duplicate()
	if "player_power_percents" in self:
		match_state.player_power_percents = player_power_percents.duplicate()
	match_state.wind = wind
	match_state.turn_timer = turn_timer
	match_state.game_over = game_over
	match_state.game_mode = game_mode if "game_mode" in self else 0
	match_state.active_world_width = active_world_width if "active_world_width" in self else WORLD_WIDTH
	_sync_projectile_state_to_match_controller()
	_update_match_state_winner_from_runtime()

func _update_match_state_winner_from_runtime() -> void:
	if tank_health.size() < 2:
		match_state.winner_index = -1
		return
	if tank_health[0] <= 0 and tank_health[1] <= 0:
		match_state.winner_index = -1
		match_state.game_over = true
	elif tank_health[0] <= 0:
		match_state.winner_index = 1
		match_state.game_over = true
	elif tank_health[1] <= 0:
		match_state.winner_index = 0
		match_state.game_over = true
	else:
		match_state.winner_index = -1
