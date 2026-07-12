class_name WorkforcePolicy
extends RefCounted

## Scheduling rules expressed over plain data so they can run headlessly.

static func role_for(worker: Dictionary, world: Dictionary) -> String:
	var permanent_role := str(worker.get("permanent_role", ""))
	if not permanent_role.is_empty():
		return permanent_role
	var freelance_assignment := str(worker.get("freelance_assignment", worker.get("manual_role", "")))
	if not freelance_assignment.is_empty():
		return freelance_assignment
	var auto_role := _automatic_role_for(worker, world)
	return auto_role


static func permanent_vacancy_for(worker: Dictionary, world: Dictionary) -> String:
	# Only fixed productive workplaces create a long-term employment contract.
	# Couriers and free gatherers stay in the reserve pool.
	var scores: Dictionary = {}
	# Construction is permanent in every era; early construction sites are jobs.
	_add_empty_workplace_score(scores, world, "construction", _construction_capacity(world))
	_add_empty_workplace_score(scores, world, "forestry", int(world.get("forestry_jobs", world.get("sawmills", 0))))
	_add_empty_workplace_score(scores, world, "farming", int(world.get("farming_jobs", world.get("farms", 0))))
	_add_empty_workplace_score(scores, world, "gather_food", int(world.get("forager_jobs", world.get("forager_tents", 0))))
	_add_empty_workplace_score(scores, world, "excavation", int(world.get("dig_sites", 0)))
	_add_empty_workplace_score(scores, world, "cook", int(world.get("cooking_jobs", 0)))
	_add_empty_workplace_score(scores, world, "teacher", int(world.get("teacher_jobs", 0)))
	_add_empty_workplace_score(scores, world, "seller", int(world.get("seller_jobs", 0)))
	_add_empty_workplace_score(scores, world, "factory_worker", int(world.get("factory_jobs", 0)))
	_add_empty_workplace_score(scores, world, "craftsman", int(world.get("craftsman_jobs", 0)))
	_add_empty_workplace_score(scores, world, "engineer", int(world.get("engineer_jobs", 0)))
	if scores.is_empty():
		return ""
	var best_role := ""
	var best_score := -100000
	for role in scores:
		var score := int(scores[role]) + roundi(float(worker.get("skills", {}).get(role, 0.0)) * 10.0)
		if score > best_score:
			best_role = role
			best_score = score
	return best_role


static func _automatic_role_for(worker: Dictionary, world: Dictionary) -> String:
	# Scores are intentionally spaced apart: essentials win first, but every worker
	# already assigned to that shortage lowers its score and prevents herd switching.
	var population := maxi(1, int(world.get("population", 1)))
	var specialization := str(worker.get("specialization", ""))
	var early_construction := int(world.get("era", SettlementState.Era.TENT)) < SettlementState.Era.STONE and int(world.get("construction_sites", 0)) > 0
	if early_construction and _assigned(world, "construction") == 0:
		return "construction"
	var scores: Dictionary = {}
	if int(world.get("food", 0)) < population * 2:
		if int(world.get("farming_jobs", world.get("farms", 0))) > _assigned(world, "farming"):
			_add_score(scores, "farming", 110 - _assigned(world, "farming") * 40)
		if int(world.get("forager_jobs", world.get("forager_tents", 0))) > _assigned(world, "gather_food"):
			_add_score(scores, "gather_food", 106 - _assigned(world, "gather_food") * 40)
	if int(world.get("wood", 0)) < population and int(world.get("forestry_jobs", world.get("sawmills", 0))) > _assigned(world, "forestry") and int(world.get("trees", 0)) > 0:
		_add_score(scores, "forestry", 96 - _assigned(world, "forestry") * 36)

	# An empty productive building is useful immediately. Once occupied, normal
	# shortage and specialization scores decide whether it needs extra workers.
	# Automatic freelancers provide one builder for early construction. Extra
	# sites must not absorb the rest of the reserve while materials are missing;
	# additional builders can still be pinned manually by the player.
	_add_empty_workplace_score(scores, world, "forestry", int(world.get("forestry_jobs", world.get("sawmills", 0))))
	_add_empty_workplace_score(scores, world, "farming", int(world.get("farming_jobs", world.get("farms", 0))))
	_add_empty_workplace_score(scores, world, "gather_food", int(world.get("forager_jobs", world.get("forager_tents", 0))))
	_add_empty_workplace_score(scores, world, "excavation", int(world.get("dig_sites", 0)))

	var preferred := "construction" if specialization == "builder" else specialization
	if preferred == "forestry" and int(world.get("sawmills", 0)) == 0:
		preferred = "forestry" if int(world.get("era", SettlementState.Era.TENT)) >= SettlementState.Era.EARTH and int(world.get("warehouses", 0)) > 0 else "gather_branches"
	elif preferred == "farming" and int(world.get("farms", 0)) == 0:
		preferred = "gather_food" if int(world.get("forager_tents", 0)) > 0 else "gather_grass"
	var can_use_preferred := _automatic_role_has_open_slot(preferred, world)
	if preferred == "forestry" and int(world.get("sawmills", 0)) == 0 and int(world.get("era", SettlementState.Era.TENT)) >= SettlementState.Era.EARTH:
		can_use_preferred = true
	if _role_available(preferred, world) and preferred != "construction" and can_use_preferred:
		_add_score(scores, preferred, 50 - _assigned(world, preferred) * 5)
	if scores.is_empty():
		return "gather_branches"
	var best_role := ""
	var best_score := -100000
	for role in scores:
		if int(scores[role]) > best_score:
			best_role = role
			best_score = int(scores[role])
	return best_role


static func _assigned(world: Dictionary, role: String) -> int:
	return int(world.get("assigned_roles", {}).get(role, 0))

static func _construction_capacity(world: Dictionary) -> int:
	var formal_jobs := int(world.get("builder_jobs", 0))
	return formal_jobs if formal_jobs > 0 else int(world.get("construction_sites", 0))


static func _automatic_role_has_open_slot(role: String, world: Dictionary) -> bool:
	var capacities := {
		"forestry": "forestry_jobs", "farming": "farming_jobs", "gather_food": "forager_jobs",
		"cook": "cooking_jobs", "teacher": "teacher_jobs", "seller": "seller_jobs",
		"factory_worker": "factory_jobs", "engineer": "engineer_jobs",
		"craftsman": "craftsman_jobs"
	}
	if not capacities.has(role):
		return true
	var fallback := {"forestry_jobs": "sawmills", "farming_jobs": "farms", "forager_jobs": "forager_tents"}
	return int(world.get(capacities[role], world.get(fallback.get(capacities[role], ""), 0))) > _assigned(world, role)


static func _add_score(scores: Dictionary, role: String, score: int) -> void:
	scores[role] = maxi(int(scores.get(role, -100000)), score)


static func _add_empty_workplace_score(scores: Dictionary, world: Dictionary, role: String, capacity: int) -> void:
	if capacity > 0 and _assigned(world, role) < capacity and _role_available(role, world):
		_add_score(scores, role, 82 - _assigned(world, role) * 4)


static func _role_available(role: String, world: Dictionary) -> bool:
	match role:
		"construction": return int(world.get("construction_sites", 0)) > 0
		"forestry": return int(world.get("warehouses", 0)) > 0 and int(world.get("trees", 0)) > 0
		"farming": return int(world.get("warehouses", 0)) > 0 and int(world.get("farms", 0)) > 0
		"excavation": return int(world.get("warehouses", 0)) > 0 and int(world.get("dig_sites", 0)) > 0
		"gather_food": return int(world.get("forager_tents", 0)) > 0
		"gather_dew": return bool(world.get("has_collected_dew", false))
		"gather_water": return bool(world.get("has_bucket", false)) and bool(world.get("has_filter", false)) and int(world.get("ponds", 0)) > 0
		"cook": return int(world.get("cooking_jobs", 0)) > 0
		"teacher": return int(world.get("schools", 0)) > 0
		"seller": return int(world.get("markets", 0)) > 0
		"factory_worker": return int(world.get("factory_jobs", 0)) > 0
		"engineer": return int(world.get("engineer_jobs", 0)) > 0
		"craftsman": return int(world.get("craftsman_jobs", 0)) > 0
		# Employment officers can operate in the field before the first campfire
		# or town hall has been built. They are appointed directly, not selected
		# by the automatic-vacancy pass, so this does not create extra officers.
		"official": return true
		"gather_branches": return int(world.get("trees", 0)) > 0
		"gather_grass": return true
	return false


static func can_assign(worker: Dictionary, world: Dictionary) -> bool:
	if bool(worker.get("player_controlled", false)) or bool(worker.get("blocked_by_storage", false)):
		return false
	if str(worker.get("workforce_status", "")) == "unregistered":
		return false
	var assigned_role := role_for(worker, world)
	if not str(worker.get("permanent_role", "")).is_empty():
		if assigned_role == "construction" and _construction_capacity(world) <= 0:
			return false
		return _role_available(assigned_role, world)
	var specialization := str(worker.get("specialization", ""))
	if str(worker.get("freelance_assignment", "")) == "courier" or int(world.get("hour", 0)) < 8:
		return false
	if specialization == "craftsman":
		return int(world.get("craftsman_jobs", 0)) > 0
	if specialization == "cook":
		return bool(world.get("has_canteen", false))
	if specialization == "teacher":
		return int(world.get("schools", 0)) > 0
	if specialization == "seller":
		return int(world.get("markets", 0)) > 0
	if specialization in ["factory_worker", "engineer"]:
		return bool(world.get("has_factory_job", false))
	if bool(worker.get("should_study", false)) and int(world.get("hour", 0)) < 12:
		return int(world.get("schools", 0)) > 0
	if specialization == "builder" and int(world.get("construction_sites", 0)) == 0 and bool(world.get("has_engineer_job", false)):
		return true
		
	match assigned_role:
		"construction": return int(world.get("construction_sites", 0)) > 0
		"forestry": return int(world.get("warehouses", 0)) > 0 and int(world.get("trees", 0)) > 0
		"farming": return int(world.get("warehouses", 0)) > 0 and int(world.get("farms", 0)) > 0
		"excavation": return int(world.get("warehouses", 0)) > 0 and int(world.get("dig_sites", 0)) > 0
		"gather_branches": return int(world.get("trees", 0)) > 0
		"gather_grass": return true
		"gather_food": return int(world.get("forager_tents", 0)) > 0
		"gather_dew": return bool(world.get("has_collected_dew", false))
		"gather_water": return bool(world.get("has_bucket", false)) and bool(world.get("has_filter", false)) and int(world.get("ponds", 0)) > 0
	return false


static func can_take_queued_job(worker: Dictionary) -> bool:
	return not bool(worker.get("player_controlled", false)) \
		and bool(worker.get("idle", false)) \
		and str(worker.get("freelance_assignment", worker.get("manual_role", ""))).is_empty() \
		and not bool(worker.get("has_queued_job", false))
