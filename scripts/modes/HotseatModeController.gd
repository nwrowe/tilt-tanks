extends ModeController
class_name HotseatModeController

func mode_name() -> String:
	return "hotseat"

func is_active(menu_state: int, game_mode: int, menu_state_game: int, realtime_mode: int) -> bool:
	return HotseatMode.is_active(menu_state, game_mode, menu_state_game, realtime_mode)

func can_begin_charge(projectile_active: bool, turn_projectiles: Array, game_over: bool, overlay_open: bool) -> bool:
	return HotseatMode.can_begin_charge(projectile_active, turn_projectiles, game_over, overlay_open)

func can_begin_keyboard_charge(
	keyboard_down: bool,
	keyboard_held: bool,
	projectile_active: bool,
	turn_projectiles: Array,
	game_over: bool,
	overlay_open: bool
) -> bool:
	return HotseatMode.can_begin_keyboard_charge(keyboard_down, keyboard_held, projectile_active, turn_projectiles, game_over, overlay_open)

func should_release_keyboard_charge(keyboard_down: bool, keyboard_held: bool) -> bool:
	return HotseatMode.should_release_keyboard_charge(keyboard_down, keyboard_held)

func charge_percent(charge_time: float, charge_time_max: float, min_percent: float, max_percent: float) -> float:
	return HotseatMode.charge_percent(charge_time, charge_time_max, min_percent, max_percent)

func turn_label(current_player: int, turn_timer: float) -> String:
	return HotseatMode.turn_label(current_player, turn_timer)

func should_show_turn_widget() -> bool:
	return true
