extends ModeController
class_name CampaignModeController

# Placeholder controller for future campaign flow.
# Campaign should eventually own level selection, progression, unlocks, scripted
# constraints, and campaign-specific loadouts, while reusing match/weapons/world
# systems underneath.

var campaign_id: String = "default"
var level_index: int = 0

func mode_name() -> String:
	return "campaign"

func enter_mode() -> void:
	pass

func exit_mode() -> void:
	pass

func should_show_turn_widget() -> bool:
	return true

func set_campaign_level(id: String, index: int) -> void:
	campaign_id = id
	level_index = max(0, index)
