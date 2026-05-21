extends RefCounted
class_name CommandBuffer

# Small ordered command queue for future network/campaign/replay plumbing.

var next_sequence_id: int = 1
var pending_commands: Array[NetworkCommand] = []

func push(command_type: String, player_index: int = 0, payload: Dictionary = {}) -> NetworkCommand:
	var command: NetworkCommand = NetworkCommand.new(command_type, player_index, payload, next_sequence_id)
	next_sequence_id += 1
	pending_commands.append(command)
	return command

func push_command(command: NetworkCommand) -> void:
	if command == null:
		return
	pending_commands.append(command)
	next_sequence_id = maxi(next_sequence_id, command.sequence_id + 1)

func has_commands() -> bool:
	return not pending_commands.is_empty()

func pop_next() -> NetworkCommand:
	if pending_commands.is_empty():
		return null
	pending_commands.sort_custom(func(a: NetworkCommand, b: NetworkCommand) -> bool:
		return a.sequence_id < b.sequence_id
	)
	return pending_commands.pop_front()

func clear() -> void:
	pending_commands.clear()

func to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for command: NetworkCommand in pending_commands:
		result.append(command.to_dictionary())
	return result
