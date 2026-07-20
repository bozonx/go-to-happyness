class_name TestDomainLogistics
extends RefCounted

const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const CitizenLivingStatusServiceScript = preload("res://game/features/citizens/application/citizen_living_status_service.gd")
const CanteenServiceScript = preload("res://game/features/logistics/application/canteen_service.gd")
const StorageDeliveryServiceScript = preload("res://game/features/logistics/application/storage_delivery_service.gd")
const TradeServiceScript = preload("res://game/features/logistics/application/trade_service.gd")
const TradeOrderScript = preload("res://game/features/logistics/domain/trade_order.gd")
const WaterCollectorServiceScript = preload("res://game/features/logistics/application/water_collector_service.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")


class FakeCanteenSimulation extends Node:
	var canteen: Node3D
	var citizens: Array[Citizen] = []
	var canteen_food := 2
	var last_interface_message := ""
	var workers_updated := false
	var fire_lit := true
	var has_cook := true

	func _is_fire_lit(_canteen: Node3D) -> bool:
		return fire_lit

	func _has_cook() -> bool:
		return has_cook

	func _update_interface(message: String) -> void:
		last_interface_message = message

	func _is_work_time() -> bool:
		return true

	func _update_workers() -> void:
		workers_updated = true


class FakeCourierDispatcher extends RefCounted:
	var completed := 0

	func complete_for(_worker: Citizen) -> void:
		completed += 1

	func task_for(_worker: Citizen) -> RefCounted:
		return null


class FakeStorageSimulation extends Node:
	var settlement := SettlementState.new()
	var warehouse_positions: Array[Vector3] = []
	var courier_dispatcher := FakeCourierDispatcher.new()
	var last_interface_message := ""
	var dispatch_requested := false
	var leisure_worker: Citizen
	var dropped_piles: Array[Dictionary] = []

	func _update_interface(message: String) -> void:
		last_interface_message = message

	func _request_courier_dispatch() -> void:
		dispatch_requested = true

	func _send_citizen_to_leisure(worker: Citizen) -> void:
		leisure_worker = worker

	func _drop_resource_pile(position: Vector3, resource_type: String, amount: int) -> void:
		dropped_piles.append({"position": position, "resource_type": resource_type, "amount": amount})


class FakeTradeSimulation extends Node:
	var queued_trades: Array = []
	var pending_trades: Dictionary = {}
	var total_minutes := 0.0
	var last_interface_message := ""

	func _total_game_minutes() -> float:
		return total_minutes

	func _update_interface(message: String) -> void:
		last_interface_message = message


class FakeWaterCollectorSimulation extends Node:
	var water_collectors: Array[Dictionary] = []


static func run_all() -> void:
	_test_citizen_task_state()
	_test_citizen_state_display_queue()
	_test_citizen_work_position_lock()
	_test_canteen_meal_requests()
	_test_canteen_raw_rations()
	_test_no_canteen_raw_rations()
	_test_courier_metadata()
	_test_construction_delivery_stays_scheduled()
	_test_daily_order_role_recheck_cooldown()
	_test_courier_equipment_capacity()
	_test_trade_order_model()
	_test_trade_service_entrance_expedition_walks_to_sign_before_departure()
	_test_fire_source_state()
	_test_citizen_status_effects()
	_test_storage_delivery_service()
	_test_citizen_living_status_service()
	_test_water_collector_service()
	_test_warehouse_reservation_at_assignment()
	_test_balanced_warehouse_mode()
	_test_backpack_invariants()
	_test_warehouse_cheat_respects_accept_filters()
	_test_dump_preserves_warehouse_accept_filters()
	_test_warehouse_accept_toggle_persists_after_refresh()


static func _test_citizen_task_state() -> void:
	var task := CitizenTaskState.new()
	task.start(1.0)
	assert(not task.advance(0.4))
	assert(task.advance(0.6))


static func _test_citizen_state_display_queue() -> void:
	var citizen := Citizen.new()
	citizen.state = Citizen.State.TO_TREE
	citizen.state = Citizen.State.CHOPPING
	assert(citizen._displayed_state == Citizen.State.IDLE)
	citizen._advance_state_display(1.0)
	assert(citizen._displayed_state == Citizen.State.CHOPPING)
	citizen._advance_state_display(0.99)
	assert(citizen._displayed_state == Citizen.State.CHOPPING)
	citizen.state = Citizen.State.TO_SAWMILL
	citizen._advance_state_display(0.01)
	assert(citizen._displayed_state == Citizen.State.TO_SAWMILL)
	citizen.free()


static func _test_citizen_work_position_lock() -> void:
	var building := Node3D.new()
	building.position = Vector3(10.0, 0.0, 10.0)

	var player := Citizen.new()
	player.is_player_controlled = true
	player.state = Citizen.State.IDLE
	player.enter_work_position(Vector3(1.0, 0.0, 1.0), "researcher", building, true)
	assert(player.work_position_locked)
	assert(player.state == Citizen.State.WORK_POSITION)
	assert(player.work_position_role == "researcher")
	assert(player.work_position_node == building)
	assert(player.work_position_temporary)
	player.exit_work_position()
	assert(not player.work_position_locked)
	assert(player.state == Citizen.State.IDLE)
	player.free()

	var ai := Citizen.new()
	ai.is_player_controlled = false
	ai.state = Citizen.State.AI_MOVING
	ai.active_role = "teacher"
	ai.enter_work_position(Vector3(2.0, 0.0, 2.0), "teacher", building, true, false)
	assert(ai.work_position_locked)
	assert(ai.state == Citizen.State.AI_MOVING)
	ai.exit_work_position()
	assert(not ai.work_position_locked)
	assert(ai.state == Citizen.State.AI_MOVING)
	assert(ai.active_role == "teacher")
	ai.free()

	building.free()


static func _test_canteen_meal_requests() -> void:
	var simulation := FakeCanteenSimulation.new()
	simulation.canteen = Node3D.new()
	var citizen := Citizen.new()
	citizen.ai_id = 42
	simulation.citizens.append(citizen)
	var service := CanteenServiceScript.new()
	service.configure(simulation)

	service.start_meal(13)
	assert(service.is_meal_requested(citizen.ai_id))
	assert(simulation.last_interface_message.contains("meal service started"))

	service.on_meal_finished(citizen)
	assert(not service.is_meal_requested(citizen.ai_id))
	assert(simulation.canteen_food == 1)
	assert(simulation.workers_updated)

	service.start_meal(13)
	assert(service.is_meal_requested(citizen.ai_id))
	service.remove_citizen(citizen.ai_id)
	assert(not service.is_meal_requested(citizen.ai_id))
	citizen.free()
	simulation.canteen.free()
	simulation.free()


static func _test_canteen_raw_rations() -> void:
	var simulation := FakeCanteenSimulation.new()
	simulation.canteen = Node3D.new()
	simulation.has_cook = false
	var citizen := Citizen.new()
	citizen.ai_id = 42
	citizen.hunger = 50.0
	simulation.citizens.append(citizen)
	var service := CanteenServiceScript.new()
	service.configure(simulation)

	service.start_meal(13)
	assert(service.is_meal_requested(citizen.ai_id))
	assert(simulation.last_interface_message.contains("raw rations"))

	service.on_meal_finished(citizen)
	assert(simulation.canteen_food == 1)
	assert(is_equal_approx(citizen.hunger, 67.5))
	citizen.free()
	simulation.canteen.free()
	simulation.free()


static func _test_no_canteen_raw_rations() -> void:
	var simulation := FakeCanteenSimulation.new()
	var citizen := Citizen.new()
	citizen.ai_id = 42
	citizen.hunger = 50.0
	simulation.citizens.append(citizen)
	var service := CanteenServiceScript.new()
	service.configure(simulation)

	service.start_meal(13)
	assert(not service.is_meal_requested(citizen.ai_id))
	assert(simulation.last_interface_message.contains("raw rations from stores"))
	assert(is_equal_approx(citizen.hunger, 67.5))
	citizen.free()
	simulation.free()


static func _test_courier_metadata() -> void:
	var citizen := Citizen.new()
	var courier_target := Citizen.new()
	citizen.courier_target = courier_target

	assert(not courier_target.has_meta("last_courier_pickup"))

	var _cargo: Dictionary = courier_target.take_pending_resource()
	courier_target.set_meta("last_courier_pickup", 100.0)

	assert(float(courier_target.get_meta("last_courier_pickup")) == 100.0)

	citizen.free()
	courier_target.free()


static func _test_construction_delivery_stays_scheduled() -> void:
	var courier := Citizen.new()
	courier.state = Citizen.State.TO_CONSTRUCTION_PICKUP
	courier.carried_amount = 1
	assert(courier.has_active_delivery())
	assert(not courier.is_available_for_schedule())
	courier.state = Citizen.State.TO_CONSTRUCTION_SITE
	assert(courier.has_active_delivery())
	assert(not courier.is_available_for_schedule())
	var home := Node3D.new()
	courier.home = home
	courier.go_home()
	assert(courier.state == Citizen.State.TO_CONSTRUCTION_SITE)
	courier.go_to_canteen(Vector3.ZERO)
	assert(courier.state == Citizen.State.TO_CONSTRUCTION_SITE)
	courier.construction_delivery_resource = "branches"
	courier.cancel_current_action()
	assert(courier.state == Citizen.State.IDLE)
	assert(courier.carried_amount == 0)
	assert(courier.construction_delivery_resource.is_empty())
	assert(not courier.has_active_delivery())
	home.free()
	courier.free()


static func _test_daily_order_role_recheck_cooldown() -> void:
	var worker := Citizen.new()
	worker.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	worker.begin_role_recheck_cooldown()
	assert(worker.role_recheck_remaining >= Citizen.ROLE_RECHECK_MIN_DELAY)
	assert(worker.role_recheck_remaining <= Citizen.ROLE_RECHECK_MAX_DELAY)
	assert(not worker.can_recheck_idle_work())
	worker.free()


static func _test_courier_equipment_capacity() -> void:
	var courier := Citizen.new()
	courier.set_courier_equipment("reinforced_backpack")
	assert(courier.courier_capacity() == 4)
	courier.register_pending_resource("boards", 6)
	var cargo: Dictionary = courier.take_pending_resource(courier.courier_capacity())
	assert(int(cargo.amount) == 4)
	assert(int(courier.pending_resources.boards) == 2)
	courier.free()


static func _test_trade_order_model() -> void:
	var order := TradeOrderScript.entrance_purchase(
		{"kind": "buy_resource", "resource": "food", "quantity": 4, "price": 2},
		Vector3(1.0, 0.0, 0.0),
		Vector3(5.0, 0.0, 0.0)
	)
	assert(order.source_endpoint == TradeOrderScript.ENDPOINT_ENTRANCE_STONE)
	assert(order.destination_endpoint == TradeOrderScript.ENDPOINT_STORAGE)
	assert(order.outside_duration_minutes == 120.0)
	assert(order.reserved_money() == 8)
	assert(order.incoming_resource("food") == 4)
	assert(order.incoming_resource("grass") == 0)


static func _test_trade_service_entrance_expedition_walks_to_sign_before_departure() -> void:
	var simulation := FakeTradeSimulation.new()
	var service := TradeServiceScript.new()
	service.configure(simulation)
	var worker := Citizen.new()
	worker.position = Vector3(12.0, 0.0, 0.0)
	var entrance := Vector3(-22.5, 0.0, 1.5)
	var storage := Vector3(2.5, 0.0, 0.5)
	var order := TradeOrderScript.entrance_purchase(
		{"kind": "buy_resource", "resource": "food", "quantity": 4, "price": 2},
		entrance,
		storage
	)

	service.assign_order_to_worker(worker, order)
	assert(simulation.pending_trades.has(worker.get_instance_id()))
	assert(worker.position == Vector3(12.0, 0.0, 0.0))
	assert(worker.state == Citizen.State.TO_TRADE_PICKUP)
	assert(worker.trade_source_position == entrance)
	assert(worker.trade_destination_position == entrance)

	service.on_trade_delivery_finished(worker)
	assert(simulation.pending_trades.has(worker.get_instance_id()))
	assert(service.entrance_expeditions.has(worker.get_instance_id()))
	assert(not worker.visible)
	assert(worker.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(order.return_at_minutes == order.outside_duration_minutes)
	worker.free()
	simulation.free()


static func _test_fire_source_state() -> void:
	var fire := FireSourceStateScript.from_values(1, 0, true)
	assert(fire.total_committed_fuel() == 1)
	assert(fire.needs_supply(4))
	assert(fire.phase_at(0) == FireSourceStateScript.Phase.DYING)
	fire.reserve(2)
	assert(fire.total_committed_fuel() == 3)
	fire.add_delivered(2, 0)
	assert(fire.fuel == 3 and fire.reserved_fuel == 0 and fire.lit)
	fire.consume(3, 240)
	assert(fire.fuel == 0 and not fire.lit)
	assert(fire.phase_at(241) == FireSourceStateScript.Phase.EMBERS)
	fire.add_delivered(1, 241)
	assert(fire.lit and fire.phase_at(241) == FireSourceStateScript.Phase.DYING)
	var exhausted_fire := FireSourceStateScript.from_values(0, 0, false, 360)
	assert(exhausted_fire.phase_at(360) == FireSourceStateScript.Phase.OUT)


static func _test_citizen_status_effects() -> void:
	var citizen := Citizen.new()
	citizen.carried_amount = 1
	citizen.storage_delivery_result(false, CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE)
	assert(citizen.carried_amount == 0)
	assert(citizen.blocked_by_storage)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE))
	assert(citizen.status_effect_labels().has("No warehouse"))
	citizen.storage_delivery_result(true)
	assert(not citizen.blocked_by_storage)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE))

	citizen.set_status_effect(CitizenStatusEffectScript.SMOKY_EYES, "Smoky eyes", 1.0)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.SMOKY_EYES))
	assert(citizen.status_effect_labels().has("Smoky eyes"))
	citizen.clear_status_effect(CitizenStatusEffectScript.SMOKY_EYES)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.SMOKY_EYES))
	citizen.free()


static func _test_storage_delivery_service() -> void:
	var simulation := FakeStorageSimulation.new()
	var service := StorageDeliveryServiceScript.new()
	service.configure(simulation)
	var worker := Citizen.new()
	simulation.settlement.add_warehouse("warehouse")
	simulation.settlement.warehouse_ever_built = true
	simulation.warehouse_positions = [Vector3.ZERO]
	service.on_resource_delivered(worker, "grass", 1)
	assert(simulation.settlement.grass == 1)
	assert(not worker.blocked_by_storage)
	assert(simulation.dispatch_requested)
	assert(simulation.courier_dispatcher.completed == 1)
	assert(simulation.last_interface_message == "Workers delivered 1 grass to the warehouse.")

	var full_storage_simulation := FakeStorageSimulation.new()
	var full_storage_service := StorageDeliveryServiceScript.new()
	full_storage_service.configure(full_storage_simulation)
	full_storage_simulation.settlement.add_warehouse("warehouse")
	full_storage_simulation.settlement.warehouse_ever_built = true
	full_storage_simulation.warehouse_positions = [Vector3.ZERO]
	full_storage_simulation.settlement.warehouses[0].set_amount("grass", 24)
	var full_storage_worker := Citizen.new()
	full_storage_worker.carried_amount = 1
	full_storage_service.on_resource_delivered(full_storage_worker, "grass", 1)
	assert(full_storage_simulation.settlement.grass == 24)
	assert(full_storage_simulation.dropped_piles.size() == 1)
	assert(full_storage_simulation.dropped_piles[0].resource_type == "grass")
	assert(not full_storage_worker.blocked_by_storage)

	var no_storage_simulation := FakeStorageSimulation.new()
	var no_storage_service := StorageDeliveryServiceScript.new()
	no_storage_service.configure(no_storage_simulation)
	var blocked_worker := Citizen.new()
	blocked_worker.carried_amount = 1
	no_storage_service.on_resource_delivered(blocked_worker, "grass", 1)
	assert(no_storage_simulation.settlement.grass == 0)
	assert(no_storage_simulation.dropped_piles.size() == 1)
	assert(no_storage_simulation.dropped_piles[0].resource_type == "grass")
	assert(no_storage_simulation.dropped_piles[0].amount == 1)
	assert(not blocked_worker.blocked_by_storage)
	assert(no_storage_simulation.last_interface_message == "No warehouse for 1 grass; the worker left it in a ground pile.")
	worker.free()
	full_storage_worker.free()
	blocked_worker.free()
	simulation.free()
	full_storage_simulation.free()
	no_storage_simulation.free()


static func _test_citizen_living_status_service() -> void:
	var service := CitizenLivingStatusServiceScript.new()
	var citizen := Citizen.new()
	service.refresh_citizen(citizen, true, false)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.NO_HOME))
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE))
	var tent_home := Node3D.new()
	tent_home.set_meta("is_tent", true)
	citizen.assign_home(tent_home)
	service.refresh_citizen(citizen, true, false)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.NO_HOME))
	assert(citizen.has_status_effect(CitizenStatusEffectScript.TENT_SHELTER))
	service.refresh_citizen(citizen, false, true)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE))
	service.refresh_citizen(citizen, true, false)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE))
	citizen.free()
	tent_home.free()


static func _test_water_collector_service() -> void:
	var simulation := FakeWaterCollectorSimulation.new()
	var service := WaterCollectorServiceScript.new()
	service.configure(simulation)

	var collector := Node3D.new()
	collector.position = Vector3(2.0, 0.0, 3.0)
	collector.set_meta("service_position", collector.position)
	simulation.water_collectors = [{
		"node": collector,
		"rate": 1.0,
		"accum": 0.0,
		"stored": 0,
		"capacity": 10,
	}]

	service.tick(2.5)
	assert(service.stored_at(collector.position) == 2)
	assert(service.collect_water(collector.position, 5) == 2)
	assert(service.stored_at(collector.position) == 0)
	assert(service.collect_water(collector.position, 1) == 0)

	collector.free()
	simulation.free()


static func _test_warehouse_reservation_at_assignment() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true
	state.branches = 10

	var warehouse: WarehouseState = state.warehouses[0]
	var room_before := warehouse.room_for("branches", SettlementState.STORAGE_WEIGHTS)
	assert(state.reserve_warehouse_room(0, "branches", 5))
	assert(warehouse.room_for("branches", SettlementState.STORAGE_WEIGHTS) < room_before)
	state.release_warehouse_reservation(0, "branches", 5)
	assert(warehouse.room_for("branches", SettlementState.STORAGE_WEIGHTS) == room_before)


static func _test_balanced_warehouse_mode() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	state.add_warehouse("warehouse")
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true
	state.balanced_warehouse_mode = true
	state.warehouses[0].add("branches", 10, SettlementState.STORAGE_WEIGHTS)
	state.warehouses[1].add("branches", 2, SettlementState.STORAGE_WEIGHTS)
	var index := state.find_warehouse_index(Vector3.ZERO, "branches", 1, [Vector3.ZERO, Vector3(10.0, 0.0, 0.0)])
	assert(index == 1)
	state.balanced_warehouse_mode = false
	index = state.find_warehouse_index(Vector3.ZERO, "branches", 1, [Vector3.ZERO, Vector3(10.0, 0.0, 0.0)])
	assert(index == 0)


static func _test_backpack_invariants() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(not state.warehouse_ever_built)
	state.add("branches", 10)
	assert(state.backpack_amount("branches") == 10)
	assert(state.amount("branches") == 10)
	var old_money := state.money
	state.add("money", 50)
	assert(state.money == old_money + 50)
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true
	state.migrate_virtual_to_warehouse(1)
	assert(state.backpack_amount("branches") == 0)
	assert(state.amount("branches") == 10)


static func _test_warehouse_cheat_respects_accept_filters() -> void:
	var state := SettlementState.new()
	state.add_warehouse("warehouse")
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true

	for resource_type in state.era_resources():
		state.set_warehouse_accepted(0, resource_type, false)

	var overflow := state.add_cheat("branches", 10)
	assert(overflow == 0)
	assert(state.warehouse_amount("branches", 0) == 0)
	assert(state.warehouse_amount("branches", 1) == 10)

	var result: Dictionary = state.fill_least_warehouse_cheat(90.0)
	assert(bool(result.get("filled", false)))
	assert(int(result.get("target_index", -1)) == 1)

	for resource_type in state.era_resources():
		state.set_warehouse_accepted(1, resource_type, false)
	var empty_result: Dictionary = state.fill_least_warehouse_cheat(90.0)
	assert(not bool(empty_result.get("filled", true)))


static func _test_dump_preserves_warehouse_accept_filters() -> void:
	var state := SettlementState.new()
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true
	state.add("branches", 5)

	state.set_warehouse_accepted(0, "branches", false)
	state.set_warehouse_accepted(0, "grass", true)
	state.dump_warehouse_resource(0, "branches", 5)

	assert(not state.warehouse_accepts(0, "branches"))
	assert(state.warehouse_accepts(0, "grass"))
	assert(state.warehouse_amount("branches", 0) == 0)


static func _test_warehouse_accept_toggle_persists_after_refresh() -> void:
	var state := SettlementState.new()
	state.add_warehouse("warehouse")
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true

	state.set_warehouse_accepted(0, "branches", false)
	state.set_warehouse_accepted(0, "grass", true)

	assert(not state.warehouse_accepts(0, "branches"))
	assert(state.warehouse_accepts(0, "grass"))

	state.set_warehouse_accepted(0, "water", false)
	assert(not state.warehouse_accepts(0, "branches"))
	assert(not state.warehouse_accepts(0, "water"))
	assert(state.warehouse_accepts(0, "grass"))

	assert(state.warehouse_accepts(1, "branches"))
	assert(state.warehouse_accepts(1, "grass"))
	assert(state.warehouse_accepts(1, "water"))

	state.add("grass", 3)
	state.dump_warehouse_resource(0, "grass", 3)
	assert(state.warehouse_accepts(0, "grass"))
