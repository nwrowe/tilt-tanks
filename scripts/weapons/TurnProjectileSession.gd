extends RefCounted
class_name TurnProjectileSession

## Owns the turn-based multi-shell collection and its weapon/split state.
## Projectile physics, impact routing and camera behavior stay with the game.
## Preserve the existing shell array identity across match resets, because
## hotseat and online gameplay may hold references to this typed array.

var shells: Array[Dictionary] = []
var weapon: String = WeaponCatalog.STANDARD
var split_done: bool = false

func reset_for_match(selected_weapon: String) -> void:
	shells.clear()
	weapon = selected_weapon
	split_done = false
