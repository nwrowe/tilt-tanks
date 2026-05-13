extends "res://scripts/MainHybridModes17.gd"

const CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION: float = 0.85

var cluster_camera_hold_timer: float = 0.0
var cluster_camera_hold_pos: Vector2 = Vector2.INF

func _ready() -> void:
	super._ready()
	_add_true_quit_button()

func reset_match() -> void:
	cluster_camera_hold_timer = 0.0
	cluster_camera_hold_pos = Vector2.INF
	super.reset_match()

func _add_true_quit_button() -> void:
	if menu_panel == null:
		return
	# Keep Main Menu, and add a real Quit button below it.
	menu_panel.size = Vector2(230, 240)
	var quit_button: Button = Button.new()
	quit_button.text = "Quit"
	quit_button.position = Vector2(16, 184)
	quit_button.size = Vector2(198, 36)
	_style_mobile_button(quit_button)
	menu_panel.add_child(quit_button)
	quit_button.pressed.connect(func() -> void:
		get_tree().quit()
	)

func _process(delta: float) -> void:
	if cluster_camera_hold_timer > 0.0:
		cluster_camera_hold_timer = maxf(0.0, cluster_camera_hold_timer - delta)
		if cluster_camera_hold_timer <= 0.0:
			cluster_camera_hold_pos = Vector2.INF
	super._process(delta)

func _camera_target_x() -> float:
	if turn_cluster_camera_pos != Vector2.INF:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(turn_cluster_camera_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	if cluster_camera_hold_pos != Vector2.INF and cluster_camera_hold_timer > 0.0:
		var camera_world_width: float = VIEW_SIZE.x / CAMERA_SCALE
		return clampf(cluster_camera_hold_pos.x - camera_world_width * 0.5, 0.0, maxf(0.0, active_world_width - camera_world_width))
	return super._camera_target_x()

func _draw() -> void:
	super._draw()
	_draw_turn_cluster_projectiles()

func _draw_turn_cluster_projectiles() -> void:
	# Hotseat cluster children are tracked separately from realtime projectiles,
	# so draw them explicitly after the parent draw pass.
	for shell: Dictionary in turn_projectiles:
		var weapon: String = str(shell.get("weapon", WEAPON_CLUSTER_CHILD))
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var radius: float = PROJECTILE_RADIUS * CAMERA_SCALE
		if weapon == WEAPON_CLUSTER_CHILD:
			radius *= 0.78
		elif weapon == WEAPON_HEAVY:
			radius *= 1.45
		var color: Color = Color(1.0, 0.92, 0.20)
		draw_circle(_world_to_screen(pos), radius, color)

func _update_turn_weapon_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	turn_cluster_camera_pos = Vector2.INF
	var last_center_pos: Vector2 = Vector2.INF
	var any_center_shell_alive: bool = false

	for shell: Dictionary in turn_projectiles:
		var pos: Vector2 = shell.get("pos", Vector2.ZERO)
		var vel: Vector2 = shell.get("vel", Vector2.ZERO)
		var owner: int = int(shell.get("owner", current_player))
		var weapon: String = str(shell.get("weapon", WEAPON_CLUSTER_CHILD))
		var is_center: bool = bool(shell.get("center_child", false))
		vel.y += gravity * delta
		vel.x += wind * delta
		pos += vel * delta

		if is_center:
			last_center_pos = pos
			turn_cluster_camera_pos = pos

		if _turn_shell_should_explode(owner, pos):
			_explode_turn_weapon(pos, weapon, false)
			if is_center:
				cluster_camera_hold_pos = pos
				cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		else:
			shell["pos"] = pos
			shell["vel"] = vel
			remaining.append(shell)
			if is_center:
				any_center_shell_alive = true

	turn_projectiles = remaining
	if any_center_shell_alive:
		cluster_camera_hold_pos = last_center_pos
	elif not turn_projectiles.is_empty() and cluster_camera_hold_pos == Vector2.INF:
		# If the center shell somehow disappears first, keep camera near the average
		# of the remaining child shells instead of snapping back.
		var avg: Vector2 = Vector2.ZERO
		for shell: Dictionary in turn_projectiles:
			avg += shell.get("pos", Vector2.ZERO)
		avg /= float(turn_projectiles.size())
		turn_cluster_camera_pos = avg
		cluster_camera_hold_pos = avg

	if turn_projectiles.is_empty():
		turn_cluster_camera_pos = Vector2.INF
		if cluster_camera_hold_pos == Vector2.INF:
			cluster_camera_hold_pos = last_center_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		if not game_over:
			_advance_turn()

func _explode_turn_weapon(pos: Vector2, weapon: String, advance_after: bool) -> void:
	projectile_active = false
	explosion_pos = pos
	explosion_timer = EXPLOSION_DURATION
	last_explosion_visual_radius = _weapon_explosion_radius(weapon)
	_apply_weapon_crater(pos, weapon)
	_apply_weapon_damage(pos, weapon)
	_settle_tanks_on_terrain()
	if tank_health[0] <= 0 or tank_health[1] <= 0:
		game_over = true
		_show_end_popup()
	elif advance_after:
		cluster_camera_hold_pos = pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
		_advance_turn()

func _update_all_realtime_projectiles(delta: float) -> void:
	var before_count: int = rt_projectiles.size()
	super._update_all_realtime_projectiles(delta)
	if before_count > 0 and rt_projectiles.is_empty() and explosion_pos != Vector2.INF:
		cluster_camera_hold_pos = explosion_pos
		cluster_camera_hold_timer = CLUSTER_CAMERA_HOLD_AFTER_EXPLOSION
