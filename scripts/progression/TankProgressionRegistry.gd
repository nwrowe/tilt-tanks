extends RefCounted
class_name TankProgressionRegistry

# Source-of-truth registry for tank classes, hardware upgrades, and crew roles.
# Runtime systems can query this registry without hardcoding progression data.

const STAT_MAX_HEALTH: String = "max_health"
const STAT_DAMAGE_RESIST: String = "damage_resist"
const STAT_FIRE_POWER: String = "fire_power"
const STAT_AIM_STABILITY: String = "aim_stability"
const STAT_RELOAD_SPEED: String = "reload_speed"
const STAT_ENGINE_POWER: String = "engine_power"
const STAT_TRACK_GRIP: String = "track_grip"
const STAT_SENSOR_RANGE: String = "sensor_range"
const STAT_SPECIALIST_EFFICIENCY: String = "specialist_efficiency"

const SLOT_BARREL: String = "barrel"
const SLOT_ARMOR: String = "armor"
const SLOT_TRACKS: String = "tracks"
const SLOT_CAGE: String = "cope_cage"
const SLOT_ENGINE: String = "engine"
const SLOT_ELECTRONICS: String = "electronics"

const ROLE_DRIVER: String = "driver"
const ROLE_GUNNER: String = "gunner"
const ROLE_WEAPON_SPECIALIST: String = "weapon_specialist"
const ROLE_ENGINEER: String = "engineer"
const ROLE_COMMANDER: String = "commander"

const CLASS_SCOUT: String = "scout"
const CLASS_MEDIUM: String = "medium"
const CLASS_HEAVY: String = "heavy"
const CLASS_SIEGE: String = "siege"

static func build_default_tank_classes() -> Dictionary:
	var classes: Dictionary = {}
	_register_tank_class(classes, {
		"id": CLASS_SCOUT,
		"display_name": "Scout Tank",
		"tier": 1,
		"purchase_cost": 0,
		"description": "Fast starter chassis with light armor and limited upgrade capacity.",
		"base_stats": {
			STAT_MAX_HEALTH: 90.0,
			STAT_DAMAGE_RESIST: 0.0,
			STAT_FIRE_POWER: 1.0,
			STAT_AIM_STABILITY: 1.0,
			STAT_RELOAD_SPEED: 1.08,
			STAT_ENGINE_POWER: 1.12,
			STAT_TRACK_GRIP: 1.0
		},
		"stat_caps": {
			STAT_MAX_HEALTH: 125.0,
			STAT_DAMAGE_RESIST: 0.12,
			STAT_FIRE_POWER: 1.12,
			STAT_AIM_STABILITY: 1.18,
			STAT_RELOAD_SPEED: 1.22,
			STAT_ENGINE_POWER: 1.30,
			STAT_TRACK_GRIP: 1.20
		},
		"slot_limits": {
			SLOT_BARREL: 1,
			SLOT_ARMOR: 1,
			SLOT_TRACKS: 1,
			SLOT_ENGINE: 1
		},
		"crew_slots": {
			ROLE_DRIVER: 1,
			ROLE_GUNNER: 1
		},
		"max_weapon_tier": 1,
		"max_upgrade_tier": 1
	})
	_register_tank_class(classes, {
		"id": CLASS_MEDIUM,
		"display_name": "Medium Tank",
		"tier": 2,
		"purchase_cost": 650,
		"description": "Balanced chassis with room for core upgrades and a small crew.",
		"base_stats": {
			STAT_MAX_HEALTH: 115.0,
			STAT_DAMAGE_RESIST: 0.08,
			STAT_FIRE_POWER: 1.05,
			STAT_AIM_STABILITY: 1.05,
			STAT_RELOAD_SPEED: 1.0,
			STAT_ENGINE_POWER: 1.0,
			STAT_TRACK_GRIP: 1.05
		},
		"stat_caps": {
			STAT_MAX_HEALTH: 165.0,
			STAT_DAMAGE_RESIST: 0.22,
			STAT_FIRE_POWER: 1.24,
			STAT_AIM_STABILITY: 1.30,
			STAT_RELOAD_SPEED: 1.24,
			STAT_ENGINE_POWER: 1.22,
			STAT_TRACK_GRIP: 1.25
		},
		"slot_limits": {
			SLOT_BARREL: 1,
			SLOT_ARMOR: 1,
			SLOT_TRACKS: 1,
			SLOT_CAGE: 1,
			SLOT_ENGINE: 1,
			SLOT_ELECTRONICS: 1
		},
		"crew_slots": {
			ROLE_DRIVER: 1,
			ROLE_GUNNER: 1,
			ROLE_WEAPON_SPECIALIST: 1
		},
		"max_weapon_tier": 2,
		"max_upgrade_tier": 2
	})
	_register_tank_class(classes, {
		"id": CLASS_HEAVY,
		"display_name": "Heavy Tank",
		"tier": 3,
		"purchase_cost": 1400,
		"description": "Durable chassis with strong armor capacity and larger crew support.",
		"base_stats": {
			STAT_MAX_HEALTH: 150.0,
			STAT_DAMAGE_RESIST: 0.16,
			STAT_FIRE_POWER: 1.10,
			STAT_AIM_STABILITY: 0.98,
			STAT_RELOAD_SPEED: 0.94,
			STAT_ENGINE_POWER: 0.88,
			STAT_TRACK_GRIP: 0.98
		},
		"stat_caps": {
			STAT_MAX_HEALTH: 230.0,
			STAT_DAMAGE_RESIST: 0.36,
			STAT_FIRE_POWER: 1.38,
			STAT_AIM_STABILITY: 1.28,
			STAT_RELOAD_SPEED: 1.16,
			STAT_ENGINE_POWER: 1.12,
			STAT_TRACK_GRIP: 1.22
		},
		"slot_limits": {
			SLOT_BARREL: 1,
			SLOT_ARMOR: 2,
			SLOT_TRACKS: 1,
			SLOT_CAGE: 1,
			SLOT_ENGINE: 1,
			SLOT_ELECTRONICS: 1
		},
		"crew_slots": {
			ROLE_DRIVER: 1,
			ROLE_GUNNER: 1,
			ROLE_WEAPON_SPECIALIST: 1,
			ROLE_ENGINEER: 1,
			ROLE_COMMANDER: 1
		},
		"max_weapon_tier": 3,
		"max_upgrade_tier": 3
	})
	_register_tank_class(classes, {
		"id": CLASS_SIEGE,
		"display_name": "Siege Tank",
		"tier": 4,
		"purchase_cost": 2600,
		"description": "Late-game chassis for heavy weapons, specialist crew, and high stat ceilings.",
		"base_stats": {
			STAT_MAX_HEALTH: 175.0,
			STAT_DAMAGE_RESIST: 0.20,
			STAT_FIRE_POWER: 1.18,
			STAT_AIM_STABILITY: 1.00,
			STAT_RELOAD_SPEED: 0.88,
			STAT_ENGINE_POWER: 0.78,
			STAT_TRACK_GRIP: 0.94
		},
		"stat_caps": {
			STAT_MAX_HEALTH: 300.0,
			STAT_DAMAGE_RESIST: 0.46,
			STAT_FIRE_POWER: 1.55,
			STAT_AIM_STABILITY: 1.35,
			STAT_RELOAD_SPEED: 1.12,
			STAT_ENGINE_POWER: 1.04,
			STAT_TRACK_GRIP: 1.16,
			STAT_SENSOR_RANGE: 1.35,
			STAT_SPECIALIST_EFFICIENCY: 1.40
		},
		"slot_limits": {
			SLOT_BARREL: 2,
			SLOT_ARMOR: 2,
			SLOT_TRACKS: 1,
			SLOT_CAGE: 1,
			SLOT_ENGINE: 1,
			SLOT_ELECTRONICS: 2
		},
		"crew_slots": {
			ROLE_DRIVER: 1,
			ROLE_GUNNER: 1,
			ROLE_WEAPON_SPECIALIST: 2,
			ROLE_ENGINEER: 1,
			ROLE_COMMANDER: 1
		},
		"max_weapon_tier": 4,
		"max_upgrade_tier": 4
	})
	return classes

static func build_default_upgrades() -> Dictionary:
	var upgrades: Dictionary = {}
	_register_upgrade(upgrades, {
		"id": "stabilized_barrel_mk1",
		"display_name": "Stabilized Barrel Mk I",
		"slot_id": SLOT_BARREL,
		"tier": 1,
		"purchase_cost": 120,
		"description": "Improves aim stability and slightly boosts fire power.",
		"stat_modifiers": {STAT_AIM_STABILITY: 0.08, STAT_FIRE_POWER: 0.03}
	})
	_register_upgrade(upgrades, {
		"id": "reinforced_armor_mk1",
		"display_name": "Reinforced Armor Mk I",
		"slot_id": SLOT_ARMOR,
		"tier": 1,
		"purchase_cost": 140,
		"description": "Adds health and light damage resistance.",
		"stat_modifiers": {STAT_MAX_HEALTH: 18.0, STAT_DAMAGE_RESIST: 0.04}
	})
	_register_upgrade(upgrades, {
		"id": "wide_tracks_mk1",
		"display_name": "Wide Tracks Mk I",
		"slot_id": SLOT_TRACKS,
		"tier": 1,
		"purchase_cost": 110,
		"description": "Improves grip for hills, snow, and rough terrain.",
		"stat_modifiers": {STAT_TRACK_GRIP: 0.08, STAT_ENGINE_POWER: 0.02}
	})
	_register_upgrade(upgrades, {
		"id": "engine_tune_mk1",
		"display_name": "Engine Tune Mk I",
		"slot_id": SLOT_ENGINE,
		"tier": 1,
		"purchase_cost": 130,
		"description": "Improves movement response and engine output.",
		"stat_modifiers": {STAT_ENGINE_POWER: 0.10}
	})
	_register_upgrade(upgrades, {
		"id": "cope_cage_mk1",
		"display_name": "Cope Cage Mk I",
		"slot_id": SLOT_CAGE,
		"tier": 2,
		"purchase_cost": 260,
		"required_tank_tier": 2,
		"description": "Adds protection against overhead/splash damage at a small mobility cost.",
		"stat_modifiers": {STAT_DAMAGE_RESIST: 0.07, STAT_ENGINE_POWER: -0.03}
	})
	_register_upgrade(upgrades, {
		"id": "ballistic_computer_mk1",
		"display_name": "Ballistic Computer Mk I",
		"slot_id": SLOT_ELECTRONICS,
		"tier": 2,
		"purchase_cost": 300,
		"required_tank_tier": 2,
		"description": "Improves aiming consistency and specialist efficiency.",
		"stat_modifiers": {STAT_AIM_STABILITY: 0.12, STAT_SPECIALIST_EFFICIENCY: 0.08}
	})
	return upgrades

static func build_default_crew() -> Dictionary:
	var crew: Dictionary = {}
	_register_crew(crew, {
		"id": "rookie_driver",
		"display_name": "Rookie Driver",
		"role_id": ROLE_DRIVER,
		"training_cost": 120,
		"description": "Improves movement and rough-terrain handling as they train.",
		"level_stat_modifiers": {
			"1": {STAT_ENGINE_POWER: 0.03, STAT_TRACK_GRIP: 0.02},
			"2": {STAT_ENGINE_POWER: 0.04, STAT_TRACK_GRIP: 0.03},
			"3": {STAT_ENGINE_POWER: 0.05, STAT_TRACK_GRIP: 0.04}
		}
	})
	_register_crew(crew, {
		"id": "rookie_gunner",
		"display_name": "Rookie Gunner",
		"role_id": ROLE_GUNNER,
		"training_cost": 130,
		"description": "Improves aim stability and reload cadence.",
		"level_stat_modifiers": {
			"1": {STAT_AIM_STABILITY: 0.04},
			"2": {STAT_AIM_STABILITY: 0.05, STAT_RELOAD_SPEED: 0.03},
			"3": {STAT_AIM_STABILITY: 0.06, STAT_RELOAD_SPEED: 0.04}
		}
	})
	_register_crew(crew, {
		"id": "weapons_specialist",
		"display_name": "Weapons Specialist",
		"role_id": ROLE_WEAPON_SPECIALIST,
		"training_cost": 180,
		"description": "Improves special weapon handling and fire power.",
		"level_stat_modifiers": {
			"1": {STAT_SPECIALIST_EFFICIENCY: 0.05},
			"2": {STAT_SPECIALIST_EFFICIENCY: 0.07, STAT_FIRE_POWER: 0.03},
			"3": {STAT_SPECIALIST_EFFICIENCY: 0.08, STAT_FIRE_POWER: 0.04}
		}
	})
	_register_crew(crew, {
		"id": "field_engineer",
		"display_name": "Field Engineer",
		"role_id": ROLE_ENGINEER,
		"training_cost": 190,
		"description": "Improves survivability and system efficiency.",
		"level_stat_modifiers": {
			"1": {STAT_MAX_HEALTH: 8.0},
			"2": {STAT_MAX_HEALTH: 10.0, STAT_DAMAGE_RESIST: 0.02},
			"3": {STAT_MAX_HEALTH: 12.0, STAT_DAMAGE_RESIST: 0.03}
		}
	})
	_register_crew(crew, {
		"id": "tank_commander",
		"display_name": "Tank Commander",
		"role_id": ROLE_COMMANDER,
		"training_cost": 240,
		"description": "Provides broad team coordination bonuses.",
		"level_stat_modifiers": {
			"1": {STAT_AIM_STABILITY: 0.02, STAT_RELOAD_SPEED: 0.02},
			"2": {STAT_AIM_STABILITY: 0.03, STAT_RELOAD_SPEED: 0.03, STAT_SENSOR_RANGE: 0.04},
			"3": {STAT_AIM_STABILITY: 0.04, STAT_RELOAD_SPEED: 0.04, STAT_SENSOR_RANGE: 0.06}
		}
	})
	return crew

static func default_player_build(player_index: int) -> TankBuildState:
	return TankBuildState.new({
		"player_index": player_index,
		"tank_class_id": CLASS_SCOUT,
		"installed_upgrade_ids": [],
		"assigned_crew_ids": ["rookie_driver", "rookie_gunner"],
		"unlocked_weapon_ids": [],
		"credits": 0
	})

static func get_tank_class(classes: Dictionary, class_id: String) -> TankClassDefinition:
	if classes.has(class_id):
		return classes[class_id] as TankClassDefinition
	return classes.get(CLASS_SCOUT, TankClassDefinition.new({"id": CLASS_SCOUT, "display_name": "Scout Tank"})) as TankClassDefinition

static func get_upgrade(upgrades: Dictionary, upgrade_id: String) -> TankUpgradeDefinition:
	return upgrades.get(upgrade_id, null) as TankUpgradeDefinition

static func get_crew_member(crew: Dictionary, crew_id: String) -> CrewMemberDefinition:
	return crew.get(crew_id, null) as CrewMemberDefinition

static func effective_stats(build: TankBuildState, classes: Dictionary, upgrades: Dictionary, crew: Dictionary) -> Dictionary:
	var tank_class: TankClassDefinition = get_tank_class(classes, build.tank_class_id)
	var stats: Dictionary = tank_class.base_stats.duplicate(true)
	for upgrade_id: String in build.installed_upgrade_ids:
		var upgrade: TankUpgradeDefinition = get_upgrade(upgrades, upgrade_id)
		if upgrade == null:
			continue
		for stat_id: String in upgrade.stat_modifiers.keys():
			stats[stat_id] = float(stats.get(stat_id, 0.0)) + float(upgrade.stat_modifiers[stat_id])
	for crew_id: String in build.assigned_crew_ids:
		var member: CrewMemberDefinition = get_crew_member(crew, crew_id)
		if member == null:
			continue
		for stat_id: String in _known_stat_ids():
			var delta: float = member.stat_delta(stat_id)
			if delta != 0.0:
				stats[stat_id] = float(stats.get(stat_id, 0.0)) + delta
	for stat_id: String in stats.keys():
		stats[stat_id] = tank_class.capped_stat(stat_id, float(stats[stat_id]))
	return stats

static func can_install_upgrade(build: TankBuildState, upgrade: TankUpgradeDefinition, classes: Dictionary) -> bool:
	if upgrade == null:
		return false
	if build.has_upgrade(upgrade.id):
		return false
	var tank_class: TankClassDefinition = get_tank_class(classes, build.tank_class_id)
	if tank_class.tier < upgrade.required_tank_tier:
		return false
	if upgrade.tier > tank_class.max_upgrade_tier:
		return false
	if not tank_class.supports_upgrade_slot(upgrade.slot_id):
		return false
	if not upgrade.prerequisites_met(build.installed_upgrade_ids):
		return false
	var used_in_slot: int = 0
	for installed_id: String in build.installed_upgrade_ids:
		var installed: TankUpgradeDefinition = get_upgrade(build_default_upgrades(), installed_id)
		if installed != null and installed.slot_id == upgrade.slot_id:
			used_in_slot += 1
	return used_in_slot < tank_class.slot_limit(upgrade.slot_id)

static func can_assign_crew(build: TankBuildState, member: CrewMemberDefinition, classes: Dictionary, crew: Dictionary) -> bool:
	if member == null:
		return false
	if build.has_crew(member.id):
		return false
	var tank_class: TankClassDefinition = get_tank_class(classes, build.tank_class_id)
	if not tank_class.supports_crew_role(member.role_id):
		return false
	var used_in_role: int = 0
	for crew_id: String in build.assigned_crew_ids:
		var assigned: CrewMemberDefinition = get_crew_member(crew, crew_id)
		if assigned != null and assigned.role_id == member.role_id:
			used_in_role += 1
	return used_in_role < tank_class.crew_slot_limit(member.role_id)

static func _register_tank_class(classes: Dictionary, data: Dictionary) -> void:
	classes[str(data.get("id", CLASS_SCOUT))] = TankClassDefinition.new(data)

static func _register_upgrade(upgrades: Dictionary, data: Dictionary) -> void:
	upgrades[str(data.get("id", ""))] = TankUpgradeDefinition.new(data)

static func _register_crew(crew: Dictionary, data: Dictionary) -> void:
	crew[str(data.get("id", ""))] = CrewMemberDefinition.new(data)

static func _known_stat_ids() -> Array[String]:
	return [
		STAT_MAX_HEALTH,
		STAT_DAMAGE_RESIST,
		STAT_FIRE_POWER,
		STAT_AIM_STABILITY,
		STAT_RELOAD_SPEED,
		STAT_ENGINE_POWER,
		STAT_TRACK_GRIP,
		STAT_SENSOR_RANGE,
		STAT_SPECIALIST_EFFICIENCY
	]
