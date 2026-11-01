extends RefCounted
class_name WeaponFramePolicy

## Pure per-frame routing for the inherited weapon runtime. Order matters:
## end-of-game visuals must outrank overlays, which outrank turn shells.
## The game node retains all simulation, UI, camera and drawing side effects.

enum Stage {
	NORMAL,
	GAME_OVER,
	WEAPON_MENU,
	TURN_SHELLS
}

static func select_stage(
	in_game: bool, game_over: bool, weapon_menu_open: bool,
	is_realtime: bool, has_turn_shells: bool
) -> Stage:
	if in_game and game_over:
		return Stage.GAME_OVER
	if in_game and weapon_menu_open:
		return Stage.WEAPON_MENU
	if in_game and not is_realtime and has_turn_shells:
		return Stage.TURN_SHELLS
	return Stage.NORMAL

## A single physics/FX clearance rule for hotseat completion, its camera
## freeze on the final frame, and host-authoritative network turn recovery.
## Callers still own pending-turn gates, camera, network RPCs and side effects.
static func can_advance_turn(
	game_over: bool, projectile_active: bool, has_turn_projectiles: bool,
	burst_active: bool, burst_waiting: bool,
	explosion_timer: float, cluster_hold_timer: float
) -> bool:
	return (
		not game_over
		and not projectile_active
		and not has_turn_projectiles
		and not burst_active
		and not burst_waiting
		and explosion_timer <= 0.0
		and cluster_hold_timer <= 0.0
	)
