extends "res://scripts/MainHybridModes2.gd"

# Consolidated compatibility layer while flattening the legacy chain.
# MainHybridModes3 steam state/drawing has been folded here while preserving
# the restored realtime hold-to-charge loop.

const WIND_DISPLAY_MAX: float = 10.0
const WIND_METER_MAX_ACCEL: float = MAX_WIND_ACCEL

const STEAM_PUFF_LIFETIME: float = 0.95
const STEAM_PUFF_RISE_SPEED: float = 34.0
const STEAM_PUFF_DRIFT_SPEED: float = 18.0
const STEAM_PUFF_START_RADIUS: float = 4.0
const STEAM_PUFF_END_RADIUS: float = 13.0

var steam_puffs: Array[Dictionary] = []
var steam_spawn_timer: float = 0.0
var movement_was_overheated: bool = false

func _on_mobile_fire_pressed() -> void:
	return

func _setup_realtime_single_player() -> void:
	super._setup_realtime_single_player()
	steam_puffs.clear()
	steam_spawn_timer = 0.0
	movement_was_overheated = false

func reset_match() -> void:
	super.reset_match()
	_randomize_wind()
	steam_puffs.clear()
	steam_spawn_timer = 0.0
	movement_was_overheated = false

func _process_realtime_single_player(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()
		_setup_realtime_single_player()

	if not game_over and not overlay_open:
		current_player = HUMAN_PLAYER_INDEX
		_update_angle_from_input(delta)
		_update_realtime_player_movement(delta)
		_update_realtime_power()
		_update_realtime_cooldowns(delta)
		_update_realtime_fire_charge(delta)
		_update_realtime_ai(delta)

	_update_all_realtime_projectiles(delta)

	if explosion_timer > 0.0:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF

	_update_camera(delta)
	_update_ui()
	_update_steam_puffs(delta)
	queue_redraw()

func _update_realtime_fire_charge(delta: float) -> void:
	return

func _update_steam_puffs(delta: float) -> void:
	if steam_puffs.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0)) + delta
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		if age < life:
			var pos: Vector2 = puff.get("pos", Vector2.ZERO)
			var drift: float = float(puff.get("drift", 0.0))
			pos.x += drift * delta
			pos.y -= STEAM_PUFF_RISE_SPEED * delta
			puff["age"] = age
			puff["pos"] = pos
			remaining.append(puff)
	steam_puffs = remaining

func _draw_steam_puffs() -> void:
	for puff: Dictionary in steam_puffs:
		var age: float = float(puff.get("age", 0.0))
		var life: float = float(puff.get("life", STEAM_PUFF_LIFETIME))
		var t: float = clampf(age / life, 0.0, 1.0)
		var pos: Vector2 = puff.get("pos", Vector2.ZERO)
		var radius: float = lerpf(STEAM_PUFF_START_RADIUS, STEAM_PUFF_END_RADIUS, t) * CAMERA_SCALE
		var alpha: float = 0.52 * (1.0 - t)
		draw_circle(_world_to_screen(pos), radius, Color(0.88, 0.90, 0.86, alpha))

func _randomize_wind() -> void:
	var display_wind: float = rng.randf_range(-WIND_DISPLAY_MAX, WIND_DISPLAY_MAX)
	wind = display_wind / WIND_DISPLAY_MAX * WIND_METER_MAX_ACCEL

func _draw_wind_widget() -> void:
	var box: Rect2 = Rect2(Vector2(18, 132), Vector2(178, 42))
	draw_rect(box, Color(0.02, 0.03, 0.04, 0.62), true)
	draw_rect(box, Color(0.85, 0.90, 1.0, 0.30), false, 1.0)

	var meter_left: float = box.position.x + 46.0
	var meter_right: float = box.position.x + box.size.x - 18.0
	var meter_center: float = (meter_left + meter_right) * 0.5
	var meter_y: float = box.position.y + 22.0
	var half_width: float = (meter_right - meter_left) * 0.5
	var display_wind: float = _wind_display_value()
	var strength: float = clampf(absf(display_wind) / WIND_DISPLAY_MAX, 0.0, 1.0)
	var fill_width: float = half_width * strength
	var bar_color: Color = _wind_strength_color(strength)

	draw_line(Vector2(meter_left, meter_y), Vector2(meter_right, meter_y), Color(0.55, 0.65, 0.75, 0.45), 8.0)
	draw_line(Vector2(meter_center, meter_y - 13.0), Vector2(meter_center, meter_y + 13.0), Color.WHITE, 2.0)

	if display_wind >= 0.0:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center + fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center + fill_width + 4.0, meter_y), 1.0, bar_color)
	else:
		draw_line(Vector2(meter_center, meter_y), Vector2(meter_center - fill_width, meter_y), bar_color, 8.0)
		_draw_small_arrow(Vector2(meter_center - fill_width - 4.0, meter_y), -1.0, bar_color)

	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 8.0, box.position.y + 27.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + box.size.x - 48.0, box.position.y + 35.0), "%+.0f" % display_wind, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _wind_display_value() -> float:
	return clampf(wind / WIND_METER_MAX_ACCEL * WIND_DISPLAY_MAX, -WIND_DISPLAY_MAX, WIND_DISPLAY_MAX)

func _wind_strength_color(strength: float) -> Color:
	var s: float = clampf(strength, 0.0, 1.0)
	if s < 0.55:
		return Color(0.35, 0.95, 0.35, 0.92)
	if s < 0.82:
		var t: float = (s - 0.55) / 0.27
		return Color(lerpf(0.35, 1.0, t), 0.95, lerpf(0.35, 0.08, t), 0.92)
	var t2: float = (s - 0.82) / 0.18
	return Color(1.0, lerpf(0.95, 0.12, t2), 0.08, 0.92)

func _draw_small_arrow(tip: Vector2, direction: float, color: Color) -> void:
	var d: float = signf(direction)
	if d == 0.0:
		return
	var p1: Vector2 = tip
	var p2: Vector2 = tip + Vector2(-8.0 * d, -6.0)
	var p3: Vector2 = tip + Vector2(-8.0 * d, 6.0)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), color)
