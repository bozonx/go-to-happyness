class_name WorkforcePolicy
extends RefCounted

## Scheduling rules expressed over plain data so they can run headlessly.

static func role_for(worker: Dictionary, world: Dictionary) -> String:
	var permanent_role := str(worker.get("permanent_role", ""))
	if not permanent_role.is_empty():
		return permanent_role
	return str(worker.get("daily_order_role", ""))


static func permanent_vacancy_for(worker: Dictionary, world: Dictionary) -> String:
	# Only fixed productive workplaces create a long-term employment contract.
	# Temporary daily orders are published by DailyPlayerOrderProvider.
	var scores: Dictionary = {}
	# Construction is permanent in every era; early construction sites are jobs.
	_add_empty_workplace_score(scores, world, "construction", _construction_capacity(world))
	_add_empty_workplace_score(scores, world, "forestry", int(world.get("forestry_jobs", world.get("sawmills", 0))))
	_add_empty_workplace_score(scores, world, "farming", int(world.get("farming_jobs", world.get("farms", 0))))
	_add_empty_workplace_score(scores, world, "gather_food", int(world.get("forager_jobs", world.get("forager_tents", 0))))
	_add_empty_workplace_score(scores, world, "gather_branches", int(world.get("materials_yard_jobs", 0)))
	_add_empty_workplace_score(scores, world, "excavation", int(world.get("dig_sites", 0)))
	_add_empty_workplace_score(scores, world, "cook", int(world.get("cooking_jobs", 0)))
	_add_empty_workplace_score(scores, world, "teacher", int(world.get("teacher_jobs", 0)))
	_add_empty_workplace_score(scores, world, "seller", int(world.get("seller_jobs", 0)))
	_add_empty_workplace_score(scores, world, "factory_worker", int(world.get("factory_jobs", 0)))
	_add_empty_workplace_score(scores, world, "craftsman", int(world.get("craftsman_jobs", 0)))
	_add_empty_workplace_score(scores, world, "engineer", int(world.get("engineer_jobs", 0)))
	_add_empty_workplace_score(scores, world, "courier", int(world.get("courier_jobs", 0)))
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


static func _assigned(world: Dictionary, role: String) -> int:
	return int(world.get("assigned_roles", {}).get(role, 0))

static func _construction_capacity(world: Dictionary) -> int:
	var formal_jobs := int(world.get("builder_jobs", 0))
	return formal_jobs if formal_jobs > 0 else int(world.get("construction_sites", 0))


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
		"gather_water": return bool(world.get("has_bucket", false)) and int(world.get("ponds", 0)) > 0
		"cook": return int(world.get("cooking_jobs", 0)) > 0
		"teacher": return int(world.get("schools", 0)) > 0
		"seller": return int(world.get("markets", 0)) > 0
		"factory_worker": return int(world.get("factory_jobs", 0)) > 0
		"engineer": return int(world.get("engineer_jobs", 0)) > 0
		"craftsman": return int(world.get("craftsman_jobs", 0)) > 0
		"courier": return int(world.get("courier_jobs", 0)) > 0
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
	if assigned_role.is_empty():
		return false
	if not str(worker.get("permanent_role", "")).is_empty():
		if assigned_role == "construction" and _construction_capacity(world) <= 0:
			return false
		return _role_available(assigned_role, world)
	var daily_order_role := str(worker.get("daily_order_role", ""))
	var workday_start := int(world.get("workday_start_hour", 8))
	if daily_order_role.is_empty() or int(world.get("hour", 0)) < workday_start:
		return false
	return _role_available(assigned_role, world)


static func can_take_queued_job(worker: Dictionary) -> bool:
	return not bool(worker.get("player_controlled", false)) \
		and bool(worker.get("idle", false)) \
		and str(worker.get("daily_order_role", "")).is_empty() \
		and not bool(worker.get("has_queued_job", false))
