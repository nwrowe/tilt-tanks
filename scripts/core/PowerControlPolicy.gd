extends RefCounted
class_name PowerControlPolicy

## Pure conversion between the power slider percentage and shot launch force.
## Clamp percentage exactly as the original PowerPercent compatibility layer did.
static func clamp_percent(percent: float) -> float:
	return clampf(percent, 0.0, 100.0)

static func force_from_percent(percent: float, minimum: float, maximum: float) -> float:
	return lerpf(minimum, maximum, clamp_percent(percent) / 100.0)
