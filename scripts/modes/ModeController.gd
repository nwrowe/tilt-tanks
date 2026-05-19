extends RefCounted
class_name ModeController

# Base interface for explicit game-mode controllers.
# These controllers should decide mode policy, not perform rendering or own
# low-level projectile/terrain simulation directly.

var owner_node: Node = null
var match_controller: MatchController = null

func _init(node: Node = null, controller: MatchController = null) -> void:
	owner_node = node
	match_controller = controller

func enter_mode() -> void:
	pass

func exit_mode() -> void:
	pass

func process_mode(_delta: float) -> void:
	pass

func can_player_fire() -> bool:
	return false

func can_player_move() -> bool:
	return false

func should_show_turn_widget() -> bool:
	return false

func mode_name() -> String:
	return "base"
