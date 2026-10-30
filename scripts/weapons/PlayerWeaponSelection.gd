extends RefCounted
class_name PlayerWeaponSelection

## Independent per-player weapon preferences. The active game still owns
## selected_weapon and the menus, while this object owns saved selections.
var choices: Array[String] = []

func reset(default_weapon: String, player_count: int = 2) -> void:
	choices.clear()
	for i: int in range(player_count):
		choices.append(default_weapon)

func save(player_index: int, weapon: String, default_weapon: String) -> void:
	if player_index < 0:
		return
	while choices.size() <= player_index:
		choices.append(default_weapon)
	choices[player_index] = weapon

func load(player_index: int, loadout: WeaponLoadout, default_weapon: String) -> String:
	if player_index < 0 or player_index >= choices.size():
		return default_weapon
	if loadout == null:
		return choices[player_index]
	return loadout.safe_weapon(choices[player_index])
