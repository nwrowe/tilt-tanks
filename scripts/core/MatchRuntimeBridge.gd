extends "res://scripts/weapons/WeaponDefinitionRuntimeBridge.gd"

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
	match_controller.complete_turn_without_shot(
		TURN_TIME_LIMIT, angle_deg, power,
		power_percent if "power_percent" in self else 0.0
	)
	_apply_post_turn_match_state()

func _update_projectile(delta: float) -> void:
	super._update_projectile(delta)
	_sync_projectile_state_to_match_controller()

func _explode(pos: Vector2) -> void:
	super._explode(pos)
	_sync_match_state_from_runtime()

func _apply_explosion_damage(pos: Vector2) -> void:
	# Classic explosions previously used the base script's direct/splash loop.
	# The controller now applies that same six-HP-minimum profile to its state.
	_apply_controller_radial_damage(
		pos, DIRECT_HIT_RADIUS, EXPLOSION_RADIUS,
		DIRECT_HIT_DAMAGE, MAX_SPLASH_DAMAGE, 6
	)

func _apply_weapon_damage(pos: Vector2, weapon: String) -> void:
	# Registry-defined weapon stats use the original four-HP splash floor.
	_apply_controller_radial_damage(
		pos, _weapon_direct_radius(weapon), _weapon_explosion_radius(weapon),
		_weapon_direct_damage(weapon), _weapon_splash_damage(weapon), 4
	)

func _apply_controller_radial_damage(
	pos: Vector2,
	direct_radius: float,
	blast_radius: float,
	direct_damage: int,
	splash_damage: int,
	minimum_splash: int
) -> void:
	# Legacy runtime values can have changed since the last frame sync.
	# Adopt them once before applying the damage directly in MatchState.
	match_controller.sync_health_values(tank_health)
	match_controller.apply_radial_damage(
		pos, tank_positions, direct_radius, blast_radius,
		direct_damage, splash_damage, minimum_splash
	)
	tank_health = match_state.tank_health.duplicate()
	_sync_game_over_state_from_match_controller()

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

func _sync_projectile_state_to_match_controller() -> void:
	# Legacy physics still advances the projectile in game runtime; the
	# controller owns how a complete frame changes MatchState lifecycle.
	match_controller.sync_projectile_frame(
		projectile_active, projectile_pos, projectile_vel,
		explosion_pos, explosion_timer
	)

func _sync_health_state_to_match_controller() -> void:
	# Transfer the runtime health values as one transaction. The controller
	# computes game-over/winner only after both tank values have been updated.
	match_controller.sync_health_values(tank_health)
	_sync_game_over_state_from_match_controller()

func _sync_game_over_state_from_match_controller() -> void:
	game_over = match_state.game_over
	# Keep the runtime health array as the rendering/UI source during transition.
	# The controller owns winner detection, while the existing UI still reads
	# game_over and tank_health directly.

func _sync_match_state_from_runtime() -> void:
	var frame_percents: Array[float] = player_power_percents if "player_power_percents" in self else match_state.player_power_percents
	var mode: int = game_mode if "game_mode" in self else 0
	var world_width: float = active_world_width if "active_world_width" in self else WORLD_WIDTH
	match_controller.sync_runtime_player_frame(
		current_player, tank_positions, player_angles, player_powers,
		frame_percents, wind, turn_timer, mode, world_width
	)
	_sync_projectile_state_to_match_controller()
	_sync_health_state_to_match_controller()

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

