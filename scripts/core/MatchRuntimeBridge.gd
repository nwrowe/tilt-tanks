extends "res://scripts/weapons/WeaponSplitRuntimeBridge.gd"

# Transitional bridge for wiring MatchState / MatchController into the active
# game without changing gameplay ownership all at once. MatchController now owns
# simple turn advancement and mirrors active projectile, explosion, health, and
# winner state for the current runtime.

var match_state: MatchState = MatchState.new()
var match_controller: MatchController = MatchController.new(match_state)

func reset_match() -> void:
	super.reset_match()
	_initialize_match_controller_from_runtime_reset()
	_sync_match_state_from_runtime()

func _process(delta: float) -> void:
	super._process(delta)
	_sync_match_state_from_runtime()

func _advance_turn() -> void:
	_sync_match_state_from_runtime()
	match_controller.advance_turn(TURN_TIME_LIMIT)
	_apply_post_turn_match_state()

func _end_turn_without_shot() -> void:
	_sync_match_state_from_runtime()
	_save_runtime_current_player_settings()
	match_controller.end_turn_without_shot(TURN_TIME_LIMIT)
	_apply_post_turn_match_state()

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

func _initialize_match_controller_from_runtime_reset() -> void:
	var default_angle: float = angle_deg
	var default_power: float = power
	var default_power_percent: float = power_percent if "power_percent" in self else 50.0
	var mode: int = game_mode if "game_mode" in self else 0
	var world_width: float = active_world_width if "active_world_width" in self else WORLD_WIDTH
	var left_start: Vector2 = tank_positions[0] if tank_positions.size() > 0 else Vector2.ZERO
	var right_start: Vector2 = tank_positions[1] if tank_positions.size() > 1 else Vector2.ZERO
	match_controller.start_match(
		mode,
		world_width,
		TURN_TIME_LIMIT,
		default_angle,
		default_power,
		default_power_percent,
		left_start,
		right_start,
		wind
	)

func _apply_post_turn_match_state() -> void:
	_apply_match_state_to_runtime_basics()
	_load_current_player_settings()
	_clear_turn_input_state()
	_sync_match_state_from_runtime()

func _clear_turn_input_state() -> void:
	mobile_left_pressed = false
	mobile_right_pressed = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()

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
		match_controller.begin_projectile(projectile_pos, projectile_vel)
	elif explosion_pos != Vector2.INF and explosion_timer > 0.0:
		match_controller.finish_projectile_with_explosion(explosion_pos, explosion_timer)
	else:
		match_controller.finish_projectile()
		if explosion_timer <= 0.0:
			match_controller.clear_explosion()

func _sync_health_state_to_match_controller() -> void:
	for player: int in range(tank_health.size()):
		match_controller.set_health(player, int(tank_health[player]))
	_sync_game_over_state_from_match_controller()

func _sync_game_over_state_from_match_controller() -> void:
	game_over = match_state.game_over
	# Keep the runtime health array as the rendering/UI source during transition.
	# The controller owns winner detection, while the existing UI still reads
	# game_over and tank_health directly.

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
	_recompute_match_winner_from_runtime_health()
	_sync_game_over_state_from_match_controller()

func _apply_match_state_to_runtime_basics() -> void:
	current_player = match_state.current_player
	turn_timer = match_state.turn_timer
	wind = match_state.wind
	game_over = match_state.game_over
	if match_state.tank_positions.size() == tank_positions.size():
		tank_positions = match_state.tank_positions.duplicate()
	if match_state.tank_health.size() == tank_health.size():
		tank_health = match_state.tank_health.duplicate()
	if match_state.player_angles.size() == player_angles.size():
		player_angles = match_state.player_angles.duplicate()
	if match_state.player_powers.size() == player_powers.size():
		player_powers = match_state.player_powers.duplicate()
	if "player_power_percents" in self and match_state.player_power_percents.size() == player_power_percents.size():
		player_power_percents = match_state.player_power_percents.duplicate()

func _apply_match_projectile_state_to_runtime() -> void:
	projectile_active = match_state.projectile_active
	projectile_pos = match_state.projectile_pos
	projectile_vel = match_state.projectile_vel
	explosion_pos = match_state.explosion_pos
	explosion_timer = match_state.explosion_timer

func _recompute_match_winner_from_runtime_health() -> void:
	for player: int in range(tank_health.size()):
		match_controller.set_health(player, int(tank_health[player]))
