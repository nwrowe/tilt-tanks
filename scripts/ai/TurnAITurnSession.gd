extends RefCounted
class_name TurnAITurnSession

## Owns the computer player's pending-turn state and think timer.
## The runtime's compatibility properties point here while weapon/gameplay
## scripts continue to control visible aiming and actual shot firing.

var pending: bool = false
var think_timer: float = 0.0

func begin(duration: float) -> void:
	pending = true
	think_timer = duration

func step(delta: float) -> bool:
	think_timer -= delta
	return think_timer <= 0.0

func cancel() -> void:
	pending = false

func reset() -> void:
	pending = false
	think_timer = 0.0

static func can_act(
	quick_game: bool, ai_player_turn: bool,
	projectile_active: bool, game_over: bool, overlay_open: bool
) -> bool:
	return quick_game and ai_player_turn and not projectile_active and not game_over and not overlay_open

static func waiting_for_explosion(
	quick_game: bool, ai_player_turn: bool,
	projectile_active: bool, game_over: bool, overlay_open: bool,
	explosion_timer: float
) -> bool:
	return can_act(quick_game, ai_player_turn, projectile_active, game_over, overlay_open) and explosion_timer > 0.0
