extends ModeController
class_name NetworkMultiplayerModeController

# Placeholder controller for future network multiplayer.
# The long-term goal is for this mode to consume match commands rather than
# reading local keyboard/mobile callbacks directly.

var local_player_index: int = 0
var is_host: bool = false
var session_id: String = ""

func mode_name() -> String:
	return "network_multiplayer"

func enter_mode() -> void:
	pass

func exit_mode() -> void:
	pass

func can_player_fire() -> bool:
	return true

func can_player_move() -> bool:
	return true

func should_show_turn_widget() -> bool:
	return true

func configure_network_session(id: String, host: bool, player_index: int) -> void:
	session_id = id
	is_host = host
	local_player_index = clampi(player_index, 0, 1)
