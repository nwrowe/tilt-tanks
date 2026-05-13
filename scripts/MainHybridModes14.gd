extends "res://scripts/MainHybridModes13.gd"

const DESTROYED_SMOKE_INTERVAL: float = 0.16
const DESTROYED_SMOKE_LIFETIME: float = 1.35
const DESTROYED_SMOKE_RISE_SPEED: float = 42.0
const DESTROYED_SMOKE_DRIFT_SPEED: float = 24.0
const DESTROYED_SMOKE_START_RADIUS: float = 5.0
const DESTROYED_SMOKE_END_RADIUS: float = 18.0

var weapon_button: Button
var weapon_panel: Panel
var weapon_menu_open: bool = false
var selected_weapon: String = "standard"
var destroyed_smoke_puffs: Array[Dictionary] = []
var destroyed_smoke_timer: float = 0.0
var destroyed_tank_index: int = -1

func _ready() -> void:
	super._ready()
	_resize_mobile_action_buttons()
	_build_weapon_ui()

func _resize_mobile_action_buttons() -> void:
	if mobile_left_button != null:
		mobile_left_button.position = Vector2(16, 430)
		mobile_left_button.size = Vector2(92, 88)
	if mobile_right_button != null:
		mobile_right_button.position = Vector2(122, 430)
		mobile_right_button.size = Vector2(92, 88)
	if mobile_fire_button != null:
		# Symmetric with the left control margin: 900 - 16 - 188 = 696.
		mobile_fire_button.position = Vector2(696, 448)
		mobile_fire_button.size = Vector2(188, 70)

func _build_weapon_ui() -> void:
	weapon_button = Button.new()
	weapon_button.text = "WEAPON"
	weapon_button.position = Vector2(346, 448)
	weapon_button.size = Vector2(170, 70)
	_style_mobile_button(weapon_button)
	ui_layer.add_child(weapon_button)
	weapon_button.pressed.connect(_toggle_weapon_menu)

	weapon_panel = Panel.new()
	weapon_panel.visible = false
	weapon_panel.position = Vector2(275, 126)
	weapon_panel.size = Vector2(350, 286)
	ui_layer.add_child(weapon_panel)

	var title: Label = Label.new()
	title.text = "Select Weapon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(18, 16)
	title.size = Vector2(314, 32)
	title.add_theme_font_size_override("font_size", 24)
	weapon_panel.add_child(title)

	var standard_button: Button = _make_weapon_menu_button("Standard Shell", Vector2(42, 66))
	standard_button.pressed.connect(func() -> void:
		selected_weapon = "standard"
		_close_weapon_menu()
	)

	var heavy_button: Button = _make_weapon_menu_button("Heavy Shell (soon)", Vector2(42, 120))
	heavy_button.pressed.connect(func() -> void:
		selected_weapon = "standard"
		_close_weapon_menu()
	)

	var cluster_button: Button = _make_weapon_menu_button("Cluster Bomb (soon)", Vector2(42, 174))
	cluster_button.pressed.connect(func() -> void:
		selected_weapon = "standard"
		_close_weapon_menu()
	)

	var close_button: Button = _make_weapon_menu_button("Back", Vector2(86, 232))
	close_button.size = Vector2(178, 38)
	close_button.pressed.connect(_close_weapon_menu)

func _make_weapon_menu_button(text: String, pos: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(266, 40)
	button.focus_mode = Control.FOCUS_NONE
	_style_mobile_button(button)
	weapon_panel.add_child(button)
	return button

func _toggle_weapon_menu() -> void:
	if game_over:
		return
	if weapon_button != null:
		weapon_button.release_focus()
	if weapon_menu_open:
		_close_weapon_menu()
	else:
		_open_weapon_menu()

func _open_weapon_menu() -> void:
	weapon_menu_open = true
	overlay_open = true
	if weapon_panel != null:
		weapon_panel.visible = true
	mobile_left_pressed = false
	mobile_right_pressed = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _close_weapon_menu() -> void:
	weapon_menu_open = false
	if weapon_panel != null:
		weapon_panel.visible = false
	# Preserve pause if another overlay is already visible.
	overlay_open = (menu_panel != null and menu_panel.visible) or (end_panel != null and end_panel.visible)

func _hide_overlays() -> void:
	super._hide_overlays()
	weapon_menu_open = false
	if weapon_panel != null:
		weapon_panel.visible = false

func _process(delta: float) -> void:
	if weapon_menu_open and menu_state == MENU_STATE_GAME:
		_update_destroyed_smoke(delta)
		queue_redraw()
		return
	super._process(delta)
	_update_destroyed_smoke(delta)

func reset_match() -> void:
	destroyed_smoke_puffs.clear()
	destroyed_smoke_timer = 0.0
	destroyed_tank_index = -1
	super.reset_match()
	_resize_mobile_action_buttons()
	_close_weapon_menu()

func _show_end_popup() -> void:
	_start_destroyed_tank_smoke()
	super._show_end_popup()

func _start_destroyed_tank_smoke() -> void:
	if destroyed_tank_index >= 0:
		return
	if tank_health[0] <= 0:
		destroyed_tank_index = 0
	elif tank_health[1] <= 0:
		destroyed_tank_index = 1
	else:
		return
	destroyed_smoke_timer = 0.0
	for i: int in range(7):
		_spawn_destroyed_smoke_puff()

func _update_destroyed_smoke(delta: float) -> void:
	if destroyed_tank_index >= 0:
		destroyed_smoke_timer -= delta
		if destroyed_smoke_timer <= 0.0:
			_spawn_destroyed_smoke_puff()
			destroyed_smoke_timer = DESTROYED_SMOKE_INTERVAL

	if destroyed_smoke_puffs.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for puff: Dictionary in destroyed_smoke_puffs:
		var age: float = float(puff.get("age", 0.0)) + delta
		var life: float = float(puff.get("life", DESTROYED_SMOKE_LIFETIME))
		if age < life:
			var pos: Vector2 = puff.get("pos", Vector2.ZERO)
			var drift: float = float(puff.get("drift", 0.0))
			pos.x += drift * delta
			pos.y -= DESTROYED_SMOKE_RISE_SPEED * delta
			puff["age"] = age
			puff["pos"] = pos
			remaining.append(puff)
	destroyed_smoke_puffs = remaining

func _spawn_destroyed_smoke_puff() -> void:
	if destroyed_tank_index < 0 or destroyed_tank_index >= tank_positions.size():
		return
	var base_pos: Vector2 = tank_positions[destroyed_tank_index]
	var offset: Vector2 = Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-36.0, -18.0))
	destroyed_smoke_puffs.append({
		"pos": base_pos + offset,
		"age": 0.0,
		"life": DESTROYED_SMOKE_LIFETIME,
		"drift": rng.randf_range(-DESTROYED_SMOKE_DRIFT_SPEED, DESTROYED_SMOKE_DRIFT_SPEED)
	})

func _draw() -> void:
	super._draw()
	_draw_destroyed_smoke_puffs()

func _draw_destroyed_smoke_puffs() -> void:
	for puff: Dictionary in destroyed_smoke_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", DESTROYED_SMOKE_LIFETIME))
		var t: float = clampf(age / life, 0.0, 1.0)
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = lerpf(DESTROYED_SMOKE_START_RADIUS, DESTROYED_SMOKE_END_RADIUS, t) * CAMERA_SCALE
		var alpha: float = 0.58 * (1.0 - t)
		draw_circle(_world_to_screen(pos), radius, Color(0.78, 0.80, 0.77, alpha))
