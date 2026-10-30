extends RefCounted
class_name MainMenuView

## Owns main-menu controls and art. The game node retains navigation,
## game-mode changes and active gameplay input.
var layer: CanvasLayer
var controls: Array[Control] = []
var logo_texture: Texture2D
var landscape_texture: Texture2D
var portrait_texture: Texture2D

func attach(parent: Node) -> void:
	if layer != null:
		return
	layer = CanvasLayer.new()
	layer.layer = 20
	parent.add_child(layer)

func load_assets(landscape_path: String, portrait_path: String, logo_path: String) -> void:
	landscape_texture = _load_texture(landscape_path)
	portrait_texture = _load_texture(portrait_path)
	logo_texture = _load_texture(logo_path)

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func clear() -> void:
	for control: Control in controls:
		if is_instance_valid(control):
			control.queue_free()
	controls.clear()

func add_label(view_size: Vector2, caption: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = size
	label.position = MainMenuPresentation.anchored_position(view_size, anchor, size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	controls.append(label)
	return label

func add_button(view_size: Vector2, caption: String, texture_path: String, anchor: Vector2, size: Vector2, callback: Callable) -> Control:
	var texture: Texture2D = _load_texture(texture_path)
	var pos: Vector2 = MainMenuPresentation.anchored_position(view_size, anchor, size)
	if texture != null:
		var texture_button: TextureButton = TextureButton.new()
		texture_button.texture_normal = texture
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_SCALE
		texture_button.size = size
		texture_button.position = pos
		texture_button.focus_mode = Control.FOCUS_NONE
		texture_button.pressed.connect(callback)
		layer.add_child(texture_button)
		controls.append(texture_button)
		return texture_button

	var button: Button = Button.new()
	button.text = caption
	button.size = size
	button.position = pos
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	style_button(button)
	layer.add_child(button)
	controls.append(button)
	return button

func style_button(button: Button) -> void:
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

func draw_background(canvas: CanvasItem, viewport_size: Vector2) -> void:
	var landscape: bool = viewport_size.x >= viewport_size.y
	var texture: Texture2D = landscape_texture if landscape else portrait_texture
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(Vector2.ZERO, viewport_size), false)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.04, 0.05, 0.12), true)
		MainMenuPresentation.draw_fallback_background(canvas, viewport_size)
	if logo_texture != null:
		var rect: Rect2 = MainMenuPresentation.logo_rect(
			viewport_size, landscape,
			Vector2(float(logo_texture.get_width()), float(logo_texture.get_height()))
		)
		canvas.draw_texture_rect(logo_texture, rect, false)
	else:
		var title_y: float = viewport_size.y * (0.14 if landscape else 0.11)
		canvas.draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 95.0, title_y), "TILT", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
		canvas.draw_string(ThemeDB.fallback_font, Vector2(viewport_size.x * 0.5 - 125.0, title_y + 48.0), "TANKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(1.0, 0.70, 0.08))
