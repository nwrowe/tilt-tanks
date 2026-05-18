extends "res://scripts/MainStableTweaks.gd"

const MENU_STATE_MAIN: int = 0
const MENU_STATE_SINGLE_PLAYER: int = 1
const MENU_STATE_OPTIONS: int = 2
const MENU_STATE_MULTIPLAYER: int = 3
const MENU_STATE_GAME: int = 4

var menu_state: int = MENU_STATE_MAIN
var menu_layer: CanvasLayer
var menu_buttons: Array[Control] = []
var menu_logo_texture: Texture2D
var menu_bg_landscape_texture: Texture2D
var menu_bg_portrait_texture: Texture2D
var single_player_mode: bool = false

func _ready() -> void:
	super._ready()
	_load_menu_assets()
	_build_menu_layer()
	_show_main_menu()

func _process(delta: float) -> void:
	if menu_state == MENU_STATE_GAME:
		super._process(delta)
	else:
		queue_redraw()

func _draw() -> void:
	if menu_state == MENU_STATE_GAME:
		super._draw()
		return
	_draw_menu_background()

func _load_menu_assets() -> void:
	menu_bg_landscape_texture = MainMenuUI.load_texture_if_exists(MainMenuUI.MENU_BG_LANDSCAPE_PATH)
	menu_bg_portrait_texture = MainMenuUI.load_texture_if_exists(MainMenuUI.MENU_BG_PORTRAIT_PATH)
	menu_logo_texture = MainMenuUI.load_texture_if_exists(MainMenuUI.MENU_LOGO_PATH)

func _build_menu_layer() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)

func _show_main_menu() -> void:
	menu_state = MENU_STATE_MAIN
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Single Player", MainMenuUI.BUTTON_SINGLE_PLAYER_PATH, Vector2(0.5, 0.54), Vector2(310, 72), _on_single_player_pressed)
	_add_menu_button("Multiplayer", MainMenuUI.BUTTON_MULTIPLAYER_PATH, Vector2(0.5, 0.65), Vector2(310, 72), _on_multiplayer_pressed)
	_add_menu_button("Options", MainMenuUI.BUTTON_OPTIONS_PATH, Vector2(0.5, 0.76), Vector2(310, 72), _on_options_pressed)
	queue_redraw()

func _show_single_player_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Quick Game", MainMenuUI.BUTTON_QUICK_GAME_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_quick_game_pressed)
	_add_menu_button("Campaign", MainMenuUI.BUTTON_CAMPAIGN_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_campaign_pressed)
	_add_menu_button("Back", MainMenuUI.BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _show_placeholder_menu(title: String) -> void:
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label(title, Vector2(0.5, 0.54), Vector2(420, 60), 28)
	_add_text_label("Coming soon", Vector2(0.5, 0.62), Vector2(420, 44), 20)
	_add_menu_button("Back", MainMenuUI.BUTTON_BACK_PATH, Vector2(0.5, 0.76), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _on_single_player_pressed() -> void:
	_show_single_player_menu()

func _on_multiplayer_pressed() -> void:
	menu_state = MENU_STATE_MULTIPLAYER
	_show_placeholder_menu("Multiplayer")

func _on_options_pressed() -> void:
	menu_state = MENU_STATE_OPTIONS
	_show_placeholder_menu("Options")

func _on_campaign_pressed() -> void:
	_show_placeholder_menu("Campaign")

func _on_quick_game_pressed() -> void:
	_start_game(true)

func _start_game(is_single_player: bool) -> void:
	single_player_mode = is_single_player
	_clear_menu_controls()
	menu_state = MENU_STATE_GAME
	_show_game_ui()
	reset_match()
	queue_redraw()

func _hide_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = false

func _show_game_ui() -> void:
	if ui_layer != null:
		ui_layer.visible = true

func _clear_menu_controls() -> void:
	for control: Control in menu_buttons:
		if is_instance_valid(control):
			control.queue_free()
	menu_buttons.clear()

func _add_text_label(text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	return MainMenuUI.make_text_label(menu_layer, menu_buttons, get_viewport_rect().size, text, anchor, size, font_size)

func _add_menu_button(text: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	return MainMenuUI.make_menu_button(menu_layer, menu_buttons, get_viewport_rect().size, text, texture_path, anchor, size, callback)

func _draw_menu_background() -> void:
	MainMenuUI.draw_menu_background(self, get_viewport_rect().size, menu_bg_landscape_texture, menu_bg_portrait_texture, menu_logo_texture)
