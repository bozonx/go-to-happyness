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
		_ensure_home(citizen)
		if citizen.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY, Citizen.State.COURIER_TO_WORKER, Citizen.State.COURIER_TO_WAREHOUSE, Citizen.State.WAITING_COURIER]:
			continue
		if citizen.blocked_by_storage:
			if not simulation.settlement.reserve_storage_room_for(citizen.resource_type, maxi(1, citizen.carried_amount), simulation.warehouse_positions.size()):
				simulation._send_citizen_to_leisure(citizen)
				continue
			citizen.blocked_by_storage = false
		if can_assign_work(citizen):
			citizen.request_goap_decision()
		else:
			simulation._send_citizen_to_leisure(citizen)


func can_assign_work(citizen: Citizen) -> bool:
	if not WorkforcePolicy.can_assign(_worker_data(citizen), _world_data()):
		return false
	return simulation._has_storage_room_for_role(work_role_for(citizen))


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
		if not simulation.demolition_sites.is_empty():
			citizen.assign_demolition(simulation.demolition_sites[index % simulation.demolition_sites.size()].building)
			return
		var materials_plant := factory_for_role("engineer")
		if materials_plant != null:
			citizen.assign_factory_work(materials_plant, "construction")
			return
	match work_role_for(citizen):
		"construction":
			if not simulation.demolition_sites.is_empty():
				citizen.assign_demolition(simulation.demolition_sites[index % simulation.demolition_sites.size()].building)
			elif not simulation.construction_sites.is_empty():
				var construction: Dictionary = simulation.construction_sites[index % simulation.construction_sites.size()]
				citizen.assign_construction(construction.node)
		"forestry":
			var tree_position: Vector3 = simulation._reserve_closest_tree_for_sawmill(citizen, Vector3.ZERO)
			if tree_position != Vector3.INF:
				if simulation.sawmill_positions.is_empty():
					citizen.assign_gathering("logs", tree_position, simulation._get_delivery_position())
				else:
					var sawmill_position: Vector3 = simulation.sawmill_positions[index % simulation.sawmill_positions.size()]
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
		"gather_branches":
			var tree_pos: Vector3 = simulation._find_closest_tree_for_citizen(citizen)
			if tree_pos != Vector3.INF:
				citizen.assign_gathering("branches", tree_pos, simulation._get_delivery_position())
			else:
				citizen.idle()
		"gather_grass":
			var grass_pos: Vector3 = simulation._find_grass_gathering_position(citizen)
			citizen.assign_gathering("grass", grass_pos, simulation._get_delivery_position())
		"gather_food":
			var forage_pos: Vector3 = simulation._find_forage_position(citizen)
			if forage_pos != Vector3.INF:
				citizen.assign_gathering("food", forage_pos, simulation._get_delivery_position())
			else:
				citizen.idle()


func work_role_for(citizen: Citizen) -> String:
	return WorkforcePolicy.role_for(_worker_data(citizen), _world_data())


func _worker_data(citizen: Citizen) -> Dictionary:
	return {
		"player_controlled": citizen.is_player_controlled,
		"blocked_by_storage": citizen.blocked_by_storage,
		"specialization": citizen.specialization,
		"manual_role": citizen.manual_role,
		"training_role": citizen.training_role,
		"training_days_completed": citizen.training_days_completed,
	}


func _world_data() -> Dictionary:
	return {
		"era": simulation.settlement.era,
		"hour": int(simulation.game_minutes) / 60,
		"has_canteen": is_instance_valid(simulation.canteen),
		"schools": simulation.school_positions.size(),
		"construction_sites": simulation.construction_sites.size() + simulation.demolition_sites.size(),
		"warehouses": simulation.warehouse_positions.size(),
		"sawmills": simulation.sawmill_positions.size(),
		"trees": simulation.tree_positions.size(),
		"farms": simulation.farm_positions.size(),
		"forager_tents": simulation.forager_positions.size(),
		"dig_sites": simulation.dig_sites.size(),
		"has_factory_job": factory_for_role("factory_worker") != null,
		"has_engineer_job": factory_for_role("engineer") != null,
		"food": simulation.food,
		"wood": simulation.wood,
		"population": simulation.citizens.size(),
	}

func _ensure_home(citizen: Citizen) -> void:
	if is_instance_valid(citizen.home):
		return
	for record in simulation.building_footprints:
		var home: Node3D = record.node
		if not is_instance_valid(home) or int(home.get_meta("spawn_slots", 0)) <= 0:
			continue
		citizen.assign_home(home)
		home.set_meta("spawn_slots", int(home.get_meta("spawn_slots", 0)) - 1)
		return


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
