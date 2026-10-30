extends RefCounted
class_name TankGarageView

## Read-only garage presentation. The caller owns tank state, navigation, and
## menu cleanup; this builder returns the controls it creates in the menu layer.
const PREVIEW_UPGRADES: Array[String] = [
	"stabilized_barrel_mk1",
	"reinforced_armor_mk1",
	"wide_tracks_mk1",
	"engine_tune_mk1"
]

static func build_ui(
	layer: CanvasLayer,
	viewport_size: Vector2,
	player_index: int,
	build: TankBuildState,
	classes: Dictionary,
	upgrades: Dictionary,
	crew: Dictionary,
	on_back: Callable
) -> Array[Control]:
	var controls: Array[Control] = []
	_add_label(layer, viewport_size, controls, "Tank Garage", Vector2(0.5, 0.25), Vector2(520, 58), 32, false)
	_add_label(layer, viewport_size, controls, summary_text(player_index, build, classes, upgrades, crew), Vector2(0.33, 0.55), Vector2(360, 260), 17, true)
	_add_label(layer, viewport_size, controls, "Available Upgrades", Vector2(0.70, 0.40), Vector2(310, 36), 22, false)

	var y_anchor: float = 0.49
	for upgrade_id: String in PREVIEW_UPGRADES:
		var upgrade: TankUpgradeDefinition = TankProgressionRegistry.get_upgrade(upgrades, upgrade_id)
		if upgrade == null:
			continue
		_add_button(layer, viewport_size, controls,
			"%s  -  %d cr" % [upgrade.display_name, upgrade.purchase_cost],
			Vector2(0.70, y_anchor), Vector2(320, 44), Callable(), true)
		y_anchor += 0.085
	_add_label(layer, viewport_size, controls,
		"Purchase flow coming next; this screen establishes the garage location and upgrade list.",
		Vector2(0.70, 0.78), Vector2(340, 64), 15, true)
	_add_button(layer, viewport_size, controls, "Back", Vector2(0.5, 0.86),
		Vector2(210, 58), on_back, false)
	return controls

static func summary_text(
	player_index: int,
	build: TankBuildState,
	classes: Dictionary,
	upgrades: Dictionary,
	crew: Dictionary
) -> String:
	var tank_class: TankClassDefinition = TankProgressionRegistry.get_tank_class(classes, build.tank_class_id)
	var stats: Dictionary = TankProgressionRegistry.effective_stats(build, classes, upgrades, crew)
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
	lines.append("Installed: %s" % _upgrade_summary(build, upgrades))
	return "\n".join(lines)

static func _upgrade_summary(build: TankBuildState, upgrades: Dictionary) -> String:
	if build.installed_upgrade_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for upgrade_id: String in build.installed_upgrade_ids:
		var upgrade: TankUpgradeDefinition = TankProgressionRegistry.get_upgrade(upgrades, upgrade_id)
		if upgrade != null:
			names.append(upgrade.display_name)
	return ", ".join(names) if not names.is_empty() else "None"

static func _add_label(
	layer: CanvasLayer,
	viewport_size: Vector2,
	controls: Array[Control],
	label_text: String,
	anchor: Vector2,
	label_size: Vector2,
	font_size: int,
	multiline: bool
) -> void:
	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if multiline else VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if multiline else TextServer.AUTOWRAP_OFF
	label.size = label_size
	label.position = _anchored_position(viewport_size, anchor, label_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	controls.append(label)

static func _add_button(
	layer: CanvasLayer,
	viewport_size: Vector2,
	controls: Array[Control],
	button_text: String,
	anchor: Vector2,
	button_size: Vector2,
	on_pressed: Callable,
	is_disabled: bool
) -> void:
	var button: Button = Button.new()
	button.text = button_text
	button.size = button_size
	button.position = _anchored_position(viewport_size, anchor, button_size)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button)
	if not is_disabled and on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	button.disabled = is_disabled
	if is_disabled:
		button.modulate = Color(1.0, 1.0, 1.0, 0.62)
	layer.add_child(button)
	controls.append(button)

static func _anchored_position(viewport_size: Vector2, anchor: Vector2, control_size: Vector2) -> Vector2:
	return Vector2(viewport_size.x * anchor.x - control_size.x * 0.5, viewport_size.y * anchor.y - control_size.y * 0.5)

static func _style_button(button: Button) -> void:
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
