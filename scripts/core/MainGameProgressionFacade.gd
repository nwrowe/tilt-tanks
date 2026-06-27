extends "res://scripts/core/MainGameSpecialWeaponsFacade.gd"

# Thin runtime hook for tank progression UI/state.
# This intentionally exposes read-only tank summaries first; combat math and
# purchasing/training flows should be integrated in later, smaller passes.

const TANK_PANEL_SIZE: Vector2 = Vector2(330.0, 318.0)
const TANK_PANEL_POS: Vector2 = Vector2(548.0, 58.0)
const TANK_SETUP_BUTTON_POS: Vector2 = Vector2(698.0, 12.0)
const TANK_SETUP_BUTTON_SIZE: Vector2 = Vector2(76.0, 38.0)
const CAMPAIGN_MAP_BG_PATH: String = "res://assets/menu/campaign_map_background_wide.png"
const CAMPAIGN_MAP_SIZE: Vector2 = Vector2(2200.0, 540.0)
const HOTSEAT_START_TURN_BUTTON_SIZE: Vector2 = Vector2(300.0, 68.0)
const HOTSEAT_START_TURN_BUTTON_POS: Vector2 = Vector2(300.0, 238.0)

var tank_classes: Dictionary = {}
var tank_upgrades: Dictionary = {}
var tank_crew: Dictionary = {}
var player_tank_builds: Array[TankBuildState] = []
var tank_panel: Panel = null
var tank_summary_label: Label = null
var tank_setup_button: Button = null
var tank_panel_player_index: int = 0
var campaign_map_scroll: ScrollContainer = null
var campaign_map_dragging: bool = false
var hotseat_turn_start_pending: bool = false
var hotseat_start_turn_button: Button = null

func _ready() -> void:
	_initialize_progression_state()
	super._ready()
	_update_tank_setup_button_visibility()

func reset_match() -> void:
	hotseat_turn_start_pending = false
	_initialize_player_tank_builds()
	super.reset_match()
	_sync_match_state_tank_builds()
	_update_tank_setup_button_visibility()
	_refresh_tank_summary_panel()
	_arm_hotseat_turn_start_prompt()

func _initialize_progression_state() -> void:
	if tank_classes.is_empty():
		tank_classes = TankProgressionRegistry.build_default_tank_classes()
	if tank_upgrades.is_empty():
		tank_upgrades = TankProgressionRegistry.build_default_upgrades()
	if tank_crew.is_empty():
		tank_crew = TankProgressionRegistry.build_default_crew()
	_initialize_player_tank_builds()

func _initialize_player_tank_builds() -> void:
	player_tank_builds = [
		TankProgressionRegistry.default_player_build(0),
		TankProgressionRegistry.default_player_build(1)
	]
	_sync_match_state_tank_builds()

func _sync_match_state_tank_builds() -> void:
	if match_state == null:
		return
	for i: int in range(player_tank_builds.size()):
		match_state.set_tank_build_for_player(i, player_tank_builds[i])

func _build_overlay_ui() -> void:
	super._build_overlay_ui()
	_build_tank_setup_button()
	_build_tank_summary_panel()
	_build_hotseat_start_turn_button()
	_update_tank_setup_button_visibility()

func _show_game_ui() -> void:
	super._show_game_ui()
	_update_tank_setup_button_visibility()

func _return_to_main_menu() -> void:
	hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()
	_close_tank_summary_panel()
	super._return_to_main_menu()
	_update_tank_setup_button_visibility()
	_update_hotseat_start_turn_button()

func _clear_menu_controls() -> void:
	campaign_map_scroll = null
	campaign_map_dragging = false
	super._clear_menu_controls()

func _advance_turn() -> void:
	super._advance_turn()
	_arm_hotseat_turn_start_prompt()

func _process(delta: float) -> void:
	if _should_hold_for_hotseat_turn_start():
		_process_hotseat_turn_start_wait(delta)
		return

	super._process(delta)
	_update_hotseat_start_turn_button()

func _hotseat_can_begin_charge() -> bool:
	if _is_hotseat_turn_start_prompt_active():
		return false
	return super._hotseat_can_begin_charge()

func _update_ui() -> void:
	super._update_ui()
	if _is_hotseat_turn_start_prompt_active() and not game_over:
		status_label.text = "Pass phone to Player %d" % (current_player + 1)
		power_label.text = "Press START"

func _on_campaign_pressed() -> void:
	_show_campaign_hub_menu()

func _show_campaign_hub_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_close_tank_summary_panel()
	_clear_menu_controls()
	_build_campaign_map_scroll()
	_add_text_label("Campaign", Vector2(0.5, 0.08), Vector2(460, 48), 32)
	_add_multiline_menu_label("Swipe horizontally to follow the campaign route. Tap a level node to launch it.", Vector2(0.5, 0.155), Vector2(680, 40), 17)
	_add_plain_menu_button("Tank Garage", Vector2(0.78, 0.91), Vector2(220, 52), _show_tank_garage_menu)
	_add_plain_menu_button("Back", Vector2(0.22, 0.91), Vector2(180, 52), _show_single_player_menu)
	queue_redraw()

func _build_campaign_map_scroll() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = viewport_size
	scroll.custom_minimum_size = viewport_size
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.gui_input.connect(_on_campaign_map_scroll_gui_input)
	campaign_map_scroll = scroll
	menu_layer.add_child(scroll)
	menu_buttons.append(scroll)

	var map_root: Control = Control.new()
	map_root.custom_minimum_size = CAMPAIGN_MAP_SIZE
	map_root.size = CAMPAIGN_MAP_SIZE
	map_root.mouse_filter = Control.MOUSE_FILTER_PASS
	map_root.gui_input.connect(_on_campaign_map_scroll_gui_input)
	scroll.add_child(map_root)

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

func _on_campaign_map_scroll_gui_input(event: InputEvent) -> void:
	if campaign_map_scroll == null:
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_scroll_campaign_map_by(-drag.relative.x)
		campaign_map_scroll.accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		campaign_map_dragging = touch.pressed
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			campaign_map_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_campaign_map_by(-90.0)
			campaign_map_scroll.accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_campaign_map_by(90.0)
			campaign_map_scroll.accept_event()
	elif event is InputEventMouseMotion and campaign_map_dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_scroll_campaign_map_by(-motion.relative.x)
			campaign_map_scroll.accept_event()
		else:
			campaign_map_dragging = false

func _scroll_campaign_map_by(delta_x: float) -> void:
	if campaign_map_scroll == null:
		return
	var max_scroll: int = maxi(0, int(CAMPAIGN_MAP_SIZE.x - campaign_map_scroll.size.x))
	campaign_map_scroll.scroll_horizontal = clampi(campaign_map_scroll.scroll_horizontal + int(round(delta_x)), 0, max_scroll)

func _add_campaign_map_background(parent: Control) -> void:
	if ResourceLoader.exists(CAMPAIGN_MAP_BG_PATH):
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.texture = load(CAMPAIGN_MAP_BG_PATH) as Texture2D
		texture_rect.position = Vector2.ZERO
		texture_rect.size = CAMPAIGN_MAP_SIZE
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
	band.size = Vector2(CAMPAIGN_MAP_SIZE.x, height)
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
			_start_campaign_level(level_index)
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

func _show_tank_garage_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_close_tank_summary_panel()
	_clear_menu_controls()
	_add_text_label("Tank Garage", Vector2(0.5, 0.25), Vector2(520, 58), 32)
	_add_multiline_menu_label(_garage_summary_text(0), Vector2(0.33, 0.55), Vector2(360, 260), 17)
	_add_text_label("Available Upgrades", Vector2(0.70, 0.40), Vector2(310, 36), 22)
	_add_upgrade_preview_buttons()
	_add_plain_menu_button("Back", Vector2(0.5, 0.86), Vector2(210, 58), _show_campaign_hub_menu)
	queue_redraw()

func _start_campaign_level(level_index: int) -> void:
	_select_campaign_mode()
	_start_game(true)

func _garage_summary_text(player_index: int) -> String:
	var build: TankBuildState = _tank_build_for_player(player_index)
	var tank_class: TankClassDefinition = TankProgressionRegistry.get_tank_class(tank_classes, build.tank_class_id)
	var stats: Dictionary = TankProgressionRegistry.effective_stats(build, tank_classes, tank_upgrades, tank_crew)
	var lines: Array[String] = []
	lines.append("Player %d Tank" % (player_index + 1))
	lines.append("Class: %s  (Tier %d)" % [tank_class.display_name, tank_class.tier])
	lines.append("Credits: %d" % build.credits)
	lines.append("")
	lines.append("Health: %.0f" % float(stats.get(TankProgressionRegistry.STAT_MAX_HEALTH, 100.0)))
	lines.append("Armor: %.0f%%" % (100.0 * float(stats.get(TankProgressionRegistry.STAT_DAMAGE_RESIST, 0.0))))
	lines.append("Fire Power: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_FIRE_POWER, 1.0)))
	lines.append("Aim Stability: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_AIM_STABILITY, 1.0)))
	lines.append("Reload: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_RELOAD_SPEED, 1.0)))
	lines.append("Engine: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_ENGINE_POWER, 1.0)))
	lines.append("Tracks: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_TRACK_GRIP, 1.0)))
	lines.append("")
	lines.append("Installed: %s" % _upgrade_summary(build))
	return "\n".join(lines)

func _add_upgrade_preview_buttons() -> void:
	var upgrade_ids: Array[String] = [
		"stabilized_barrel_mk1",
		"reinforced_armor_mk1",
		"wide_tracks_mk1",
		"engine_tune_mk1"
	]
	var y_anchor: float = 0.49
	for upgrade_id: String in upgrade_ids:
		var upgrade: TankUpgradeDefinition = TankProgressionRegistry.get_upgrade(tank_upgrades, upgrade_id)
		if upgrade == null:
			continue
		_add_disabled_menu_button(
			"%s  -  %d cr" % [upgrade.display_name, upgrade.purchase_cost],
			Vector2(0.70, y_anchor),
			Vector2(320, 44)
		)
		y_anchor += 0.085
	_add_multiline_menu_label("Purchase flow coming next; this screen establishes the garage location and upgrade list.", Vector2(0.70, 0.78), Vector2(340, 64), 15)

func _add_plain_menu_button(text: String, anchor: Vector2, size: Vector2, callback: Callable) -> Button:
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

func _add_disabled_menu_button(text: String, anchor: Vector2, size: Vector2) -> Button:
	var button: Button = _add_plain_menu_button(text, anchor, size, func() -> void:
		return
	)
	button.disabled = true
	button.modulate = Color(1.0, 1.0, 1.0, 0.62)
	return button

func _add_multiline_menu_label(text: String, anchor: Vector2, size: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func _build_tank_setup_button() -> void:
	if ui_layer == null or tank_setup_button != null:
		return
	tank_setup_button = MobileControls.make_button("Tank", TANK_SETUP_BUTTON_POS, TANK_SETUP_BUTTON_SIZE, ui_layer)
	tank_setup_button.pressed.connect(_toggle_tank_summary_panel)

func _update_tank_setup_button_visibility() -> void:
	if tank_setup_button != null:
		tank_setup_button.visible = menu_state == MENU_STATE_GAME and not game_over

func _build_tank_summary_panel() -> void:
	if ui_layer == null or tank_panel != null:
		return
	tank_panel = Panel.new()
	tank_panel.visible = false
	tank_panel.position = TANK_PANEL_POS
	tank_panel.size = TANK_PANEL_SIZE
	ui_layer.add_child(tank_panel)

	var title: Label = Label.new()
	title.text = "Tank Setup"
	title.position = Vector2(16.0, 12.0)
	title.size = Vector2(220.0, 24.0)
	tank_panel.add_child(title)

	tank_summary_label = Label.new()
	tank_summary_label.position = Vector2(16.0, 44.0)
	tank_summary_label.size = Vector2(298.0, 210.0)
	tank_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tank_panel.add_child(tank_summary_label)

	var player_toggle_button: Button = MobileControls.make_button("Switch Player", Vector2(16.0, 260.0), Vector2(142.0, 36.0), tank_panel)
	player_toggle_button.pressed.connect(_toggle_tank_summary_player)

	var close_button: Button = MobileControls.make_button("Close", Vector2(172.0, 260.0), Vector2(142.0, 36.0), tank_panel)
	close_button.pressed.connect(_close_tank_summary_panel)

func _toggle_tank_summary_panel() -> void:
	if tank_setup_button != null:
		tank_setup_button.release_focus()
	if tank_panel == null:
		return
	if weapon_menu_open:
		_close_weapon_menu()
	if menu_panel != null and menu_panel.visible:
		menu_panel.visible = false
	tank_panel_player_index = clampi(current_player, 0, 1)
	tank_panel.visible = not tank_panel.visible
	if tank_panel.visible:
		_refresh_tank_summary_panel()
	overlay_open = _any_overlay_open()

func _close_tank_summary_panel() -> void:
	if tank_panel != null:
		tank_panel.visible = false
	overlay_open = _any_overlay_open()

func _toggle_tank_summary_player() -> void:
	tank_panel_player_index = 1 - clampi(tank_panel_player_index, 0, 1)
	_refresh_tank_summary_panel()

func _refresh_tank_summary_panel() -> void:
	if tank_summary_label == null:
		return
	tank_summary_label.text = _tank_summary_text(tank_panel_player_index)

func _tank_summary_text(player_index: int) -> String:
	var build: TankBuildState = _tank_build_for_player(player_index)
	var tank_class: TankClassDefinition = TankProgressionRegistry.get_tank_class(tank_classes, build.tank_class_id)
	var stats: Dictionary = TankProgressionRegistry.effective_stats(build, tank_classes, tank_upgrades, tank_crew)
	var lines: Array[String] = []
	lines.append("Player %d" % (player_index + 1))
	lines.append("Class: %s  (Tier %d)" % [tank_class.display_name, tank_class.tier])
	lines.append("Credits: %d" % build.credits)
	lines.append("")
	lines.append("Health: %.0f" % float(stats.get(TankProgressionRegistry.STAT_MAX_HEALTH, 100.0)))
	lines.append("Armor: %.0f%%" % (100.0 * float(stats.get(TankProgressionRegistry.STAT_DAMAGE_RESIST, 0.0))))
	lines.append("Fire Power: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_FIRE_POWER, 1.0)))
	lines.append("Aim Stability: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_AIM_STABILITY, 1.0)))
	lines.append("Reload: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_RELOAD_SPEED, 1.0)))
	lines.append("Engine: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_ENGINE_POWER, 1.0)))
	lines.append("Tracks: %.2fx" % float(stats.get(TankProgressionRegistry.STAT_TRACK_GRIP, 1.0)))
	lines.append("")
	lines.append("Crew: %s" % _crew_summary(build))
	lines.append("Upgrades: %s" % _upgrade_summary(build))
	lines.append("")
	lines.append("Read-only for now; purchase/training flow comes next.")
	return "\n".join(lines)

func _tank_build_for_player(player_index: int) -> TankBuildState:
	if player_index >= 0 and player_index < player_tank_builds.size():
		return player_tank_builds[player_index]
	return TankProgressionRegistry.default_player_build(player_index)

func _crew_summary(build: TankBuildState) -> String:
	if build.assigned_crew_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for crew_id: String in build.assigned_crew_ids:
		var member: CrewMemberDefinition = TankProgressionRegistry.get_crew_member(tank_crew, crew_id)
		if member != null:
			names.append("%s L%d" % [member.display_name, member.level])
	return ", ".join(names) if not names.is_empty() else "None"

func _upgrade_summary(build: TankBuildState) -> String:
	if build.installed_upgrade_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for upgrade_id: String in build.installed_upgrade_ids:
		var upgrade: TankUpgradeDefinition = TankProgressionRegistry.get_upgrade(tank_upgrades, upgrade_id)
		if upgrade != null:
			names.append(upgrade.display_name)
	return ", ".join(names) if not names.is_empty() else "None"

func _build_hotseat_start_turn_button() -> void:
	if hotseat_start_turn_button != null:
		return
	hotseat_start_turn_button = MobileControls.make_button(
		"Start Turn",
		HOTSEAT_START_TURN_BUTTON_POS,
		HOTSEAT_START_TURN_BUTTON_SIZE,
		ui_layer
	)
	hotseat_start_turn_button.visible = false
	hotseat_start_turn_button.pressed.connect(_on_hotseat_start_turn_pressed)

func _arm_hotseat_turn_start_prompt() -> void:
	if _is_hotseat_turn_start_prompt_mode() and not game_over:
		hotseat_turn_start_pending = true
		turn_timer = TURN_TIME_LIMIT
		_reset_hotseat_charge()
		_clear_hotseat_handoff_input_state()
	else:
		hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()

func _on_hotseat_start_turn_pressed() -> void:
	if hotseat_start_turn_button != null:
		hotseat_start_turn_button.release_focus()
	if not _is_hotseat_turn_start_prompt_active():
		hotseat_turn_start_pending = false
		_update_hotseat_start_turn_button()
		return

	hotseat_turn_start_pending = false
	turn_timer = TURN_TIME_LIMIT
	if match_state != null:
		match_state.turn_timer = turn_timer
	_reset_hotseat_charge()
	_clear_hotseat_handoff_input_state()
	_update_hotseat_start_turn_button()
	queue_redraw()

func _process_hotseat_turn_start_wait(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()
		return

	_clear_hotseat_handoff_input_state()
	_update_camera(delta)
	_update_ui()
	_update_muzzle_effects(delta)
	_update_hotseat_start_turn_button()
	queue_redraw()

func _should_hold_for_hotseat_turn_start() -> bool:
	return (
		_is_hotseat_turn_start_prompt_active()
		and not overlay_open
		and not projectile_active
		and turn_projectiles.is_empty()
		and not machine_gun_active
		and not machine_gun_turn_waiting_for_shells
		and not pending_advance_after_explosion_hold
		and explosion_timer <= 0.0
		and cluster_camera_hold_timer <= 0.0
	)

func _is_hotseat_turn_start_prompt_active() -> bool:
	return hotseat_turn_start_pending and _is_hotseat_turn_start_prompt_mode() and not game_over

func _is_hotseat_turn_start_prompt_mode() -> bool:
	return menu_state == MENU_STATE_GAME and game_mode == GAME_MODE_HOTSEAT and not single_player_mode

func _clear_hotseat_handoff_input_state() -> void:
	mobile_left_pressed = false
	mobile_right_pressed = false
	hotseat_fire_button_held = false
	hotseat_keyboard_fire_held = false
	if mobile_left_button != null:
		mobile_left_button.release_focus()
	if mobile_right_button != null:
		mobile_right_button.release_focus()
	if mobile_fire_button != null:
		mobile_fire_button.release_focus()

func _update_hotseat_start_turn_button() -> void:
	if hotseat_start_turn_button == null:
		return
	var should_show: bool = _is_hotseat_turn_start_prompt_active() and not overlay_open
	hotseat_start_turn_button.visible = should_show
	hotseat_start_turn_button.disabled = not should_show
	if should_show:
		hotseat_start_turn_button.text = "Start P%d Turn" % (current_player + 1)

func _toggle_menu() -> void:
	if tank_panel != null and tank_panel.visible:
		tank_panel.visible = false
	super._toggle_menu()
	overlay_open = _any_overlay_open()
	_update_hotseat_start_turn_button()

func _toggle_weapon_menu() -> void:
	if tank_panel != null and tank_panel.visible:
		tank_panel.visible = false
	super._toggle_weapon_menu()
	overlay_open = _any_overlay_open()
	_update_hotseat_start_turn_button()

func _show_end_popup() -> void:
	_close_tank_summary_panel()
	hotseat_turn_start_pending = false
	_update_hotseat_start_turn_button()
	super._show_end_popup()
	_update_tank_setup_button_visibility()

func _handle_outside_menu_tap(event: InputEvent) -> bool:
	var handled: bool = super._handle_outside_menu_tap(event)
	if handled:
		_update_hotseat_start_turn_button()
		return true
	if menu_state != MENU_STATE_GAME or tank_panel == null or not tank_panel.visible:
		return false
	var click_pos: Vector2 = Vector2.INF
	var is_press: bool = false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		is_press = touch.pressed
		click_pos = touch.position
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		is_press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		click_pos = mb.position
	if not is_press:
		return false
	if not _point_inside_control(tank_panel, click_pos) and not _point_inside_control(tank_setup_button, click_pos):
		tank_panel.visible = false
		overlay_open = _any_overlay_open()
		_update_hotseat_start_turn_button()
		return true
	return false

func _any_overlay_open() -> bool:
	return (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible) or (tank_panel != null and tank_panel.visible)
