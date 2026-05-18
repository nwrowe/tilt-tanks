extends "res://scripts/weapons/WeaponRuntimeBridge.gd"

# Transitional bridge for wiring MatchState / MatchController into the active
# game without changing gameplay ownership all at once. For now this mirrors
# the existing inherited runtime state into a MatchState object after key
# lifecycle points. Later passes can move reset/turn/win/projectile ownership
# from the bridge chain into MatchController one behavior at a time.

var match_state: MatchState = MatchState.new()
var match_controller: MatchController = MatchController.new(match_state)

func reset_match() -> void:
	super.reset_match()
	_sync_match_state_from_runtime()

func _advance_turn() -> void:
	super._advance_turn()
	_sync_match_state_from_runtime()

func _end_turn_without_shot() -> void:
	super._end_turn_without_shot()
	_sync_match_state_from_runtime()

func _explode(pos: Vector2) -> void:
	super._explode(pos)
	_sync_match_state_from_runtime()

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
	match_state.projectile_active = projectile_active
	match_state.projectile_pos = projectile_pos
	match_state.projectile_vel = projectile_vel
	match_state.explosion_pos = explosion_pos
	match_state.explosion_timer = explosion_timer
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
