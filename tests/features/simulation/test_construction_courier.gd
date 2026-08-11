extends SceneTree

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")
const PlayerController = preload("res://game/features/citizens/presentation/player_controller.gd")
const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests construction site creation, courier delivery from piles and warehouse
## stock, workforce ordering, and reservation reconciliation.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var cell := Vector2i(10, 10)
	var position := Vector3(10.5, 0.0, 10.5)
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

	# Construction logistics may consume a nearby ground pile directly. This is
	# different from generic cleaning: only the exact required resource is taken.
	assert(simulation.warehouse_positions.is_empty())
	SimHelper.create_resource_pile(simulation, position + Vector3(0.25, 0.0, 0.0), {construction_resource: 1})
	var source_pile: ResourcePileScript = simulation.resource_piles.back()
	SimHelper.assign_daily_order(simulation, logistics_worker, "courier")
	SimHelper.update_couriers(simulation)
	var pile_tasks: Array[CourierTask] = simulation.courier_dispatcher.available_tasks().filter(func(task: CourierTask) -> bool:
		return task.kind == CourierTask.Kind.CONSTRUCTION and task.pickup == source_pile.node.global_position)
	assert(not pile_tasks.is_empty())
	logistics_worker.global_position = source_pile.node.global_position
	assert(simulation.courier_task_service.start_courier_construction_or_supply(logistics_worker, pile_tasks.front()))
	logistics_worker._process_construction_pickup(0.1)
	logistics_worker.global_position = logistics_worker.construction_position
	logistics_worker._process_construction_delivery(0.1)
	assert(int(source_pile.resources.get(construction_resource, 0)) == 0)
	assert(int(construction_site.delivered_materials.get(construction_resource, 0)) == 1)
	assert(bool(construction_site.node.get_meta("can_advance", false)), "A pile delivery must unblock builders immediately")
	logistics_worker.clear_daily_order()

	# With a warehouse, workforce orders exclude the supply worker (already
	# assigned to construction) and courier orders include the logistics worker.
	simulation.settlement.add(construction_resource, 1)
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
	assert(simulation.courier_dispatcher.available_tasks().any(func(task: CourierTask) -> bool: return task.kind == CourierTask.Kind.CONSTRUCTION))
	logistics_worker.clear_daily_order()
	supply_worker.clear_daily_order()
	if added_test_warehouse:
		simulation.warehouse_positions.clear()
		simulation.settlement.warehouses.clear()
		simulation.settlement.warehouse_types.clear()
		simulation.settlement.warehouse_ever_built = false

	# Reconciliation returns orphaned cargo exactly once when no courier owns it.
	var before_orphan: int = simulation.settlement.amount(construction_resource)
	simulation.settlement.add(construction_resource, -1)
	construction_site.reserved_materials[construction_resource] = 1
	SimHelper.reconcile_construction_reservations(simulation, construction_site)
	assert(simulation.settlement.amount(construction_resource) == before_orphan)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 0)
	logistics_worker.clear_daily_order()
	assert(simulation.construction.cancel_site(simulation.construction_sites[0].node))
	assert(simulation.construction_sites.is_empty())
	assert(simulation.building_registry.record_at_cell(cell) == null)

	await SimHelper.cleanup_simulation(self, simulation)
	quit(0)
