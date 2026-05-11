extends Node2D

@onready var terrain: Line2D = $Terrain
@onready var status_label: Label = $UI/Panel/StatusLabel
@onready var angle_label: Label = $UI/Panel/AngleLabel
@onready var power_label: Label = $UI/Panel/PowerLabel
@onready var power_slider: HSlider = $UI/Panel/PowerSlider
@onready var fire_button: Button = $UI/Panel/FireButton
@onready var reset_button: Button = $UI/Panel/ResetButton

const SCREEN_SIZE: Vector2 = Vector2(900, 540)
const GROUND_Y: float = 460.0
const TERRAIN_STEP: float = 10.0
const TERRAIN_MIN_Y: float = 315.0
const TERRAIN_MAX_Y: float = 485.0
const TANK_RADIUS: float = 16.0
const CANNON_LENGTH: float = 46.0
const PROJECTILE_RADIUS: float = 5.0
const EXPLOSION_RADIUS: float = 58.0
const DIRECT_HIT_RADIUS: float = 24.0
const MAX_DAMAGE: int = 100
const CRATER_RADIUS: float = 54.0
const CRATER_DEPTH: float = 46.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var terrain_points: Array[Vector2] = []
var tank_positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var tank_health: Array[int] = [100, 100]

var current_player: int = 0
var angle_deg: float = 45.0
var power: float = 500.0
var gravity: float = 520.0
var wind: float = 0.0

var projectile_active: bool = false
var projectile_pos: Vector2 = Vector2.ZERO
var projectile_vel: Vector2 = Vector2.ZERO
var explosion_pos: Vector2 = Vector2.INF
var explosion_timer: float = 0.0
var game_over: bool = false

func _ready() -> void:
	rng.randomize()
	fire_button.pressed.connect(_on_fire_pressed)
	reset_button.pressed.connect(reset_match)
	reset_match()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_match()

	if not projectile_active and not game_over:
		_update_angle_from_input(delta)
		power = float(power_slider.value)

	if projectile_active:
		_update_projectile(delta)

	if explosion_timer > 0.0:
		explosion_timer -= delta
		if explosion_timer <= 0.0:
			explosion_pos = Vector2.INF

	_update_ui()
	queue_redraw()

func _generate_random_terrain() -> void:
	terrain_points.clear()

	var control_spacing: float = 90.0
	var control_points: Array[Vector2] = []
	var control_count: int = int(ceil(SCREEN_SIZE.x / control_spacing)) + 2

	for i: int in range(control_count):
		var x: float = float(i) * control_spacing
		var y: float = rng.randf_range(TERRAIN_MIN_Y, TERRAIN_MAX_Y)

		# Keep the tank spawn edges somewhat playable.
		if x < 180.0 or x > SCREEN_SIZE.x - 180.0:
			y = rng.randf_range(390.0, 455.0)

		control_points.append(Vector2(x, y))

	var point_count: int = int(SCREEN_SIZE.x / TERRAIN_STEP) + 1
	for i: int in range(point_count):
		var x: float = float(i) * TERRAIN_STEP
		var control_index: int = mini(int(floor(x / control_spacing)), control_points.size() - 2)
		var left: Vector2 = control_points[control_index]
		var right: Vector2 = control_points[control_index + 1]
		var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		var y: float = lerpf(left.y, right.y, smooth_t)
		terrain_points.append(Vector2(x, y))

	_flatten_spawn_area(120.0, 42.0)
	_flatten_spawn_area(780.0, 42.0)
	_refresh_terrain_line()
	_place_tanks_on_terrain()

func _flatten_spawn_area(center_x: float, half_width: float) -> void:
	var y_sum: float = 0.0
	var count: int = 0

	for point: Vector2 in terrain_points:
		if absf(point.x - center_x) <= half_width:
			y_sum += point.y
			count += 1

	if count <= 0:
		return

	var flat_y: float = y_sum / float(count)
	for i: int in range(terrain_points.size()):
		var point: Vector2 = terrain_points[i]
		var dist: float = absf(point.x - center_x)
		if dist <= half_width:
			point.y = flat_y
		elif dist <= half_width + 35.0:
			var blend: float = (dist - half_width) / 35.0
			point.y = lerpf(flat_y, point.y, blend)
		terrain_points[i] = point

func _refresh_terrain_line() -> void:
	terrain.clear_points()
	for point: Vector2 in terrain_points:
		terrain.add_point(point)

func _place_tanks_on_terrain() -> void:
	tank_positions[0] = Vector2(120.0, _ground_y_at_x(120.0) - TANK_RADIUS)
	tank_positions[1] = Vector2(780.0, _ground_y_at_x(780.0) - TANK_RADIUS)

func _ground_y_at_x(x: float) -> float:
	if terrain_points.is_empty():
		return GROUND_Y

	if x <= terrain_points[0].x:
		return terrain_points[0].y

	var last_index: int = terrain_points.size() - 1
	if x >= terrain_points[last_index].x:
		return terrain_points[last_index].y

	var index: int = mini(int(floor(x / TERRAIN_STEP)), last_index - 1)
	var left: Vector2 = terrain_points[index]
	var right: Vector2 = terrain_points[index + 1]
	var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
	return lerpf(left.y, right.y, t)

func _update_angle_from_input(delta: float) -> void:
	var gravity_vec: Vector3 = Input.get_gravity()

	# Desktop/editor fallback. Mobile sensors usually return non-zero on device.
	if gravity_vec.length() < 0.01:
		if Input.is_key_pressed(KEY_UP):
			angle_deg += 75.0 * delta
		if Input.is_key_pressed(KEY_DOWN):
			angle_deg -= 75.0 * delta
	else:
		# First-pass tilt mapping. Tune this after testing on actual phones.
		# Depending on device orientation, you may prefer gravity_vec.x instead.
		var tilt: float = clampf(gravity_vec.y / 9.8, -1.0, 1.0)
		angle_deg = lerpf(12.0, 85.0, (tilt + 1.0) * 0.5)

	angle_deg = clampf(angle_deg, 5.0, 88.0)

func _on_fire_pressed() -> void:
	if projectile_active or game_over:
		return

	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var muzzle_offset: Vector2 = Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))

	projectile_pos = tank_positions[current_player] + muzzle_offset
	projectile_vel = Vector2(facing * power * cos(rad), -power * sin(rad))
	projectile_active = true

func _update_projectile(delta: float) -> void:
	projectile_vel.y += gravity * delta
	projectile_vel.x += wind * delta
	projectile_pos += projectile_vel * delta

	var enemy: int = 1 - current_player
	if projectile_pos.distance_to(tank_positions[enemy]) <= TANK_RADIUS + PROJECTILE_RADIUS:
		_explode(projectile_pos)
		return

	var ground_y: float = _ground_y_at_x(projectile_pos.x)
	if projectile_pos.y >= ground_y:
		_explode(Vector2(projectile_pos.x, ground_y))
		return

	if projectile_pos.x < -100.0 or projectile_pos.x > SCREEN_SIZE.x + 100.0 or projectile_pos.y > SCREEN_SIZE.y + 150.0:
		_explode(projectile_pos)

func _explode(pos: Vector2) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = 0.35

	_apply_crater(pos)
	_apply_explosion_damage(pos)
	_place_tanks_on_terrain()

	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
	else:
		current_player = 1 - current_player

func _apply_explosion_damage(pos: Vector2) -> void:
	for player: int in range(2):
		var dist: float = pos.distance_to(tank_positions[player])
		if dist <= DIRECT_HIT_RADIUS:
			tank_health[player] = 0
		elif dist <= EXPLOSION_RADIUS:
			var normalized: float = (dist - DIRECT_HIT_RADIUS) / (EXPLOSION_RADIUS - DIRECT_HIT_RADIUS)
			var damage_float: float = float(MAX_DAMAGE) * pow(1.0 - normalized, 1.35)
			var damage: int = maxi(8, int(round(damage_float)))
			tank_health[player] = maxi(0, tank_health[player] - damage)

func _apply_crater(pos: Vector2) -> void:
	for i: int in range(terrain_points.size()):
		var point: Vector2 = terrain_points[i]
		var dx: float = point.x - pos.x
		if absf(dx) <= CRATER_RADIUS:
			var normalized_x: float = dx / CRATER_RADIUS
			var bowl: float = sqrt(maxf(0.0, 1.0 - normalized_x * normalized_x))
			var target_y: float = pos.y + CRATER_DEPTH * bowl
			point.y = clampf(maxf(point.y, target_y), TERRAIN_MIN_Y, SCREEN_SIZE.y + 80.0)
			terrain_points[i] = point

	_refresh_terrain_line()

func reset_match() -> void:
	current_player = 0
	angle_deg = 45.0
	power = 500.0
	power_slider.value = power
	tank_health = [100, 100]
	projectile_active = false
	projectile_pos = Vector2.ZERO
	projectile_vel = Vector2.ZERO
	explosion_pos = Vector2.INF
	explosion_timer = 0.0
	game_over = false
	_generate_random_terrain()

func _update_ui() -> void:
	angle_label.text = "Angle: %.1f" % angle_deg
	power_label.text = "Power: %.0f" % power

	if game_over:
		var winner: int = 1 if tank_health[0] <= 0 else 0
		status_label.text = "Player %d wins!  P1 HP: %d  P2 HP: %d" % [winner + 1, tank_health[0], tank_health[1]]
	else:
		status_label.text = "Player %d turn    P1 HP: %d    P2 HP: %d" % [current_player + 1, tank_health[0], tank_health[1]]

func _draw() -> void:
	# Sky/background
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.06, 0.07, 0.10), true)

	_draw_ground_fill()

	# Tanks
	_draw_tank(0, Color(0.25, 0.9, 0.35))
	_draw_tank(1, Color(0.95, 0.25, 0.25))

	# Active cannon
	var base: Vector2 = tank_positions[current_player]
	var facing: float = 1.0 if current_player == 0 else -1.0
	var rad: float = deg_to_rad(angle_deg)
	var tip: Vector2 = base + Vector2(facing * CANNON_LENGTH * cos(rad), -CANNON_LENGTH * sin(rad))
	draw_line(base, tip, Color.WHITE, 5.0)

	# Projectile
	if projectile_active:
		draw_circle(projectile_pos, PROJECTILE_RADIUS, Color(1.0, 0.92, 0.2))

	# Explosion flash
	if explosion_timer > 0.0 and explosion_pos != Vector2.INF:
		var t: float = explosion_timer / 0.35
		draw_circle(explosion_pos, EXPLOSION_RADIUS * (1.0 - 0.25 * t), Color(1.0, 0.55, 0.1, 0.55))

func _draw_ground_fill() -> void:
	if terrain_points.is_empty():
		return

	var polygon: PackedVector2Array = PackedVector2Array()
	polygon.append(Vector2(0.0, SCREEN_SIZE.y + 100.0))
	for point: Vector2 in terrain_points:
		polygon.append(point)
	polygon.append(Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y + 100.0))
	draw_colored_polygon(polygon, Color(0.13, 0.24, 0.12))

func _draw_tank(index: int, color: Color) -> void:
	var pos: Vector2 = tank_positions[index]
	var body: Rect2 = Rect2(pos + Vector2(-22, -12), Vector2(44, 20))
	draw_rect(body, color, true)
	draw_circle(pos + Vector2(0, -12), 13.0, color)
	draw_circle(pos + Vector2(-14, 10), 5.0, Color.BLACK)
	draw_circle(pos + Vector2(14, 10), 5.0, Color.BLACK)
