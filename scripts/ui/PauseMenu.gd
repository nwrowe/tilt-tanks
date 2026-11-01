extends RefCounted
class_name PauseMenu

# Construction-only helpers for the in-game pause/menu panel.
#
# These helpers do not own menu state or callbacks. The active game script
# still decides what each button does and when panels open or close.

const PANEL_WITH_MAIN_BUTTON_SIZE: Vector2 = Vector2(230, 194)

const MAIN_MENU_TEXT: String = "Main Menu"
const MAIN_MENU_POS: Vector2 = Vector2(16, 138)
const MAIN_MENU_SIZE: Vector2 = Vector2(198, 36)

const QUIT_TEXT: String = "Quit"
const QUIT_POS: Vector2 = Vector2.ZERO
const QUIT_SIZE: Vector2 = Vector2.ZERO

static func make_main_menu_button(menu_panel: Panel) -> Button:
	if menu_panel != null:
		menu_panel.size = PANEL_WITH_MAIN_BUTTON_SIZE
	return MobileControls.make_button(MAIN_MENU_TEXT, MAIN_MENU_POS, MAIN_MENU_SIZE, menu_panel)

static func make_quit_button(menu_panel: Panel) -> Button:
	return MobileControls.make_button(QUIT_TEXT, QUIT_POS, QUIT_SIZE, menu_panel)

# Active three-button pause overlay. This is a view builder only:
# the game remains the owner of panel visibility, callbacks and match state.
const ACTIVE_PANEL_POS: Vector2 = Vector2(640, 58)
const ACTIVE_PANEL_SIZE: Vector2 = Vector2(230, 145)
const ACTIVE_PANEL_BUTTON_X: float = 16.0
const ACTIVE_PANEL_BUTTON_W: float = 198.0
const ACTIVE_PANEL_BUTTON_H: float = 36.0
const ACTIVE_PANEL_START_Y: float = 46.0
const ACTIVE_PANEL_GAP_Y: float = 46.0

static func make_active_panel(ui_layer: CanvasLayer, on_rematch: Callable, on_main_menu: Callable) -> Panel:
	var panel: Panel = Panel.new()
	panel.visible = false
	panel.position = ACTIVE_PANEL_POS
	panel.size = ACTIVE_PANEL_SIZE
	ui_layer.add_child(panel)

	var title: Label = Label.new()
	title.text = "Menu"
	title.position = Vector2(16, 12)
	title.size = Vector2(180, 24)
	panel.add_child(title)

	var rematch: Button = MobileControls.make_button("Rematch", Vector2(16, 46), Vector2(198, 36), panel)
	rematch.pressed.connect(on_rematch)
	var main_menu: Button = MobileControls.make_button("Main Menu", Vector2(16, 92), Vector2(198, 36), panel)
	main_menu.pressed.connect(on_main_menu)
	return panel

static func layout_active_panel(panel: Panel) -> void:
	if panel == null:
		return
	var order: Array[String] = ["Rematch", "Main Menu", "Quit"]
	var y: float = UIManager.layout_buttons_by_label(
		panel, order,
		ACTIVE_PANEL_BUTTON_X, ACTIVE_PANEL_START_Y,
		ACTIVE_PANEL_BUTTON_W, ACTIVE_PANEL_BUTTON_H, ACTIVE_PANEL_GAP_Y
	)
	panel.size = Vector2(230.0, y + 12.0)
