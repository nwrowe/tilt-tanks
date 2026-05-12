extends "res://scripts/MainMask6.gd"

const BODY_COLLISION_HALF_WIDTH: float = 20.0
const BODY_COLLISION_TOP: float = 26.0
const BODY_COLLISION_BOTTOM_ABOVE_FEET: float = 5.0
const GROUND_SUPPORT_DEPTH: float = 7.0

func _tank_body_collides(center: Vector2) -> bool:
	# Check only the tank body above the ground contact point. The previous rectangle
	# included the feet/ground contact area, so a tank standing on dirt counted as
	# colliding and movement was rejected.
	var left_col: int = clampi(int(floor((center.x - BODY_COLLISION_HALF_WIDTH) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var right_col: int = clampi(int(ceil((center.x + BODY_COLLISION_HALF_WIDTH) / TERRAIN_STEP)), 0, terrain_cols - 1)
	var top_row: int = clampi(int(floor((center.y - BODY_COLLISION_TOP) / TERRAIN_STEP)), 0, terrain_rows - 1)
	var bottom_y: float = center.y + TANK_RADIUS - BODY_COLLISION_BOTTOM_ABOVE_FEET
	var bottom_row: int = clampi(int(floor(bottom_y / TERRAIN_STEP)), 0, terrain_rows - 1)
	for col: int in range(left_col, right_col + 1):
		for row: int in range(top_row, bottom_row + 1):
			if solid[col][row] == 1:
				return true
	return false

func _has_ground_support(center: Vector2) -> bool:
	# Support is checked just below the tank feet, separate from body collision.
	var foot_y: float = center.y + TANK_RADIUS + GROUND_SUPPORT_DEPTH
	var sample_offsets: Array[float] = [-TANK_COLLISION_HALF_WIDTH * 0.8, 0.0, TANK_COLLISION_HALF_WIDTH * 0.8]
	for offset: float in sample_offsets:
		if _is_solid_at(Vector2(center.x + offset, foot_y)):
			return true
	return false

func _can_move_tank_to(candidate: Vector2, old_pos: Vector2) -> bool:
	var dy: float = candidate.y - old_pos.y
	if dy < -TANK_MAX_CLIMB_PER_MOVE:
		return false
	if dy > TANK_MAX_DROP_PER_MOVE:
		return false
	if _tank_body_collides(candidate):
		return false
	if not _has_ground_support(candidate):
		return false
	return true
