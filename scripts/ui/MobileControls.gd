extends RefCounted
class_name MobileControls

# Shared helpers for the prototype mobile/menu buttons.
#
# Keep these values behavior-identical to the legacy _style_mobile_button()
# and _make_button() implementations while construction is migrated out of the
# MainHybridModes inheritance chain.

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
