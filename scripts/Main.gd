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
const TANK_RADIUS: float = 16.0
const CANNON_LENGTH: float = 46.0
const PROJECTILE_RADIUS: float = 5.0
const EXPLOSION_RADIUS: float = 46.0

var tank_positions: Array[Vector2] = [Vector2(120, GROUND_Y - TANK_RADIUS), Vector2(780, GROUND_Y - TANK_RADIUS)]
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
	fire_button.pressed.connect(_on_fire_pressed)
	reset_button.pressed.connect(reset_match)
	_make_flat_terrain()
	_update_ui()

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

func _make_flat_terrain() -> void:
	terrain.clear_points()
	terrain.add_point(Vector2(0, GROUND_Y))
	terrain.add_point(Vector2(SCREEN_SIZE.x, GROUND_Y))

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
	if projectile_pos.distance_to(tank_positions[enemy]) <= EXPLOSION_RADIUS:
		_explode(projectile_pos)
		return

	if projectile_pos.y >= GROUND_Y:
		_explode(projectile_pos)
		return

	if projectile_pos.x < -100.0 or projectile_pos.x > SCREEN_SIZE.x + 100.0 or projectile_pos.y > SCREEN_SIZE.y + 150.0:
		_explode(projectile_pos)

func _explode(pos: Vector2) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = 0.35

	for player: int in range(2):
		var dist: float = pos.distance_to(tank_positions[player])
		if dist <= EXPLOSION_RADIUS:
			var damage: int = int(round(45.0 * (1.0 - dist / EXPLOSION_RADIUS)))
			tank_health[player] = maxi(0, tank_health[player] - damage)

	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
	else:
		current_player = 1 - current_player

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

	# Ground fill
	draw_rect(Rect2(Vector2(0, GROUND_Y), Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y - GROUND_Y)), Color(0.13, 0.24, 0.12), true)

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

func _draw_tank(index: int, color: Color) -> void:
	var pos: Vector2 = tank_positions[index]
	var body: Rect2 = Rect2(pos + Vector2(-22, -12), Vector2(44, 20))
	draw_rect(body, color, true)
	draw_circle(pos + Vector2(0, -12), 13.0, color)
	draw_circle(pos + Vector2(-14, 10), 5.0, Color.BLACK)
	draw_circle(pos + Vector2(14, 10), 5.0, Color.BLACK)
