extends RefCounted
class_name ModeControllerRegistry

const MODE_HOTSEAT: String = "hotseat"
const MODE_REALTIME_SINGLE_PLAYER: String = "realtime_single_player"
const MODE_REALTIME_AI: String = "realtime_ai"

static func build_default_controllers(owner_node: Node = null, match_controller: MatchController = null) -> Dictionary:
	return {
		MODE_HOTSEAT: HotseatModeController.new(owner_node, match_controller),
		MODE_REALTIME_SINGLE_PLAYER: RealtimeSinglePlayerModeController.new(owner_node, match_controller),
		MODE_REALTIME_AI: RealtimeAIController.new(owner_node, match_controller)
	}

static func controller_for_name(controllers: Dictionary, mode_name: String) -> ModeController:
	if controllers.has(mode_name):
		return controllers[mode_name] as ModeController
	return controllers.get(MODE_HOTSEAT, ModeController.new()) as ModeController
