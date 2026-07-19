class_name CitizenProfile
extends RefCounted

## Deterministic skill state and rules for a citizen. No nodes, physics,
## rendering or simulation references — only skill values, growth, decay,
## and the role-to-skill mapping.

const DEVELOPED_SKILL_THRESHOLD := 0.15
const SKILL_GROWTH_PER_SECOND_WORK := 0.0001
const DAILY_CONSTRUCTION_SKILL_CAP := 0.20
const SKILL_GROWTH_PER_SCHOOL_DAY := 0.01
const SKILL_DECAY_RATE := 0.005
const SKILL_MIN_FLOOR := 0.10

var specialization := "unassigned"
var skills := {}
var is_jack_of_all_trades := false
var practiced_today: Dictionary = {}


static func get_core_skill_for_role(role: String) -> String:
	match role:
		"construction", "demolition":
			return "construction"
		"forestry", "gather_branches", "gather_logs":
			return "forestry"
		"farming", "gather_water", "gather_food", "gather_grass":
			return "farming"
		"excavation":
			return "excavation"
		"factory_work", "factory_worker":
			return "factory_worker"
		"engineering", "engineer":
			return "engineer"
		"courier":
			return "courier"
		"craftsman", "crafting":
			return "craftsman"
		"cooking", "cook":
			return "cook"
		"teaching", "teacher":
			return "teacher"
		"selling", "seller":
			return "seller"
		"registration", "official":
			return "official"
		_:
			return ""


func has_perk(skill_name: String) -> bool:
	return skills.get(skill_name, 0.0) >= 1.0


func apply_daily_decay() -> void:
	for skill_name in skills.keys():
		if not practiced_today.get(skill_name, false):
			skills[skill_name] = maxf(SKILL_MIN_FLOOR, float(skills.get(skill_name, 0.0)) - SKILL_DECAY_RATE)
	practiced_today.clear()
