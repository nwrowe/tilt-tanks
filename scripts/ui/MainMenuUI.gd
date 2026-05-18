extends RefCounted
class_name MainMenuUI

const MENU_BG_LANDSCAPE_PATH: String = "res://assets/menu/main_menu_background_landscape.png"
const MENU_BG_PORTRAIT_PATH: String = "res://assets/menu/main_menu_background_portrait.png"
const MENU_LOGO_PATH: String = "res://assets/menu/tilt_tanks_logo.png"

const BUTTON_SINGLE_PLAYER_PATH: String = "res://assets/menu/button_single_player.png"
const BUTTON_MULTIPLAYER_PATH: String = "res://assets/menu/button_multiplayer.png"
const BUTTON_OPTIONS_PATH: String = "res://assets/menu/button_options.png"
const BUTTON_QUICK_GAME_PATH: String = "res://assets/menu/button_quick_game.png"
const BUTTON_CAMPAIGN_PATH: String = "res://assets/menu/button_campaign.png"
const BUTTON_BACK_PATH: String = "res://assets/menu/button_back.png"

static func load_texture_if_exists(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func anchored_position(viewport_size: Vector2, anchor: Vector2, size: Vector2) -> Vector2:
	return Vector2(viewport_size.x * anchor.x - size.x * 0.5, viewport_size.y * anchor.y - size.y * 0.5)

static func make_text_label(layer: CanvasLayer, buttons: Array, viewport_size: Vector2, text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	label.position = anchored_position(viewport_size, anchor, size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	buttons.append(label)
	return label

static func make_menu_button(layer: CanvasLayer, buttons: Array, viewport_size: Vector2, text: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	var texture: Texture2D = load_texture_if_exists(texture_path)
	if texture != null:
		var texture_button: TextureButton = TextureButton.new()
		texture_button.texture_normal = texture
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_SCALE
		texture_button.size = size
		texture_button.position = anchored_position(viewport_size, anchor, size)
		texture_button.focus_mode = Control.FOCUS_NONE
		texture_button.pressed.connect(callback)
		layer.add_child(texture_button)
		buttons.append(texture_button)
		return texture_button

	var button: Button = Button.new()
	button.text = text
	button.size = size
	button.position = anchored_position(viewport_size, anchor, size)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	style_menu_button(button)
	layer.add_child(button)
	buttons.append(button)
	return button

static func style_menu_button(button: Button) -> void:
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

static func draw_menu_background(drawer: CanvasItem, viewport_size: Vector2, landscape_texture: Texture2D, portrait_texture: Texture2D, logo_texture: Texture2D) -> void:
	var use_landscape: bool = viewport_size.x >= viewport_size.y
	var bg_texture: Texture2D = landscape_texture if use_landscape else portrait_texture

	if bg_texture != null:
		drawer.draw_texture_rect(bg_texture, Rect2(Vector2.ZERO, viewport_size), false)
	else:
		drawer.draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.05, 0.12), true)
		draw_fallback_menu_background(drawer, viewport_size)

	if logo_texture != null:
		draw_menu_logo_texture(drawer, viewport_size, use_landscape, logo_texture)
	else:
		draw_fallback_logo(drawer, viewport_size, use_landscape)

static func draw_menu_logo_texture(drawer: CanvasItem, viewport_size: Vector2, use_landscape: bool, logo_texture: Texture2D) -> void:
	var target_width: float = viewport_size.x * (0.36 if use_landscape else 0.70)
	var aspect: float = float(logo_texture.get_width()) / float(logo_texture.get_height())
	var target_size: Vector2 = Vector2(target_width, target_width / aspect)
	var y: float = viewport_size.y * (0.12 if use_landscape else 0.09)
	var rect: Rect2 = Rect2(Vector2((viewport_size.x - target_size.x) * 0.5, y), target_size)
	drawer.draw_texture_rect(logo_texture, rect, false)

static func draw_fallback_logo(drawer: CanvasItem, viewport_size: Vector2, use_landscape: bool) -> void:
	var title_y: float = viewport_size.y * (0.14 if use_landscape else 0.11)
	var subtitle_y: float = title_y + 48.0
	drawer.draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 95.0, title_y), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
	drawer.draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 125.0, subtitle_y), "TANKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.70, 0.08))

static func draw_fallback_menu_background(drawer: CanvasItem, viewport_size: Vector2) -> void:
	var horizon_y: float = viewport_size.y * 0.56
	var hill_y: float = viewport_size.y * 0.72
	for i: int in range(8):
		var t: float = float(i) / 7.0
		var y0: float = viewport_size.y * t
		var color: Color = Color(0.04 + 0.15 * t, 0.05, 0.16 + 0.20 * t)
		drawer.draw_rect(Rect2(Vector2(0, y0), Vector2(viewport_size.x, viewport_size.y / 7.0 + 2.0)), color, true)
	drawer.draw_circle(Vector2(viewport_size.x * 0.50, horizon_y), 24.0, Color(1.0, 0.78, 0.18, 0.95))
	var mountains: PackedVector2Array = PackedVector2Array()
	mountains.append(Vector2(0, horizon_y + 85.0))
	for i: int in range(8):
		var x: float = viewport_size.x * float(i) / 7.0
		var y: float = horizon_y + 80.0 - 90.0 * absf(sin(float(i) * 1.37))
		mountains.append(Vector2(x, y))
	mountains.append(Vector2(viewport_size.x, horizon_y + 85.0))
	drawer.draw_colored_polygon(mountains, Color(0.19, 0.11, 0.32, 0.95))
	var hill: PackedVector2Array = PackedVector2Array()
	hill.append(Vector2(0, viewport_size.y))
	for i: int in range(30):
		var x2: float = viewport_size.x * float(i) / 29.0
		var y2: float = hill_y + 32.0 * sin(float(i) * 0.42)
		hill.append(Vector2(x2, y2))
	hill.append(Vector2(viewport_size.x, viewport_size.y))
	drawer.draw_colored_polygon(hill, Color(0.08, 0.25, 0.08, 1.0))
