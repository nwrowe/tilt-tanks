extends RefCounted
class_name NetworkCommand

# Passive command object for future network/campaign/replay workflows.
# Local input, AI input, and network input can eventually be converted into
# these commands before being applied to MatchController/runtime systems.

const TYPE_NONE: String = "none"
const TYPE_START_MATCH: String = "start_match"
const TYPE_SELECT_WEAPON: String = "select_weapon"
const TYPE_SET_AIM: String = "set_aim"
const TYPE_BEGIN_CHARGE: String = "begin_charge"
const TYPE_RELEASE_FIRE: String = "release_fire"
const TYPE_MOVE: String = "move"
const TYPE_END_TURN: String = "end_turn"

var command_type: String = TYPE_NONE
var player_index: int = 0
var payload: Dictionary = {}
var sequence_id: int = 0
var timestamp_msec: int = 0

func _init(type: String = TYPE_NONE, player: int = 0, data: Dictionary = {}, sequence: int = 0) -> void:
	command_type = type
	player_index = player
	payload = data.duplicate(true)
	sequence_id = sequence
	timestamp_msec = Time.get_ticks_msec()

func to_dictionary() -> Dictionary:
	return {
		"command_type": command_type,
		"player_index": player_index,
		"payload": payload,
		"sequence_id": sequence_id,
		"timestamp_msec": timestamp_msec
	}

static func from_dictionary(data: Dictionary) -> NetworkCommand:
	var command: NetworkCommand = NetworkCommand.new(
		str(data.get("command_type", TYPE_NONE)),
		int(data.get("player_index", 0)),
		data.get("payload", {}),
		int(data.get("sequence_id", 0))
	)
	command.timestamp_msec = int(data.get("timestamp_msec", Time.get_ticks_msec()))
	return command
