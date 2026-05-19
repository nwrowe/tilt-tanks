extends ModeController
class_name RealtimeSinglePlayerModeController

func mode_name() -> String:
	return "realtime_single_player"

func player_can_fire(player_shell_active: bool, game_over: bool) -> bool:
	return RealtimeSinglePlayerMode.player_can_fire(player_shell_active, game_over)

func can_begin_fire_charge(
	keyboard_down: bool,
	keyboard_held: bool,
	player_shell_active: bool,
	game_over: bool,
	overlay_open: bool
) -> bool:
	return RealtimeSinglePlayerMode.can_begin_fire_charge(keyboard_down, keyboard_held, player_shell_active, game_over, overlay_open)

func should_release_fire_charge(keyboard_down: bool, keyboard_held: bool) -> bool:
	return RealtimeSinglePlayerMode.should_release_fire_charge(keyboard_down, keyboard_held)

func charge_percent(charge_time: float, charge_time_max: float, min_percent: float, max_percent: float) -> float:
	return RealtimeSinglePlayerMode.charge_percent(charge_time, charge_time_max, min_percent, max_percent)

func shell_status_label(player_shell_active: bool, charging: bool, charge_percent_value: float, cooldown: float) -> String:
	return RealtimeSinglePlayerMode.shell_status_label(player_shell_active, charging, charge_percent_value, cooldown)

func should_show_turn_widget() -> bool:
	return false
