extends "res://scripts/MainHybridModes6.gd"

func _draw_turn_widget() -> void:
	# Realtime single-player has no turns, so hide the old bottom-right turn timer.
	# Hotseat and other turn-based modes keep the existing timer behavior.
	if game_mode == GAME_MODE_SINGLE_PLAYER_REALTIME and menu_state == MENU_STATE_GAME:
		return
	super._draw_turn_widget()
