extends RefCounted
class_name MatchController

# Owns match/session state transitions as they are migrated out of the active
# gameplay bridge chain. Keep this controller free of rendering, UI construction,
# and direct input handling.

var state: MatchState

func _init(initial_state: MatchState = null) -> void:
	state = initial_state if initial_state != null else MatchState.new()

func start_match(
	mode: int,
	world_width: float,
	turn_time_limit: float,
	default_angle: float,
	default_power: float,
	default_power_percent: float,
	left_start: Vector2,
	right_start: Vector2,
	initial_wind: float
) -> void:
	state.game_mode = mode
	state.active_world_width = world_width
	state.turn_timer = turn_time_limit
	state.wind = initial_wind
	state.reset_players(default_angle, default_power, default_power_percent, left_start, right_start)
	state.reset_projectile_state()

func advance_turn(turn_time_limit: float) -> int:
	state.current_player = 1 - state.current_player
	state.turn_timer = turn_time_limit
	return state.current_player

func end_turn_without_shot(turn_time_limit: float) -> int:
	return advance_turn(turn_time_limit)

func save_current_player_settings(angle: float, power: float, power_percent: float) -> void:
	var player: int = state.current_player
	if player < 0 or player >= state.player_angles.size():
		return
	state.player_angles[player] = angle
	state.player_powers[player] = power
	state.player_power_percents[player] = power_percent

func begin_projectile(pos: Vector2, vel: Vector2) -> void:
	set_projectile(pos, vel)
	clear_explosion()

func finish_projectile() -> void:
	clear_projectile()

func finish_projectile_with_explosion(pos: Vector2, duration: float) -> void:
	clear_projectile()
	set_explosion(pos, duration)

func set_projectile(pos: Vector2, vel: Vector2) -> void:
	state.projectile_pos = pos
	state.projectile_vel = vel
	state.projectile_active = true

func clear_projectile() -> void:
	state.projectile_active = false
	state.projectile_pos = Vector2.ZERO
	state.projectile_vel = Vector2.ZERO

func set_explosion(pos: Vector2, duration: float) -> void:
	state.explosion_pos = pos
	state.explosion_timer = duration

func clear_explosion() -> void:
	state.explosion_pos = Vector2.INF
	state.explosion_timer = 0.0

func apply_damage(player: int, amount: int) -> void:
	if player < 0 or player >= state.tank_health.size():
		return
	state.tank_health[player] = maxi(0, int(state.tank_health[player]) - amount)
	_update_winner_from_health()

func set_health(player: int, health: int) -> void:
	if player < 0 or player >= state.tank_health.size():
		return
	state.tank_health[player] = maxi(0, health)
	_update_winner_from_health()

func _update_winner_from_health() -> void:
	if state.tank_health[0] <= 0 and state.tank_health[1] <= 0:
		state.mark_winner(-1)
		state.game_over = true
	elif state.tank_health[0] <= 0:
		state.mark_winner(1)
	elif state.tank_health[1] <= 0:
		state.mark_winner(0)
	else:
		state.mark_winner(-1)
		state.game_over = false

func is_game_over() -> bool:
	return state.game_over

func winner_index() -> int:
	return state.winner_index
