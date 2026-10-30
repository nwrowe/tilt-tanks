extends RefCounted
class_name MainMenuNavigationSession

## Owns the active menu screen and single-player selection, not controls.
## The Node2D runtime still owns navigation callbacks and mode-specific
## side effects; MainMenuView remains responsible for UI instances.

const MAIN: int = 0
const SINGLE_PLAYER: int = 1
const OPTIONS: int = 2
const MULTIPLAYER: int = 3
const GAME: int = 4

var screen: int = MAIN
var single_player: bool = false

func open_main() -> void:
	screen = MAIN
	single_player = false

func open_single_player() -> void:
	screen = SINGLE_PLAYER
	single_player = true

func open_multiplayer() -> void:
	screen = MULTIPLAYER
	single_player = false

func show_online() -> void:
	# Existing online action retains the previous single-player flag.
	screen = MULTIPLAYER

func open_options() -> void:
	# Existing options path retains the previous selection flag.
	screen = OPTIONS

func choose_single_player(value: bool) -> void:
	single_player = value

func enter_game() -> void:
	# The scene clears menu controls between selection and this transition.
	screen = GAME
