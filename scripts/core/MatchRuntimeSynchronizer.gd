extends RefCounted
class_name MatchRuntimeSynchronizer

## Composed adapter between legacy game fields and controller-owned state.
## No inheritance from a game node; no UI, physics, or RPC dependencies.
## The caller supplies explicit typed values and applies resulting state.
var controller: MatchController
var state: MatchState

func _init(match_controller: MatchController) -> void:
	controller = match_controller
	state = match_controller.state

func start_match(
	mode: int, world_width: float, turn_time_limit: float,
	angle: float, power: float, power_percent: float,
	left: Vector2, right: Vector2, wind: float
) -> void:
	controller.start_match(
		mode, world_width, turn_time_limit, angle, power,
		power_percent, left, right, wind
	)

func sync_frame(
	player: int, positions: Array[Vector2], angles: Array[float],
	powers: Array[float], power_percents: Array[float],
	wind: float, turn_timer: float, mode: int, world_width: float,
	projectile_active: bool, projectile_pos: Vector2,
	projectile_vel: Vector2, explosion_pos: Vector2,
	explosion_timer: float, health: Array[int]
) -> bool:
	controller.sync_runtime_player_frame(
		player, positions, angles, powers, power_percents,
		wind, turn_timer, mode, world_width
	)
	sync_projectile(
		projectile_active, projectile_pos, projectile_vel,
		explosion_pos, explosion_timer
	)
	return sync_health(health)

func sync_projectile(
	active: bool, pos: Vector2, vel: Vector2,
	explosion_pos: Vector2, explosion_timer: float
) -> void:
	controller.sync_projectile_frame(
		active, pos, vel, explosion_pos, explosion_timer
	)

func sync_health(health: Array[int]) -> bool:
	controller.sync_health_values(health)
	return state.game_over

func apply_radial_damage(
	health: Array[int], positions: Array[Vector2],
	impact: Vector2, direct_radius: float, blast_radius: float,
	direct_damage: int, splash_damage: int,
	minimum_splash: int
) -> Array[int]:
	controller.sync_health_values(health)
	controller.apply_radial_damage(
		impact, positions, direct_radius, blast_radius,
		direct_damage, splash_damage, minimum_splash
	)
	return state.tank_health.duplicate()
