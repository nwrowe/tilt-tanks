extends "res://scripts/core/MainGameSpecialWeaponsFacade.gd"

# Thin runtime hook for tank progression UI/state.
# This intentionally exposes read-only tank summaries first; combat math and
# purchasing/training flows should be integrated in later, smaller passes.

const TANK_PANEL_SIZE: Vector2 = Vector2(330.0, 318.0)
const TANK_PANEL_POS: Vector2 = Vector2(548.0, 58.0)
const TANK_LINE_HEIGHT: float = 22.0

var tank_classes: Dictionary = {}
var tank_upgrades: Dictionary = {}
var tank_crew: Dictionary = {}
var player_tank_builds: Array[TankBuildState] = []
var tank_panel: Panel = null
var tank_summary_label: Label = null
var tank_panel_player_index: int = 0

func _ready() -> void:
	_initialize_progression_state()
	super._ready()
	_ensure_tank_summary_button()

func reset_match() -> void:
	_initialize_player_tank_builds()
	super.reset_match()
	_sync_match_state_tank_builds()
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
	_build_tank_summary_panel()

func _add_true_quit_button() -> void:
	super._add_true_quit_button()
	_ensure_tank_summary_button()

func _ensure_tank_summary_button() -> void:
	if menu_panel == null:
		return
	for child: Node in menu_panel.get_children():
		if child is Button and (child as Button).text == "Tank Setup":
			return
	var tank_button: Button = MobileControls.make_button("Tank Setup", Vector2(MENU_PANEL_BUTTON_X, MENU_PANEL_START_Y), Vector2(MENU_PANEL_BUTTON_W, MENU_PANEL_BUTTON_H), menu_panel)
	tank_button.pressed.connect(_toggle_tank_summary_panel)
	_relayout_three_line_menu()

func _relayout_three_line_menu() -> void:
	if menu_panel == null:
		return
	var buttons_by_label: Dictionary = {}
	for child: Node in menu_panel.get_children():
		if child is Button:
			var button: Button = child as Button
			if button.text in ["Tank Setup", "Rematch", "Main Menu", "Quit"] and not buttons_by_label.has(button.text):
				buttons_by_label[button.text] = button
	var desired_order: Array[String] = ["Tank Setup", "Rematch", "Main Menu", "Quit"]
	var y: float = MENU_PANEL_START_Y
	for label: String in desired_order:
		if buttons_by_label.has(label):
			var button: Button = buttons_by_label[label] as Button
			button.position = Vector2(MENU_PANEL_BUTTON_X, y)
			button.size = Vector2(MENU_PANEL_BUTTON_W, MENU_PANEL_BUTTON_H)
			y += MENU_PANEL_GAP_Y
	menu_panel.size = Vector2(230.0, y + 12.0)

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
	if tank_panel == null:
		return
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
	if not _point_inside_control(tank_panel, click_pos) and not _point_inside_control(menu_button, click_pos):
		tank_panel.visible = false
		overlay_open = _any_overlay_open()
		return true
	return false

func _any_overlay_open() -> bool:
	return (menu_panel != null and menu_panel.visible) or (weapon_panel != null and weapon_panel.visible) or (end_panel != null and end_panel.visible) or (tank_panel != null and tank_panel.visible)
