extends RefCounted
class_name UIManager

static func point_inside_control(control: Control, point: Vector2) -> bool:
	if control == null or not control.visible:
		return false
	var rect: Rect2 = Rect2(control.global_position, control.size)
	return rect.has_point(point)

static func set_visible(control: Control, visible: bool) -> void:
	if control != null:
		control.visible = visible

static func style_button(button: Button, bg: Color, border: Color, font: Color, radius: int = 14, border_width: int = 2) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(border_width)
	normal.set_corner_radius_all(radius)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.12)
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, font)

static func relabel_buttons_recursive(node: Node, old_text: String, new_text: String) -> void:
	if node is Button:
		var button: Button = node as Button
		if button.text == old_text:
			button.text = new_text
	for child: Node in node.get_children():
		relabel_buttons_recursive(child, old_text, new_text)

static func find_buttons_by_text(root: Node, labels: Array[String]) -> Array[Button]:
	var found: Array[Button] = []
	_collect_buttons_by_text(root, labels, found)
	return found

static func _collect_buttons_by_text(node: Node, labels: Array[String], found: Array[Button]) -> void:
	if node is Button:
		var button: Button = node as Button
		if labels.has(button.text):
			found.append(button)
	for child: Node in node.get_children():
		_collect_buttons_by_text(child, labels, found)

static func layout_buttons_by_label(root: Node, order: Array[String], x: float, start_y: float, width: float, height: float, gap_y: float) -> float:
	var buttons: Array[Button] = find_buttons_by_text(root, order)
	var y: float = start_y
	for label: String in order:
		for button: Button in buttons:
			if button.text == label:
				button.position = Vector2(x, y)
				button.size = Vector2(width, height)
				y += gap_y
				break
	return y

static func close_if_outside(panel: Control, toggle_button: Control, click_pos: Vector2) -> bool:
	if panel == null or not panel.visible:
		return false
	if point_inside_control(panel, click_pos):
		return false
	if point_inside_control(toggle_button, click_pos):
		return false
	panel.visible = false
	return true
