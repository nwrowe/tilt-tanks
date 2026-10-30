extends RefCounted
class_name RealtimeCooldownPolicy

## Standalone realtime cooldown and movement-exhaustion policy.
## The active runtime retains fields for inherited callers and binds results
## back after each frame. Preserve the order of clamp, expiry and recharge.

static func advance(
	player_fire: float, ai_fire: float, ai_move: float,
	exhaust: float, energy: float, max_energy: float, delta: float
) -> Dictionary:
	player_fire = maxf(0.0, player_fire - delta)
	ai_fire = maxf(0.0, ai_fire - delta)
	ai_move = maxf(0.0, ai_move - delta)
	var was_overheated: bool = false
	if exhaust > 0.0:
		exhaust = maxf(0.0, exhaust - delta)
		was_overheated = true
		if exhaust <= 0.0:
			energy = maxf(energy, max_energy * 0.25)
	return {
		"player_fire": player_fire, "ai_fire": ai_fire,
		"ai_move": ai_move, "exhaust": exhaust,
		"energy": energy, "was_overheated": was_overheated
	}
