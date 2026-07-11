class_name WorkforceCoordinator
extends Node

## Schedules citizens while keeping scene-specific state behind MainSimulation's API.
## This is intentionally a Node so it can later own timers, signals and debug UI.

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func update_workers() -> void:
	if simulation._is_night():
		for citizen in simulation.citizens:
			citizen.request_goap_decision()
		return
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY, Citizen.State.COURIER_TO_WORKER, Citizen.State.COURIER_TO_WAREHOUSE, Citizen.State.WAITING_COURIER]:
			continue
		if citizen.blocked_by_storage:
			if simulation._stored_resources() >= simulation._warehouse_capacity():
				continue
			citizen.blocked_by_storage = false
		citizen.request_goap_decision()


func can_assign_work(citizen: Citizen) -> bool:
	if citizen.is_player_controlled or citizen.blocked_by_storage:
		return false
	if citizen.specialization == "courier":
		return false
	if int(simulation.game_minutes) / 60 < 8:
		return false
	if citizen.specialization == "cook":
		return is_instance_valid(simulation.canteen)
	if citizen.specialization == "teacher":
		return not simulation.school_positions.is_empty()
	if citizen.specialization == "factory_worker":
		return factory_for_role("factory_worker") != null
	if citizen.specialization == "engineer":
		return factory_for_role("engineer") != null
	if not citizen.training_role.is_empty() and citizen.training_days_completed < 10 and int(simulation.game_minutes) / 60 < 12:
		return not simulation.school_positions.is_empty()
	if citizen.specialization == "builder" and simulation.construction_sites.is_empty() and factory_for_role("engineer") != null:
		return true
	match work_role_for(citizen):
		"construction": return not simulation.construction_sites.is_empty()
		"forestry": return not simulation.warehouse_positions.is_empty() and not simulation.sawmill_positions.is_empty() and not simulation.tree_positions.is_empty()
		"farming": return not simulation.warehouse_positions.is_empty() and not simulation.farm_positions.is_empty()
		"excavation": return not simulation.dig_sites.is_empty() and not simulation.warehouse_positions.is_empty()
	return false


func assign_work(citizen: Citizen, index: int) -> void:
	if not can_assign_work(citizen):
		return
	if citizen.specialization == "cook":
		citizen.assign_canteen_work(simulation.canteen_position)
		return
	if citizen.specialization == "teacher":
		citizen.assign_teacher_work(simulation.school_positions[0])
		return
	if citizen.specialization == "factory_worker":
		citizen.assign_factory_work(factory_for_role("factory_worker"), "factory_work")
		return
	if citizen.specialization == "engineer":
		citizen.assign_factory_work(factory_for_role("engineer"), "engineering")
		return
	if not citizen.training_role.is_empty() and citizen.training_days_completed < 10 and int(simulation.game_minutes) / 60 < 12:
		citizen.attend_school()
		return
	if citizen.specialization == "builder" and simulation.construction_sites.is_empty():
		var materials_plant := factory_for_role("engineer")
		if materials_plant != null:
			citizen.assign_factory_work(materials_plant, "construction")
			return
	match work_role_for(citizen):
		"construction":
			var construction: Dictionary = simulation.construction_sites[index % simulation.construction_sites.size()]
			citizen.assign_construction(construction.node)
		"forestry":
			var sawmill_position: Vector3 = simulation.sawmill_positions[index % simulation.sawmill_positions.size()]
			var tree_position: Vector3 = simulation._reserve_closest_tree_for_sawmill(citizen, sawmill_position)
			if tree_position != Vector3.INF:
				citizen.assign_work("wood", tree_position, sawmill_position, simulation.warehouse_positions[index % simulation.warehouse_positions.size()])
		"farming":
			var farm_position: Vector3 = simulation.farm_positions[index % simulation.farm_positions.size()]
			citizen.assign_work("food", farm_position, farm_position, simulation.warehouse_positions[index % simulation.warehouse_positions.size()], simulation._has_courier())
		"excavation":
			var dig_site := citizen.assigned_dig_site
			if not is_instance_valid(dig_site):
				var excavation: Dictionary = simulation.dig_sites[index % simulation.dig_sites.size()]
				dig_site = excavation.node
			citizen.assign_excavation(dig_site)


func work_role_for(citizen: Citizen) -> String:
	if not citizen.manual_role.is_empty():
		return citizen.manual_role
	if citizen.specialization == "builder" and not simulation.construction_sites.is_empty():
		return "construction"
	if citizen.specialization == "forestry" and not simulation.sawmill_positions.is_empty():
		return "forestry"
	if citizen.specialization == "farming" and not simulation.farm_positions.is_empty():
		return "farming"
	if citizen.specialization == "excavation" and not simulation.dig_sites.is_empty():
		return "excavation"
	return ""


func factory_for_role(role: String) -> Node3D:
	if role == "factory_worker":
		for building_type in ["materials_factory", "brick_factory", "recycling_factory", "metal_factory"]:
			for factory in simulation.factories:
				if factory.get_meta("building_type", "") != building_type:
					continue
				var assigned_workers := 0
				for citizen in simulation.citizens:
					assigned_workers += 1 if simulation._is_factory_worker_active(citizen, factory) else 0
				if assigned_workers < int(factory.get_meta("required_factory_workers", 1)):
					return factory
	for factory in simulation.factories:
		if not is_instance_valid(factory):
			continue
		var building_type: String = factory.get_meta("building_type", "")
		if role == "factory_worker" and building_type in ["brick_factory", "materials_factory", "recycling_factory", "metal_factory"]:
			return factory
		if role == "engineer" and building_type == "materials_factory":
			return factory
	return null
