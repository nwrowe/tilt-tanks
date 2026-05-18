extends "res://scripts/MainStableTweaks.gd"

# -----------------------------------------------------------------------------
# Menu asset paths
# Add your finished art to these paths when ready. The game runs with fallback
# colors/text buttons even before the assets exist.
# -----------------------------------------------------------------------------
const MENU_BG_LANDSCAPE_PATH: String = "res://assets/menu/main_menu_background_landscape.png"
const MENU_BG_PORTRAIT_PATH: String = "res://assets/menu/main_menu_background_portrait.png"
const MENU_LOGO_PATH: String = "res://assets/menu/tilt_tanks_logo.png"

const BUTTON_SINGLE_PLAYER_PATH: String = "res://assets/menu/button_single_player.png"
const BUTTON_MULTIPLAYER_PATH: String = "res://assets/menu/button_multiplayer.png"
const BUTTON_OPTIONS_PATH: String = "res://assets/menu/button_options.png"
const BUTTON_QUICK_GAME_PATH: String = "res://assets/menu/button_quick_game.png"
const BUTTON_CAMPAIGN_PATH: String = "res://assets/menu/button_campaign.png"
const BUTTON_BACK_PATH: String = "res://assets/menu/button_back.png"

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
	menu_bg_landscape_texture = _load_texture_if_exists(MENU_BG_LANDSCAPE_PATH)
	menu_bg_portrait_texture = _load_texture_if_exists(MENU_BG_PORTRAIT_PATH)
	menu_logo_texture = _load_texture_if_exists(MENU_LOGO_PATH)

func _load_texture_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_menu_layer() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)

func _show_main_menu() -> void:
	menu_state = MENU_STATE_MAIN
	single_player_mode = false
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Single Player", BUTTON_SINGLE_PLAYER_PATH, Vector2(0.5, 0.54), Vector2(310, 72), _on_single_player_pressed)
	_add_menu_button("Multiplayer", BUTTON_MULTIPLAYER_PATH, Vector2(0.5, 0.65), Vector2(310, 72), _on_multiplayer_pressed)
	_add_menu_button("Options", BUTTON_OPTIONS_PATH, Vector2(0.5, 0.76), Vector2(310, 72), _on_options_pressed)
	queue_redraw()

func _show_single_player_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_clear_menu_controls()
	_add_menu_button("Quick Game", BUTTON_QUICK_GAME_PATH, Vector2(0.5, 0.58), Vector2(310, 72), _on_quick_game_pressed)
	_add_menu_button("Campaign", BUTTON_CAMPAIGN_PATH, Vector2(0.5, 0.69), Vector2(310, 72), _on_campaign_pressed)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.82), Vector2(210, 58), _show_main_menu)
	queue_redraw()

func _show_placeholder_menu(title: String) -> void:
	_hide_game_ui()
	_clear_menu_controls()
	_add_text_label(title, Vector2(0.5, 0.54), Vector2(420, 60), 28)
	_add_text_label("Coming soon", Vector2(0.5, 0.62), Vector2(420, 44), 20)
	_add_menu_button("Back", BUTTON_BACK_PATH, Vector2(0.5, 0.76), Vector2(210, 58), _show_main_menu)
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
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	label.position = _anchored_position(anchor, size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	menu_layer.add_child(label)
	menu_buttons.append(label)
	return label

func _add_menu_button(text: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	var texture: Texture2D = _load_texture_if_exists(texture_path)
	if texture != null:
		var texture_button: TextureButton = TextureButton.new()
		texture_button.texture_normal = texture
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_SCALE
		texture_button.size = size
		texture_button.position = _anchored_position(anchor, size)
		texture_button.focus_mode = Control.FOCUS_NONE
		texture_button.pressed.connect(callback)
		menu_layer.add_child(texture_button)
		menu_buttons.append(texture_button)
		return texture_button

	var button: Button = Button.new()
	button.text = text
	button.size = size
	button.position = _anchored_position(anchor, size)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_style_menu_button(button)
	menu_layer.add_child(button)
	menu_buttons.append(button)
	return button

func _style_menu_button(button: Button) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.12, 0.16, 0.88)
	normal.border_color = Color(0.55, 0.82, 0.95, 0.65)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(18)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.28, 0.34, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 24)

func _anchored_position(anchor: Vector2, size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(viewport_size.x * anchor.x - size.x * 0.5, viewport_size.y * anchor.y - size.y * 0.5)

func _draw_menu_background() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var viewport_size: Vector2 = viewport_rect.size
	var use_landscape: bool = viewport_size.x >= viewport_size.y
	var bg_texture: Texture2D = menu_bg_landscape_texture if use_landscape else menu_bg_portrait_texture

	if bg_texture != null:
		draw_texture_rect(bg_texture, Rect2(Vector2.ZERO, viewport_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.05, 0.12), true)
		_draw_fallback_menu_background(viewport_size)

	if menu_logo_texture != null:
		_draw_menu_logo_texture(viewport_size, use_landscape)
	else:
		_draw_fallback_logo(viewport_size, use_landscape)

func _draw_menu_logo_texture(viewport_size: Vector2, use_landscape: bool) -> void:
	var target_width: float = viewport_size.x * (0.36 if use_landscape else 0.70)
	var aspect: float = float(menu_logo_texture.get_width()) / float(menu_logo_texture.get_height())
	var target_size: Vector2 = Vector2(target_width, target_width / aspect)
	var y: float = viewport_size.y * (0.12 if use_landscape else 0.09)
	var rect: Rect2 = Rect2(Vector2((viewport_size.x - target_size.x) * 0.5, y), target_size)
	draw_texture_rect(menu_logo_texture, rect, false)

func _draw_fallback_logo(viewport_size: Vector2, use_landscape: bool) -> void:
	var title_y: float = viewport_size.y * (0.14 if use_landscape else 0.11)
	var subtitle_y: float = title_y + 48.0
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 95.0, title_y), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 125.0, subtitle_y), "TANKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.70, 0.08))

func _draw_fallback_menu_background(viewport_size: Vector2) -> void:
	var horizon_y: float = viewport_size.y * 0.56
	var hill_y: float = viewport_size.y * 0.72
	for i: int in range(8):
		var t: float = float(i) / 7.0
		var y0: float = viewport_size.y * t
		var color: Color = Color(0.04 + 0.15 * t, 0.05, 0.16 + 0.20 * t)
		draw_rect(Rect2(Vector2(0, y0), Vector2(viewport_size.x, viewport_size.y / 7.0 + 2.0)), color, true)
	draw_circle(Vector2(viewport_size.x * 0.50, horizon_y), 24.0, Color(1.0, 0.78, 0.18, 0.95))
	var mountains: PackedVector2Array = PackedVector2Array()
	mountains.append(Vector2(0, horizon_y + 85.0))
	for i: int in range(8):
		var x: float = viewport_size.x * float(i) / 7.0
		var y: float = horizon_y + 80.0 - 90.0 * absf(sin(float(i) * 1.37))
		mountains.append(Vector2(x, y))
	mountains.append(Vector2(viewport_size.x, horizon_y + 85.0))
	draw_colored_polygon(mountains, Color(0.19, 0.11, 0.32, 0.95))
	var hill: PackedVector2Array = PackedVector2Array()
	hill.append(Vector2(0, viewport_size.y))
	for i: int in range(30):
		var x: float = viewport_size.x * float(i) / 29.0
		var y: float = hill_y + 32.0 * sin(float(i) * 0.42)
		hill.append(Vector2(x, y))
	hill.append(Vector2(viewport_size.x, viewport_size.y))
	draw_colored_polygon(hill, Color(0.08, 0.25, 0.08, 1.0))
