extends RefCounted
class_name WeaponBurstSession

## Owns a timed, multi-round weapon burst independent of the gameplay node.
## The scene spawns projectiles, triggers effects, follows the camera, and
## decides when a completed burst can advance the turn. This session owns
## mutable burst timing, shot parameters, and turn-shell wait status.
##
## Round firing uses the caller's RNG, with exactly one angle and one power
## jitter draw in that order; recording happens AFTER the scene spawns it.

var active: bool = false
var owner: int = 0
var remaining: int = 0
var timer: float = 0.0
var interval: float = 0.1
var angle: float = 45.0
var power_percent: float = 50.0
var realtime: bool = false
var turn_waiting_for_shells: bool = false

func begin(
	owner_id: int, aim_angle: float, charge_percent: float,
	realtime_mode: bool, round_count: int, round_interval: float
) -> void:
	active = true
	turn_waiting_for_shells = not realtime_mode
	owner = owner_id
	remaining = round_count
	interval = round_interval
	timer = 0.0
	angle = aim_angle
	power_percent = charge_percent
	realtime = realtime_mode

func advance(delta: float) -> void:
	if active:
		timer -= delta

func round_due() -> bool:
	return active and timer <= 0.0

func shot_settings(
	rng: RandomNumberGenerator, angle_jitter: float, power_jitter: float,
	min_angle: float, max_angle: float
) -> Dictionary:
	var shot_angle: float = clampf(
		angle + rng.randf_range(-angle_jitter, angle_jitter), min_angle, max_angle
	)
	var shot_percent: float = clampf(
		power_percent + rng.randf_range(-power_jitter, power_jitter), 0.0, 100.0
	)
	return {"angle": shot_angle, "power_percent": shot_percent}

func round_fired() -> void:
	remaining -= 1
	timer += interval

func finish() -> bool:
	var was_realtime: bool = realtime
	active = false
	return was_realtime

func can_finish_turn(
	game_over: bool, has_turn_shells: bool,
	explosion_timer: float, camera_hold_timer: float
) -> bool:
	return (
		turn_waiting_for_shells and not active and not game_over
		and not has_turn_shells and explosion_timer <= 0.0
		and camera_hold_timer <= 0.0
	)

func clear_active() -> void:
	active = false
	remaining = 0
	timer = 0.0
	turn_waiting_for_shells = false
