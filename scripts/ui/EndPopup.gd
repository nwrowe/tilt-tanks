extends RefCounted
class_name EndPopup

# Construction-only helper for the end-of-match popup.
#
# This helper owns only node creation and default geometry. The active game
# script still owns winner text, visibility, rematch behavior, and quit/menu
# behavior.

const PANEL_POS: Vector2 = Vector2(270, 165)
const PANEL_SIZE: Vector2 = Vector2(360, 190)

const LABEL_POS: Vector2 = Vector2(18, 20)
const LABEL_SIZE: Vector2 = Vector2(324, 54)
const DEFAULT_LABEL_TEXT: String = "Player wins!"

const REMATCH_TEXT: String = "Rematch"
const REMATCH_POS: Vector2 = Vector2(36, 96)
const REMATCH_SIZE: Vector2 = Vector2(130, 46)

const QUIT_TEXT: String = "Quit"
const QUIT_POS: Vector2 = Vector2(194, 96)
const QUIT_SIZE: Vector2 = Vector2(130, 46)

static func make_panel(ui_layer: CanvasLayer) -> Panel:
	var panel: Panel = Panel.new()
	panel.visible = false
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	if ui_layer != null:
		ui_layer.add_child(panel)
	return panel

static func make_label(panel: Panel) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = LABEL_POS
	label.size = LABEL_SIZE
	label.text = DEFAULT_LABEL_TEXT
	if panel != null:
		panel.add_child(label)
	return label

static func make_rematch_button(panel: Panel) -> Button:
	return MobileControls.make_button(REMATCH_TEXT, REMATCH_POS, REMATCH_SIZE, panel)

static func make_quit_button(panel: Panel) -> Button:
	return MobileControls.make_button(QUIT_TEXT, QUIT_POS, QUIT_SIZE, panel)
