extends RefCounted
class_name MobileControls

# Shared helpers for the prototype mobile/menu buttons.
#
# Keep these values behavior-identical to the legacy _style_mobile_button()
# and _make_button() implementations while construction is migrated out of the
# MainHybridModes inheritance chain.

const MENU_BUTTON_TEXT: String = "☰"
const MENU_BUTTON_POS: Vector2 = Vector2(842, 12)
const MENU_BUTTON_SIZE: Vector2 = Vector2(44, 38)

const LEFT_BUTTON_TEXT: String = "◀"
const LEFT_BUTTON_POS: Vector2 = Vector2(18, 448)
const LEFT_BUTTON_SIZE: Vector2 = Vector2(78, 72)

const RIGHT_BUTTON_TEXT: String = "▶"
const RIGHT_BUTTON_POS: Vector2 = Vector2(108, 448)
const RIGHT_BUTTON_SIZE: Vector2 = Vector2(78, 72)

const FIRE_BUTTON_TEXT: String = "FIRE"
const FIRE_BUTTON_POS: Vector2 = Vector2(382, 462)
const FIRE_BUTTON_SIZE: Vector2 = Vector2(136, 58)

static func style_mobile_button(button: Button) -> void:
	if button == null:
		return

	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = false

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.17, 0.20, 0.82)
	normal.border_color = Color(0.85, 0.90, 1.0, 0.42)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.46, 0.58, 0.92)

	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)

	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, Color.WHITE)

static func make_button(text: String, pos: Vector2, size: Vector2, parent: Node) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.size = size
	style_mobile_button(button)
	if parent != null:
		parent.add_child(button)
	return button

static func make_menu_button(parent: Node) -> Button:
	return make_button(MENU_BUTTON_TEXT, MENU_BUTTON_POS, MENU_BUTTON_SIZE, parent)

static func make_left_button(parent: Node) -> Button:
	return make_button(LEFT_BUTTON_TEXT, LEFT_BUTTON_POS, LEFT_BUTTON_SIZE, parent)

static func make_right_button(parent: Node) -> Button:
	return make_button(RIGHT_BUTTON_TEXT, RIGHT_BUTTON_POS, RIGHT_BUTTON_SIZE, parent)

static func make_fire_button(parent: Node) -> Button:
	return make_button(FIRE_BUTTON_TEXT, FIRE_BUTTON_POS, FIRE_BUTTON_SIZE, parent)

## Active weapon runtime layout. This is distinct from the legacy
## WorldRuntimeBridge fallback FIRE position (430, 448).
static func layout_weapon_runtime_actions(
	left_button: Button, right_button: Button, fire_button: Button,
	weapon_button: Button, weapon_pos: Vector2, weapon_size: Vector2
) -> void:
	if left_button != null:
		left_button.position = Vector2(16, 430)
		left_button.size = Vector2(92, 88)
	if right_button != null:
		right_button.position = Vector2(122, 430)
		right_button.size = Vector2(92, 88)
	if fire_button != null:
		fire_button.position = Vector2(696, 448)
		fire_button.size = Vector2(188, 70)
	if weapon_button != null:
		weapon_button.position = weapon_pos
		weapon_button.size = weapon_size
