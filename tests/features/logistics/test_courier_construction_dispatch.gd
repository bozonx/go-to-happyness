extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame

	var campfire_cell := Vector2i(12, 12)
	var campfire_position := Vector3(12.0, 0.0, 12.0)
	var campfire_blueprint := BuildingBlueprints.get_blueprint("campfire")
	simulation.building_registry.reserve(campfire_cell, campfire_position, campfire_blueprint.footprint)
	simulation._create_construction_site(campfire_cell, "campfire", campfire_position, 0, campfire_blueprint, campfire_blueprint.footprint)

	var tent_cell := Vector2i(14, 14)
	var tent_position := Vector3(14.0, 0.0, 14.0)
	var tent_blueprint := BuildingBlueprints.get_blueprint("tent")
	simulation.building_registry.reserve(tent_cell, tent_position, tent_blueprint.footprint)
	simulation._create_construction_site(tent_cell, "tent", tent_position, 0, tent_blueprint, tent_blueprint.footprint)

	assert(simulation.construction_sites.size() == 2)

	# Keep two storages so task identity and source selection are exercised. The
	# nearest source is removed below to emulate demolition or a blocked route.
	var nearest_warehouse := Vector3(11.0, 0.0, 10.0)
	var fallback_warehouse := Vector3.ZERO
	simulation.warehouse_positions.append(nearest_warehouse)
	simulation.warehouse_positions.append(fallback_warehouse)
	simulation.settlement.add_warehouse("warehouse")
	simulation.settlement.add_warehouse("warehouse")
	simulation.settlement.warehouse_ever_built = true
	# Stock enough physical warehouse resources for both sites to need deliveries.
	simulation.settlement.add("branches", 20)
	simulation.settlement.add("grass", 20)

	simulation._update_couriers()
	var construction_tasks: Array[CourierTask] = simulation.courier_dispatcher.available_tasks().filter(
		func(task: CourierTask) -> bool: return task.kind == CourierTask.Kind.CONSTRUCTION
	)
	assert(not construction_tasks.is_empty(), "Expected a construction task for the focused site")
	for task in construction_tasks:
		var task_site: ConstructionSite = task.payload.get("site") as ConstructionSite
		assert(task_site != null and task_site.node == simulation.construction_sites[0].node, "Construction deliveries must stay focused on the builder's current project")
		assert(task.pickup == nearest_warehouse, "Construction task should use the nearest warehouse")
	var branch_tasks := construction_tasks.filter(
		func(task: CourierTask) -> bool: return str(task.payload.get("resource", "")) == "branches"
	)
	assert(branch_tasks.size() >= 2, "A construction load larger than one courier capacity must publish parallel delivery tasks")

	# An unassigned task must follow the physical stock when another warehouse is
	# closer but empty.
	for resource_type in ["branches", "grass"]:
		var stored: int = simulation.settlement.warehouse_amount(resource_type, 0)
		simulation.settlement.warehouses[0].set_amount(resource_type, 0)
		simulation.settlement.warehouses[1].set_amount(resource_type, stored)
	simulation._update_couriers()
	construction_tasks = simulation.courier_dispatcher.available_tasks().filter(
		func(task: CourierTask) -> bool: return task.kind == CourierTask.Kind.CONSTRUCTION
	)
	assert(not construction_tasks.is_empty(), "Expected a replacement construction task after stock moved")
	for task in construction_tasks:
		assert(task.pickup == fallback_warehouse, "Construction task should use a warehouse that contains the material")

	# Removing the empty warehouse must preserve the task for the remaining source.
	simulation.warehouse_positions.remove_at(0)
	simulation.settlement.warehouses.remove_at(0)
	simulation.settlement.warehouse_types.remove_at(0)
	simulation._update_couriers()
	construction_tasks = simulation.courier_dispatcher.available_tasks().filter(
		func(task: CourierTask) -> bool: return task.kind == CourierTask.Kind.CONSTRUCTION
	)
	assert(not construction_tasks.is_empty(), "Expected a replacement construction task after the source warehouse changed")
	for task in construction_tasks:
		assert(task.pickup == fallback_warehouse, "Construction task should be republished for the remaining warehouse")

	# Dispatch must result in an actual stock-to-site delivery, not merely a task
	# visible to the director. Keep a single daily courier idle at the warehouse
	# so the full order/goal/actuator route is exercised.
	var courier: Citizen = simulation.citizens[0]
	courier.global_position = fallback_warehouse
	courier.idle()
	courier.set_courier_equipment("reinforced_backpack")
	simulation._assign_daily_order(courier, "courier")
	var branch_delivery_completed := false
	for _frame in range(1200):
		await physics_frame
		var campfire_site: ConstructionSite = simulation.construction.site_for_node(simulation.construction_sites[0].node)
		if campfire_site != null and int(campfire_site.delivered_materials.get("branches", 0)) > 0:
			branch_delivery_completed = true
			break
	assert(branch_delivery_completed, "Courier should deliver a construction material from the warehouse to the site")
	var campfire_site: ConstructionSite = simulation.construction.site_for_node(simulation.construction_sites[0].node)
	assert(int(campfire_site.delivered_materials.get("branches", 0)) == courier.courier_capacity(), "Construction delivery should use the courier's carrying capacity")

	root.remove_child(simulation)
	simulation.free()
	quit(0)
