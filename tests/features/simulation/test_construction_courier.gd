extends SceneTree

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const PlayerController = preload("res://game/features/citizens/presentation/player_controller.gd")
const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests construction site creation, courier delivery from piles and warehouse
## stock, workforce ordering, and reservation reconciliation.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var cell := Vector2i(12, 12)
	var position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("campfire")
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	SimHelper.create_construction_site(simulation, cell, "campfire", position, 0, blueprint, blueprint.footprint)
	assert(simulation.construction_sites.size() == 1)
	assert(SimHelper.is_construction_site(simulation, simulation.construction_sites[0].node))
	var construction_site: ConstructionSite = simulation.construction_sites[0]
	var construction_resource := str(construction_site.required_materials.keys()[0])
	var supply_worker: Citizen = simulation.citizens[2]
	supply_worker.idle()
	var logistics_worker: Citizen = simulation.citizens[3]

	# Ground piles are reserved for cleaners. Couriers must not turn a
	# construction delivery into an implicit cleaning task.
	assert(simulation.warehouse_positions.is_empty())
	SimHelper.create_resource_pile(simulation, logistics_worker.global_position, {construction_resource: 1})
	var source_pile: ResourcePileScript = simulation.resource_piles.back()
	SimHelper.assign_daily_order(simulation, logistics_worker, "courier")
	SimHelper.update_couriers(simulation)
	var pile_snapshot := SettlementAIWorldFacade.new(simulation).capture(999)
	var pile_orders := CourierDeliveryOrderProvider.new().collect_orders(pile_snapshot)
	var matching_pile_orders := pile_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery")
	assert(matching_pile_orders.is_empty())
	assert(int(source_pile.resources.get(construction_resource, 0)) == 1)
	logistics_worker.clear_daily_order()

	# Ctrl+F grants settlement stock without creating a warehouse or a pile. That
	# stock is collected from the camp entrance until a warehouse is completed.
	simulation.settlement.add(construction_resource, 1)
	SimHelper.assign_daily_order(simulation, logistics_worker, "courier")
	SimHelper.update_couriers(simulation)
	var debug_stock_snapshot := SettlementAIWorldFacade.new(simulation).capture(1000)
	var debug_stock_orders := CourierDeliveryOrderProvider.new().collect_orders(debug_stock_snapshot)
	var matching_debug_orders := debug_stock_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery")
	print("DEBUG: courier_worker=", logistics_worker.can_handle_entry_logistics(), " state=", logistics_worker.state, " is_daily_courier=", logistics_worker.is_daily_courier())
	print("DEBUG: has_active_daily_order=", logistics_worker.has_active_daily_order(), " daily_order_role=", logistics_worker.daily_order_role)
	print("DEBUG: settlement amount=", simulation.settlement.amount(construction_resource), " warehouse_positions=", simulation.warehouse_positions.size())
	print("DEBUG: courier_tasks=", debug_stock_snapshot.settlement.value(&"work.courier.tasks", []).size())
	print("DEBUG: entrance_stone valid=", is_instance_valid(simulation.entrance_stone), " campfire_node valid=", is_instance_valid(simulation.campfire_node))
	print("DEBUG: total orders=", debug_stock_orders.size(), " matching=", matching_debug_orders.size())
	var debug_tasks: Array = debug_stock_snapshot.settlement.value(&"work.courier.tasks", []) as Array
	for t in debug_tasks:
		print("DEBUG: task=", t)
	var debug_citizen := debug_stock_snapshot.citizen(logistics_worker.ai_id)
	if debug_citizen != null:
		print("DEBUG: citizen facts work.courier.worker=", debug_citizen.facts.value(&"work.courier.worker", false))
		print("DEBUG: citizen facts work.courier.can_start=", debug_citizen.facts.value(&"work.courier.can_start", false))
		print("DEBUG: citizen facts work.courier.tasks=", debug_citizen.facts.value(&"work.courier.tasks", []).size())
		print("DEBUG: citizen facts work.courier.use_personal_tasks=", debug_citizen.facts.value(&"work.courier.use_personal_tasks", false))
		print("DEBUG: citizen facts work.courier.in_progress=", debug_citizen.facts.value(&"work.courier.in_progress", false))
	print("DEBUG: citizen pos=", logistics_worker.global_position, " entrance pos=", simulation.entrance_stone.global_position)
	print("DEBUG: route citizen->entrance=", simulation.is_route_reachable(logistics_worker.global_position, simulation.entrance_stone.global_position, false))
	print("DEBUG: route entrance->site=", simulation.is_route_reachable(simulation.entrance_stone.global_position, Vector3(12, 0, 12), false))
	var debug_task_id := StringName("construction_(12, 12)_branches_open_storage_0")
	var debug_task: CourierTask = simulation.courier_dispatcher.tasks.get(debug_task_id)
	if debug_task != null:
		print("DEBUG: task pickup=", debug_task.pickup, " dropoff=", debug_task.dropoff, " kind=", debug_task.kind)
		print("DEBUG: task reachable=", simulation.courier_task_service.is_courier_task_reachable(logistics_worker, debug_task))
	assert(not matching_debug_orders.is_empty())
	var debug_stock_order: CitizenOrder = matching_debug_orders.front()
	assert(simulation.courier_dispatcher.start_task(logistics_worker, debug_stock_order.payload.value(&"courier.task_id")))
	assert(simulation.settlement.amount(construction_resource) == 0)
	logistics_worker.global_position = simulation.entrance_stone.global_position
	logistics_worker._process_construction_pickup(0.1)
	logistics_worker.global_position = logistics_worker.construction_position
	logistics_worker._process_construction_delivery(0.1)
	assert(int(construction_site.delivered_materials.get(construction_resource, 0)) == 1)
	assert(bool(construction_site.node.get_meta("can_advance", false)), "A delivered material must unblock builders immediately")
	logistics_worker.clear_daily_order()

	# With a warehouse, workforce orders exclude the supply worker (already
	# assigned to construction) and courier orders include the logistics worker.
	simulation.settlement.add(construction_resource, 1)
	var material_before: int = simulation.settlement.amount(construction_resource)
	var added_test_warehouse := false
	if simulation.warehouse_positions.is_empty():
		simulation.warehouse_positions.append(supply_worker.global_position)
		simulation.settlement.add_warehouse("warehouse")
		simulation.settlement.warehouse_ever_built = true
		simulation.settlement.add(construction_resource, 1)
		added_test_warehouse = true
	assert(SimHelper.reserve_player_gather_storage(simulation, "branches", PlayerController.HERO_GATHER_YIELD) == PlayerController.HERO_GATHER_YIELD)
	SimHelper.assign_daily_order(simulation, supply_worker, "construction")
	SimHelper.assign_daily_order(simulation, logistics_worker, "courier")
	SimHelper.update_couriers(simulation)
	var construction_snapshot := SettlementAIWorldFacade.new(simulation).capture(1000)
	var workforce_orders := WorkforceOrderProvider.new().collect_orders(construction_snapshot)
	assert(workforce_orders.all(func(order: CitizenOrder): return order.citizen_id != supply_worker.ai_id))
	var courier_orders := CourierDeliveryOrderProvider.new().collect_orders(construction_snapshot)
	assert(courier_orders.any(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery"))
	logistics_worker.clear_daily_order()
	supply_worker.clear_daily_order()
	if added_test_warehouse:
		simulation.warehouse_positions.clear()
		simulation.settlement.warehouses.clear()
		simulation.settlement.warehouse_types.clear()
		simulation.settlement.warehouse_ever_built = false

	# Dispatcher reservation/reconciliation path for construction supply.
	SimHelper.assign_daily_order(simulation, logistics_worker, "courier")
	SimHelper.update_couriers(simulation)
	var final_snapshot := SettlementAIWorldFacade.new(simulation).capture(1001)
	var final_orders := CourierDeliveryOrderProvider.new().collect_orders(final_snapshot)
	var final_order: Variant = final_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery").front()
	assert(final_order != null)
	assert(simulation.courier_dispatcher.start_task(logistics_worker, final_order.payload.value(&"courier.task_id")))
	assert(simulation.settlement.amount(construction_resource) == material_before - 1)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 1)
	logistics_worker.idle()
	SimHelper.reconcile_construction_reservations(simulation, construction_site)
	assert(simulation.settlement.amount(construction_resource) == material_before)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 0)
	logistics_worker.clear_daily_order()
	assert(simulation.construction.cancel_site(simulation.construction_sites[0].node))
	assert(simulation.construction_sites.is_empty())
	assert(simulation.building_registry.record_at_cell(cell) == null)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
