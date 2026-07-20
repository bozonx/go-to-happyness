class_name CitizenEfficiencyService
extends RefCounted

const CitizenProfileScript = preload("res://game/features/citizens/domain/citizen_profile.gd")


func compute_efficiency(
		role: String,
		skills: Dictionary,
		satisfaction: float,
		fatigue: float,
		buffs: Dictionary,
		has_perk_fn: Callable,
		is_jack_of_all_trades: bool,
		era_index: int,
		story_multiplier_fn: Callable
		) -> float:
	var core_skill := CitizenProfileScript.get_core_skill_for_role(role)
	var S := float(skills.get(core_skill, 0.0)) if not core_skill.is_empty() else 0.5

	# Max penalty is era-dependent
	var max_penalty := 0.15 + 0.11 * float(era_index)
	var skill_efficiency_factor := lerpf(1.0 - max_penalty, 1.30, S)

	# Farmer perk bonus
	if role == "farming" and has_perk_fn.call("farming"):
		skill_efficiency_factor += 0.15

	var satisfaction_factor := lerpf(0.45, 1.0, satisfaction / 100.0)
	var meal_bonus := 0.15 if buffs.has("canteen_meal") else 0.0
	var efficiency := skill_efficiency_factor * satisfaction_factor * (1.0 + meal_bonus)
	efficiency *= lerpf(1.0, 0.55, fatigue / 100.0)
	if is_jack_of_all_trades and role in ["construction", "gather_branches", "gather_grass", "gather_food", "forestry", "farming", "excavation"]:
		efficiency *= 1.30
	if story_multiplier_fn.is_valid():
		efficiency *= float(story_multiplier_fn.call(role))
	return efficiency
