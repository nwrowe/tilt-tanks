extends ScrollContainer
class_name CampaignMapView

## Self-contained visual map and drag handler. The root only supplies a
## level-selection callback; this view does not start matches or own campaign saves.
const MAP_BG_PATH: String = "res://assets/menu/campaign_map_background_wide.png"
const MAP_SIZE: Vector2 = Vector2(2200.0, 540.0)

var level_selected: Callable
var dragging: bool = false

func configure(viewport_size: Vector2, on_level_selected: Callable) -> void:
	level_selected = on_level_selected
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(handle_scroll_input)

	var map_root: Control = Control.new()
	map_root.custom_minimum_size = MAP_SIZE
	map_root.size = MAP_SIZE
	map_root.mouse_filter = Control.MOUSE_FILTER_PASS
	map_root.gui_input.connect(handle_scroll_input)
	add_child(map_root)

	_add_campaign_map_background(map_root)
	_add_campaign_route_segment(map_root, Vector2(175.0, 342.0), Vector2(500.0, 312.0))
	_add_campaign_route_segment(map_root, Vector2(500.0, 312.0), Vector2(825.0, 365.0))
	_add_campaign_route_segment(map_root, Vector2(825.0, 365.0), Vector2(1185.0, 295.0))
	_add_campaign_route_segment(map_root, Vector2(1185.0, 295.0), Vector2(1545.0, 350.0))
	_add_campaign_route_segment(map_root, Vector2(1545.0, 350.0), Vector2(1900.0, 270.0))
	_add_campaign_level_node(map_root, 1, "Training\nGrounds", Vector2(175.0, 342.0), true)
	_add_campaign_level_node(map_root, 2, "Ridge\nAmbush", Vector2(500.0, 312.0), false)
	_add_campaign_level_node(map_root, 3, "Frozen\nPass", Vector2(825.0, 365.0), false)
	_add_campaign_level_node(map_root, 4, "Factory\nSiege", Vector2(1185.0, 295.0), false)
	_add_campaign_level_node(map_root, 5, "Canyon\nRun", Vector2(1545.0, 350.0), false)
	_add_campaign_level_node(map_root, 6, "Final\nFortress", Vector2(1900.0, 270.0), false)

func handle_scroll_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		scroll_by(-drag.relative.x)
		accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		dragging = touch.pressed
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-90.0)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(90.0)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			scroll_by(-motion.relative.x)
			accept_event()
		else:
			dragging = false

func scroll_by(delta_x: float) -> void:
	var max_scroll: int = maxi(0, int(MAP_SIZE.x - size.x))
	scroll_horizontal = clampi(scroll_horizontal + int(round(delta_x)), 0, max_scroll)

func _add_campaign_map_background(parent: Control) -> void:
	if ResourceLoader.exists(MAP_BG_PATH):
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.texture = load(MAP_BG_PATH) as Texture2D
		texture_rect.position = Vector2.ZERO
		texture_rect.size = MAP_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(texture_rect)
		return

	_add_map_color_band(parent, Color(0.08, 0.12, 0.24, 1.0), 0.0, 185.0)
	_add_map_color_band(parent, Color(0.12, 0.20, 0.32, 1.0), 185.0, 155.0)
	_add_map_color_band(parent, Color(0.20, 0.34, 0.18, 1.0), 340.0, 200.0)
	_add_campaign_mountain(parent, Vector2(120.0, 270.0), 180.0, 96.0)
	_add_campaign_mountain(parent, Vector2(420.0, 260.0), 230.0, 130.0)
	_add_campaign_mountain(parent, Vector2(760.0, 282.0), 210.0, 106.0)
	_add_campaign_mountain(parent, Vector2(1110.0, 250.0), 270.0, 148.0)
	_add_campaign_mountain(parent, Vector2(1510.0, 286.0), 250.0, 118.0)
	_add_campaign_mountain(parent, Vector2(1910.0, 246.0), 285.0, 150.0)

func _add_map_color_band(parent: Control, color: Color, y: float, height: float) -> void:
	var band: ColorRect = ColorRect.new()
	band.color = color
	band.position = Vector2(0.0, y)
	band.size = Vector2(MAP_SIZE.x, height)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(band)

func _add_campaign_mountain(parent: Control, center: Vector2, width: float, height: float) -> void:
	var mountain: Polygon2D = Polygon2D.new()
	mountain.polygon = PackedVector2Array([
		center + Vector2(-width * 0.50, height * 0.55),
		center + Vector2(-width * 0.20, -height * 0.35),
		center + Vector2(0.0, -height * 0.55),
		center + Vector2(width * 0.28, -height * 0.22),
		center + Vector2(width * 0.55, height * 0.55)
	])
	mountain.color = Color(0.14, 0.13, 0.22, 0.92)
	parent.add_child(mountain)

func _add_campaign_route_segment(parent: Control, start: Vector2, finish: Vector2) -> void:
	var route: Line2D = Line2D.new()
	route.width = 11.0
	route.default_color = Color(0.98, 0.78, 0.25, 0.78)
	route.add_point(start)
	route.add_point(finish)
	parent.add_child(route)

func _add_campaign_level_node(parent: Control, level_index: int, label_text: String, center: Vector2, unlocked: bool) -> void:
	var button: Button = Button.new()
	button.text = "%d\n%s" % [level_index, label_text]
	button.position = center - Vector2(48.0, 48.0)
	button.size = Vector2(96.0, 96.0)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	button.mouse_filter = Control.MOUSE_FILTER_PASS if unlocked else Control.MOUSE_FILTER_IGNORE
	_style_campaign_level_button(button, unlocked)
	parent.add_child(button)
	if unlocked:
		button.pressed.connect(func() -> void:
			level_selected.call(level_index)
		)

func _style_campaign_level_button(button: Button, unlocked: bool) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.32, 0.20, 0.94) if unlocked else Color(0.16, 0.16, 0.18, 0.82)
	normal.border_color = Color(1.0, 0.86, 0.25, 0.95) if unlocked else Color(0.62, 0.62, 0.66, 0.55)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(42)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.20, 0.48, 0.28, 0.98)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.82, 0.82, 0.86, 0.75))
	button.add_theme_font_size_override("font_size", 16)
