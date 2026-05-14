extends RefCounted
class_name HotseatMode

static func is_active(menu_state: int, game_mode: int, game_menu_state: int, realtime_mode: int) -> bool:
	return menu_state == game_menu_state and game_mode != realtime_mode

static func can_begin_charge(projectile_active: bool, turn_projectiles: Array[Dictionary], game_over: bool, overlay_open: bool) -> bool:
	return not projectile_active and turn_projectiles.is_empty() and not game_over and not overlay_open

static func turn_label(current_player: int, turn_timer: float) -> String:
	return "P%d  %02ds" % [current_player + 1, int(ceil(turn_timer))]

static func charge_percent(charge_time: float, charge_time_max: float, min_percent: float, max_percent: float) -> float:
	var ratio: float = clampf(charge_time / maxf(charge_time_max, 0.001), 0.0, 1.0)
	return lerpf(min_percent, max_percent, ratio)
