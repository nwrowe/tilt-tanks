extends "res://scripts/core/MainGameSpecialWeaponsFacade.gd"

# Thin runtime hook for tank progression UI/state.
# This intentionally exposes read-only tank summaries first; combat math and
# purchasing/training flows should be integrated in later, smaller passes.

const TANK_PANEL_SIZE: Vector2 = Vector2(330.0, 318.0)
const TANK_PANEL_POS: Vector2 = Vector2(548.0, 58.0)
const TANK_SETUP_BUTTON_POS: Vector2 = Vector2(698.0, 12.0)
const TANK_SETUP_BUTTON_SIZE: Vector2 = Vector2(76.0, 38.0)

var tank_classes: Dictionary = {}
var tank_upgrades: Dictionary = {}
var tank_crew: Dictionary = {}
var player_tank_builds: Array[TankBuildState] = []
var tank_panel: Panel = null
var tank_summary_label: Label = null
var tank_setup_button: Button = null
var tank_panel_player_index: int = 0

func _ready() -> void:
	_initialize_progression_state()
	super._ready()
	_update_tank_setup_button_visibility()

func reset_match() -> void:
	_initialize_player_tank_builds()
	super.reset_match()
	_sync_match_state_tank_builds()
	_update_tank_setup_button_visibility()
	_refresh_tank_summary_panel()

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
	_update_tank_setup_button_visibility()

func _show_game_ui() -> void:
	super._show_game_ui()
	_update_tank_setup_button_visibility()

func _return_to_main_menu() -> void:
	_close_tank_summary_panel()
	super._return_to_main_menu()
	_update_tank_setup_button_visibility()

func _on_campaign_pressed() -> void:
	_show_campaign_hub_menu()

func _show_campaign_hub_menu() -> void:
	menu_state = MENU_STATE_SINGLE_PLAYER
	single_player_mode = true
	_hide_game_ui()
	_close_tank_summary_panel()
	_clear_menu_controls()
	_add_text_label("Campaign", Vector2(0.5, 0.31), Vector2(460, 58), 32)
	_add_multiline_menu_label(
		"Choose a campaign level, then visit the garage between levels to upgrade your tank.",
		Vector2(0.5, 0.40),
		Vector2(560, 58),
		18
	)
	_add_plain_menu_button("Level 1: Training Grounds", Vector2(0.35, 0.57), Vector2(285, 58), func() -> void:
		_start_campaign_level(1)
	)
	_add_disabled_menu_button("Level 2: Ridge Ambush  (Locked)", Vector2(0.35, 0.68), Vector2(285, 58))
	_add_plain_menu_button("Tank Garage", Vector2(0.66, 0.57), Vector2(250, 58), _show_tank_garage_menu)
	_add_plain_menu_button("Back", Vector2(0.5, 0.82), Vector2(210, 58), _show_single_player_menu)
	queue_redraw()

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

func _toggle_menu() -> void:
	if tank_panel != null and tank_panel.visible:
		tank_panel.visible = false
	super._toggle_menu()
	overlay_open = _any_overlay_open()

func _toggle_weapon_menu() -> void:
	if tank_panel != null and tank_panel.visible:
		tank_panel.visible = false
	super._toggle_weapon_menu()
	overlay_open = _any_overlay_open()

func _show_end_popup() -> void:
	_close_tank_summary_panel()
	super._show_end_popup()
	_update_tank_setup_button_visibility()

func _handle_outside_menu_tap(event: InputEvent) -> bool:
	var handled: bool = super._handle_outside_menu_tap(event)
	if handled:
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
		return true
	return false

func _any_overlay_open() -> bool:
	return (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible) or (tank_panel != null and tank_panel.visible)
