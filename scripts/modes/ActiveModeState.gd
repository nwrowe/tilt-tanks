extends RefCounted
class_name ActiveModeState

# Lightweight holder for the currently selected explicit mode controller.
# This keeps mode selection separate from menu/gameplay scripts so campaign,
# realtime, hotseat, and future network modes can switch through one path.

var current_mode_name: String = ModeControllerRegistry.MODE_HOTSEAT
var current_controller: ModeController = null

func set_mode(mode_name: String, controllers: Dictionary) -> ModeController:
	current_mode_name = mode_name
	current_controller = ModeControllerRegistry.controller_for_name(controllers, mode_name)
	return current_controller

func is_mode(mode_name: String) -> bool:
	return current_mode_name == mode_name

func controller() -> ModeController:
	return current_controller
