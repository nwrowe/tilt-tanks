extends RefCounted
class_name MatchDamagePolicy

## Pure weapon radial damage computation. Intentionally preserves the
## two legacy blast profiles: standard explosions have a 6 HP minimum
## splash hit; registry-driven weapon explosions use 4 HP minimum.
static func radial_damage(
	impact: Vector2,
	target: Vector2,
	direct_radius: float,
	blast_radius: float,
	direct_damage: int,
	splash_damage: int,
	minimum_splash: int
) -> int:
	var distance: float = impact.distance_to(target)
	if distance <= direct_radius:
		return direct_damage
	if distance > blast_radius:
		return 0
	var normalized: float = (distance - direct_radius) / maxf(blast_radius - direct_radius, 1.0)
	var falloff_damage: float = float(splash_damage) * pow(1.0 - normalized, 1.35)
	return maxi(minimum_splash, int(round(falloff_damage)))
