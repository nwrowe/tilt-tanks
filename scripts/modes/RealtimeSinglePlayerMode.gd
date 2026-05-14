extends RefCounted
class_name RealtimeSinglePlayerMode

static func is_active(menu_state: int, game_mode: int, game_menu_state: int, realtime_mode: int) -> bool:
	return menu_state == game_menu_state and game_mode == realtime_mode

static func player_can_fire(shell_active: bool, game_over: bool) -> bool:
	return not shell_active and not game_over

static func can_begin_fire_charge(keyboard_down: bool, keyboard_held: bool, shell_active: bool, game_over: bool, overlay_open: bool) -> bool:
	return keyboard_down and not keyboard_held and player_can_fire(shell_active, game_over) and not overlay_open

static func should_release_fire_charge(keyboard_down: bool, keyboard_held: bool) -> bool:
	return not keyboard_down and keyboard_held

static func charge_percent(charge_time: float, charge_time_max: float, min_percent: float, max_percent: float) -> float:
	var ratio: float = clampf(charge_time / maxf(charge_time_max, 0.001), 0.0, 1.0)
	return lerpf(min_percent, max_percent, ratio)

static func should_process_ai(game_over: bool, overlay_open: bool) -> bool:
	return not game_over and not overlay_open

static func shell_status_label(shell_active: bool, charging: bool, charge_percent_value: float, cooldown: float) -> String:
	if charging:
		return "Charge: %.0f%%" % charge_percent_value
	if shell_active:
		return "Shell in flight"
	if cooldown > 0.0:
		return "Fire cooling"
	return "Hold FIRE"
