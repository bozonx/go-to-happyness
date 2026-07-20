class_name CitizenSatisfactionService
extends RefCounted

const CitizenProfileScript = preload("res://game/features/citizens/domain/citizen_profile.gd")

const DEVELOPED_SKILL_THRESHOLD := CitizenProfileScript.DEVELOPED_SKILL_THRESHOLD
const SKILL_GROWTH_PER_SECOND_WORK := CitizenProfileScript.SKILL_GROWTH_PER_SECOND_WORK
const DAILY_CONSTRUCTION_SKILL_CAP := CitizenProfileScript.DAILY_CONSTRUCTION_SKILL_CAP

## Result of a satisfaction update tick.
## Fields:
##   satisfaction: float — new satisfaction value
##   satisfaction_tick: float — remaining tick accumulator (always 0.0 after a full tick)
##   skills: Dictionary — updated skills dictionary (only the active core skill may have grown)
##   practiced_skills: Array[String] — skills that were practiced this tick
class SatisfactionResult:
	var satisfaction: float
	var satisfaction_tick: float
	var skills: Dictionary
	var practiced_skills: Array[String]

	func _init(p_satisfaction: float, p_satisfaction_tick: float, p_skills: Dictionary, p_practiced_skills: Array[String]) -> void:
		satisfaction = p_satisfaction
		satisfaction_tick = p_satisfaction_tick
		skills = p_skills
		practiced_skills = p_practiced_skills


## Compute one satisfaction/skill-growth tick.
##
## Parameters:
##   active_role: current work role (empty = idle)
##   preferred_role: the citizen's preferred role string
##   overtime_mode: whether overtime is active
##   satisfaction: current satisfaction value
##   satisfaction_tick: accumulated time since last tick
##   skills: current skills dictionary (will be copied, not mutated)
##   satisfaction_cap: max satisfaction value
##   has_active_daily_order: whether a daily order is active
##   mentor_check_fn: Callable(core_skill: String, position: Vector3) -> float
##                    Returns growth multiplier (1.0 = no mentor, 1.5 = mentor nearby)
##   position: citizen's world position (for mentor proximity check)
func compute_tick(
		active_role: String,
		preferred_role: String,
		overtime_mode: bool,
		satisfaction: float,
		satisfaction_tick: float,
		skills: Dictionary,
		satisfaction_cap: float,
		has_active_daily_order: bool,
		mentor_check_fn: Callable,
		position: Vector3
		) -> SatisfactionResult:
	satisfaction_tick += 0.0
	if satisfaction_tick < 1.0:
		return SatisfactionResult.new(satisfaction, satisfaction_tick, skills, [])

	if active_role.is_empty():
		var idle_sat := minf(satisfaction_cap, satisfaction + 1.2 * satisfaction_tick)
		return SatisfactionResult.new(idle_sat, 0.0, skills, [])

	var core_pref_role := CitizenProfileScript.get_core_skill_for_role(preferred_role)
	var core_active_role := CitizenProfileScript.get_core_skill_for_role(active_role)
	var change := 0.0

	if overtime_mode:
		change -= 3.0

	if not core_active_role.is_empty() and core_active_role == core_pref_role:
		change = 1.2
	else:
		var has_developed := false
		for val in skills.values():
			if float(val) > DEVELOPED_SKILL_THRESHOLD:
				has_developed = true
				break
		if has_developed:
			change = -2.0
		else:
			change = 0.0

	var new_satisfaction := clampf(satisfaction + change * satisfaction_tick, 0.0, satisfaction_cap)

	# Skill growth with mentor synergy
	var practiced_skills: Array[String] = []
	var new_skills := skills.duplicate()
	var core_skill := CitizenProfileScript.get_core_skill_for_role(active_role)
	if not core_skill.is_empty():
		var growth_multiplier := 1.0
		if mentor_check_fn.is_valid():
			growth_multiplier = float(mentor_check_fn.call(core_skill, position))
		var current_val := float(new_skills.get(core_skill, 0.0))
		var skill_cap := 1.0
		if has_active_daily_order and core_skill == "construction":
			skill_cap = DAILY_CONSTRUCTION_SKILL_CAP
		new_skills[core_skill] = minf(skill_cap, current_val + SKILL_GROWTH_PER_SECOND_WORK * growth_multiplier * satisfaction_tick)
		practiced_skills.append(core_skill)

	return SatisfactionResult.new(new_satisfaction, 0.0, new_skills, practiced_skills)
