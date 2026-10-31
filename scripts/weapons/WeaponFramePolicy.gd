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
