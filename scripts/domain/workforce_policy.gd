class_name WorkforcePolicy
extends RefCounted

## Scheduling rules expressed over plain data so they can run headlessly.

static func role_for(worker: Dictionary, world: Dictionary) -> String:
	var manual_role := str(worker.get("manual_role", ""))
	if not manual_role.is_empty():
		return manual_role
	# Automatic work first covers essential shortages when the required workplace
	# exists, then falls back to the resident's specialization.
	var population := maxi(1, int(world.get("population", 1)))
	if bool(world.get("has_bucket", false)) and int(world.get("ponds", 0)) > 0 and int(world.get("water", 0)) < population * 2:
		return "gather_water"
	if int(world.get("food", 0)) < population * 2:
		if int(world.get("farms", 0)) > 0:
			return "farming"
		if int(world.get("forager_tents", 0)) > 0:
			return "gather_food"
	if int(world.get("wood", 0)) < population and int(world.get("sawmills", 0)) > 0 and int(world.get("trees", 0)) > 0:
		return "forestry"
	var specialization := str(worker.get("specialization", ""))
	if specialization == "builder" and int(world.get("construction_sites", 0)) > 0:
		return "construction"
	if specialization == "forestry":
		if int(world.get("sawmills", 0)) > 0:
			return "forestry"
		elif int(world.get("era", SettlementState.Era.TENT)) >= SettlementState.Era.EARTH and int(world.get("warehouses", 0)) > 0:
			return "forestry"
		else:
			return "gather_branches"
	if specialization == "farming":
		if int(world.get("farms", 0)) > 0:
			return "farming"
		elif int(world.get("forager_tents", 0)) > 0:
			return "gather_food"
		else:
			return "gather_grass"
	if specialization == "excavation" and int(world.get("dig_sites", 0)) > 0:
		return "excavation"
	
	if int(world.get("construction_sites", 0)) > 0:
		return "construction"
	return "gather_branches"


static func can_assign(worker: Dictionary, world: Dictionary) -> bool:
	if bool(worker.get("player_controlled", false)) or bool(worker.get("blocked_by_storage", false)):
		return false
	var specialization := str(worker.get("specialization", ""))
	if specialization == "courier" or int(world.get("hour", 0)) < 8:
		return false
	if specialization == "cook":
		return bool(world.get("has_canteen", false))
	if specialization == "teacher":
		return int(world.get("schools", 0)) > 0
	if specialization in ["factory_worker", "engineer"]:
		return bool(world.get("has_factory_job", false))
	if not str(worker.get("training_role", "")).is_empty() and int(worker.get("training_days_completed", 0)) < 10 and int(world.get("hour", 0)) < 12:
		return int(world.get("schools", 0)) > 0
	if specialization == "builder" and int(world.get("construction_sites", 0)) == 0 and bool(world.get("has_engineer_job", false)):
		return true
		
	match role_for(worker, world):
		"construction": return int(world.get("construction_sites", 0)) > 0
		"forestry": return int(world.get("warehouses", 0)) > 0 and int(world.get("trees", 0)) > 0
		"farming": return int(world.get("warehouses", 0)) > 0 and int(world.get("farms", 0)) > 0
		"excavation": return int(world.get("warehouses", 0)) > 0 and int(world.get("dig_sites", 0)) > 0
		"gather_branches": return int(world.get("trees", 0)) > 0
		"gather_grass": return true
		"gather_food": return int(world.get("forager_tents", 0)) > 0
		"gather_water": return bool(world.get("has_bucket", false)) and int(world.get("ponds", 0)) > 0
	return false
