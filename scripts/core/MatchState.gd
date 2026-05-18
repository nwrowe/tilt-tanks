extends RefCounted
class_name MatchState

# Lightweight data container for match/session state.
# This is intentionally passive: it stores state but does not mutate gameplay on
# its own. MatchController will own state transitions as logic is migrated out
# of the legacy bridge chain.

var current_player: int = 0
var tank_positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var tank_health: Array[int] = [100, 100]
var player_angles: Array[float] = [45.0, 45.0]
var player_powers: Array[float] = [800.0, 800.0]
var player_power_percents: Array[float] = [50.0, 50.0]

var wind: float = 0.0
var turn_timer: float = 0.0
var game_over: bool = false
var winner_index: int = -1

var game_mode: int = 0
var active_world_width: float = 1500.0

var projectile_active: bool = false
var projectile_pos: Vector2 = Vector2.ZERO
var projectile_vel: Vector2 = Vector2.ZERO
var explosion_pos: Vector2 = Vector2.INF
var explosion_timer: float = 0.0

func reset_players(
	default_angle: float,
	default_power: float,
	default_power_percent: float,
	left_start: Vector2,
	right_start: Vector2
) -> void:
	current_player = 0
	tank_positions = [left_start, right_start]
	tank_health = [100, 100]
	player_angles = [default_angle, default_angle]
	player_powers = [default_power, default_power]
	player_power_percents = [default_power_percent, default_power_percent]
	game_over = false
	winner_index = -1

func reset_projectile_state() -> void:
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0

func mark_winner(index: int) -> void:
	winner_index = index
	game_over = index >= 0

func active_player_angle() -> float:
	return float(player_angles[current_player])

func active_player_power() -> float:
	return float(player_powers[current_player])

func active_player_power_percent() -> float:
	return float(player_power_percents[current_player])
