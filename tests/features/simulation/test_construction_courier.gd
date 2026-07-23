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
	simulation._create_construction_site(cell, "campfire", position, 0, blueprint, blueprint.footprint)
	assert(simulation.construction_sites.size() == 1)
	assert(simulation._is_construction_site(simulation.construction_sites[0].node))
	var construction_site: ConstructionSite = simulation.construction_sites[0]
	var construction_resource := str(construction_site.required_materials.keys()[0])
	var supply_worker: Citizen = simulation.citizens[2]
	supply_worker.idle()
	var logistics_worker: Citizen = simulation.citizens[3]

	# Ground piles are reserved for cleaners. Couriers must not turn a
	# construction delivery into an implicit cleaning task.
	assert(simulation.warehouse_positions.is_empty())
	simulation._create_resource_pile(logistics_worker.global_position, {construction_resource: 1})
	var source_pile: ResourcePileScript = simulation.resource_piles.back()
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var pile_snapshot := SettlementAIWorldFacade.new(simulation).capture(999)
	var pile_orders := CourierDeliveryOrderProvider.new().collect_orders(pile_snapshot)
	var matching_pile_orders := pile_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery")
	assert(matching_pile_orders.is_empty())
	assert(int(source_pile.resources.get(construction_resource, 0)) == 1)
	logistics_worker.clear_daily_order()

	# Ctrl+F grants settlement stock without creating a warehouse or a pile. That
	# stock is collected from the camp entrance until a warehouse is completed.
	simulation.settlement.add(construction_resource, 1)
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var debug_stock_snapshot := SettlementAIWorldFacade.new(simulation).capture(1000)
	var debug_stock_orders := CourierDeliveryOrderProvider.new().collect_orders(debug_stock_snapshot)
	var matching_debug_orders := debug_stock_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery")
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
	assert(simulation._reserve_player_gather_storage("branches", PlayerController.HERO_GATHER_YIELD) == PlayerController.HERO_GATHER_YIELD)
	simulation._assign_daily_order(supply_worker, "construction")
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
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
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var final_snapshot := SettlementAIWorldFacade.new(simulation).capture(1001)
	var final_orders := CourierDeliveryOrderProvider.new().collect_orders(final_snapshot)
	var final_order: Variant = final_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery").front()
	assert(final_order != null)
	assert(simulation.courier_dispatcher.start_task(logistics_worker, final_order.payload.value(&"courier.task_id")))
	assert(simulation.settlement.amount(construction_resource) == material_before - 1)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 1)
	logistics_worker.idle()
	simulation._reconcile_construction_reservations(construction_site)
	assert(simulation.settlement.amount(construction_resource) == material_before)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 0)
	logistics_worker.clear_daily_order()
	assert(simulation.construction.cancel_site(simulation.construction_sites[0].node))
	assert(simulation.construction_sites.is_empty())
	assert(simulation.building_registry.record_at_cell(cell) == null)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
