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
