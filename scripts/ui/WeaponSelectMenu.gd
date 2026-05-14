extends RefCounted
class_name WeaponSelectMenu

# Construction-only helper for the weapon selector UI.
#
# This intentionally does not own gameplay state or signal behavior yet. The
# active game script still decides which weapon is selected and how the menu
# closes. Keeping this helper construction-only makes the migration low risk.

const BUTTON_POS: Vector2 = Vector2(786, 12)
const BUTTON_SIZE: Vector2 = Vector2(44, 38)
const BUTTON_TEXT: String = "B"

const PANEL_POS: Vector2 = Vector2(275, 126)
const PANEL_SIZE: Vector2 = Vector2(350, 286)

const TITLE_POS: Vector2 = Vector2(18, 16)
const TITLE_SIZE: Vector2 = Vector2(314, 32)
const TITLE_FONT_SIZE: int = 24

const OPTION_SIZE: Vector2 = Vector2(266, 40)
const BACK_SIZE: Vector2 = Vector2(178, 38)

static func make_weapon_button(ui_layer: CanvasLayer) -> Button:
	return MobileControls.make_button(BUTTON_TEXT, BUTTON_POS, BUTTON_SIZE, ui_layer)

static func make_panel(ui_layer: CanvasLayer) -> Panel:
	var panel: Panel = Panel.new()
	panel.visible = false
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	if ui_layer != null:
		ui_layer.add_child(panel)
	return panel

static func add_title(panel: Panel) -> Label:
	var title: Label = Label.new()
	title.text = "Select Weapon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = TITLE_POS
	title.size = TITLE_SIZE
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	if panel != null:
		panel.add_child(title)
	return title

static func make_option_button(panel: Panel, text: String, pos: Vector2) -> Button:
	return MobileControls.make_button(text, pos, OPTION_SIZE, panel)

static func make_back_button(panel: Panel, pos: Vector2) -> Button:
	return MobileControls.make_button("Back", pos, BACK_SIZE, panel)
