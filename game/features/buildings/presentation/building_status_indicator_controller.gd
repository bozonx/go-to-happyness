class_name BuildingStatusIndicatorController
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func update_building_status_indicators(delta: float) -> void:
	if simulation == null:
		return
	simulation.building_status_update_time -= delta
	if simulation.building_status_update_time > 0.0:
		return
	simulation.building_status_update_time = 0.5
	for indicator in simulation.building_status_indicators:
		if not is_instance_valid(indicator):
			continue
		var building := indicator.get_parent() as Node3D
		if not is_instance_valid(building):
			continue
		var required: Dictionary = required_staff_for_building(building)
		if required.is_empty():
			indicator.visible = false
			continue
		var assigned: int = assigned_staff_for_building(building, required)
		indicator.visible = assigned < int(required.count)
		indicator.text = "NO WORKER" if assigned == 0 else "STAFF %d/%d" % [assigned, int(required.count)]
		indicator.modulate = Color("ef6b5b") if assigned == 0 else Color("f0c45d")


func required_staff_for_building(building: Node3D) -> Dictionary:
	match simulation.building_registry.building_type_for_node(building):
		"sawmill": return {"role": "forestry", "count": 1}
		"farm": return {"role": "farming", "count": 1}
		"forager_tent", "straw_forager_tent": return {"role": "gather_food", "count": 2}
		"tarp_forager_tent": return {"role": "gather_food", "count": 4}
		"materials_yard", "straw_materials_yard": return {"role": "gather_branches", "count": 2}
		"tarp_materials_yard": return {"role": "gather_branches", "count": 4}
		"cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3", "dugout_kitchen", "clay_bakery", "canteen", "stone_tavern", "brick_restaurant": return {"role": "cooking", "count": 1}
		"school": return {"role": "teaching", "count": 1}
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory": return {"role": "factory_worker", "count": int(building.get_meta("required_factory_workers", 1))}
	return {}


func assigned_staff_for_building(building: Node3D, required: Dictionary) -> int:
	var count := 0
	var role: String = required.role
	for citizen in simulation.citizens:
		if role == "cooking" and citizen.active_role == "cooking":
			count += 1
		elif role == "teaching" and citizen.active_role == "teaching":
			count += 1
		elif role == "factory_worker" and citizen.factory == building and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
			count += 1
		elif role == "forestry" and citizen.active_role == "forestry":
			count += 1
		elif role == "farming" and citizen.active_role == "farming":
			count += 1
		elif role == "gather_food" and citizen.active_role == "gather_food":
			count += 1
	return count
