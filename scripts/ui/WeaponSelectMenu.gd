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

const PANEL_POS: Vector2 = Vector2(275, 88)
const PANEL_SIZE: Vector2 = Vector2(350, 392)

const TITLE_POS: Vector2 = Vector2(18, 16)
const TITLE_SIZE: Vector2 = Vector2(314, 32)
const TITLE_FONT_SIZE: int = 24

const SCROLL_POS: Vector2 = Vector2(34, 60)
const SCROLL_SIZE: Vector2 = Vector2(282, 258)
const OPTION_SIZE: Vector2 = Vector2(250, 40)
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

static func make_scroll_area(panel: Panel) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = SCROLL_POS
	scroll.size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	if panel != null:
		panel.add_child(scroll)
	return list

static func make_option_button(panel: Panel, text: String, pos: Vector2) -> Button:
	return MobileControls.make_button(text, pos, OPTION_SIZE, panel)

static func make_list_option_button(list: VBoxContainer, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = OPTION_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if list != null:
		list.add_child(button)
	return button

static func make_back_button(panel: Panel, pos: Vector2) -> Button:
	return MobileControls.make_button("Back", pos, BACK_SIZE, panel)
