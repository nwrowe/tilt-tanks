extends RefCounted
class_name OnlineDuelHostCoordinator

## Host-only timer and turn-advance decisions. No scene or RPC dependencies.
## Actual projectile state mutations and authoritative sends stay in the game.
var sync_remaining: float = 0.0
var fallback_remaining: float = 0.0
var fallback_owner: int = -1

func reset() -> void:
	sync_remaining = 0.0
	clear_fallback()

func force_next_sync() -> void:
	sync_remaining = 0.0

func due_for_sync(delta: float, peer_connected: bool, active_motion: bool, active_interval: float, idle_interval: float) -> bool:
	if not peer_connected:
		return false
	sync_remaining -= delta
	if sync_remaining > 0.0:
		return false
	sync_remaining = active_interval if active_motion else idle_interval
	return true

func arm_fallback(owner: int, delay: float) -> void:
	fallback_owner = owner
	fallback_remaining = delay

func clear_fallback() -> void:
	fallback_remaining = 0.0
	fallback_owner = -1

func fallback_due(delta: float, current_player: int, safe_to_advance: bool) -> bool:
	if fallback_owner < 0:
		return false
	if current_player != fallback_owner:
		clear_fallback()
		return false
	fallback_remaining = maxf(0.0, fallback_remaining - delta)
	if fallback_remaining > 0.0 or not safe_to_advance:
		return false
	clear_fallback()
	return true

static func can_advance(
	game_over: bool,
	projectile_active: bool,
	has_turn_projectiles: bool,
	machine_gun_active: bool,
	machine_gun_waiting: bool,
	explosion_timer: float,
	cluster_hold_timer: float
) -> bool:
	return WeaponFramePolicy.can_advance_turn(
		game_over, projectile_active, has_turn_projectiles,
		machine_gun_active, machine_gun_waiting, explosion_timer,
		cluster_hold_timer
	)
