class_name CourierTaskService
extends RefCounted

## Handles courier task lifecycle: starting tasks (canteen, trade, sawmill,
## dew, worker pickup, construction, building supply, arrival, outside work),
## warehouse space reservation, reachability checks, task cancellation,
## and construction reservation reconciliation.

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const BuildingCatalog = preload("res://game/features/buildings/domain/building_catalog.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _queued_trades: Array = []
var _pending_trades: Dictionary = {}
var _warehouse_positions: Array[Vector3] = []
var _pending_arrivals: Array = []
var _arrival_greeters: Dictionary = {}
var _outside_workers: Dictionary = {}
var _building_registry: Variant
var _sawmills: Variant
var _water_collector_service: Variant
var _trade_service: TradeService
var _canteen_service: Variant
var _canteen_getter: Callable
var _canteen_food_getter: Callable
var _canteen_position_getter: Callable
var _pending_canteen_delivery_getter: Callable
var _set_canteen_delivery_state: Callable
var _entrance_stone_getter: Callable
var _runtime_seconds_getter: Callable
var _fire_state_for: Callable
var _apply_fire_state: Callable
var _is_route_reachable: Callable
var _preferred_construction_site: Callable
var _construction_source_available: Callable
var _citizen_for_ai_id: Callable


func configure(
	p_settlement: SettlementState,
	p_citizens: Array,
	p_queued_trades: Array,
	p_pending_trades: Dictionary,
	p_warehouse_positions: Array[Vector3],
	p_pending_arrivals: Array,
	p_arrival_greeters: Dictionary,
	p_outside_workers: Dictionary,
	p_building_registry: Variant,
	p_sawmills: Variant,
	p_water_collector_service: Variant,
	p_trade_service: TradeService,
	p_canteen_service: Variant,
	p_canteen_getter: Callable,
	p_canteen_food_getter: Callable,
	p_canteen_position_getter: Callable,
	p_pending_canteen_delivery_getter: Callable,
	p_set_canteen_delivery_state: Callable,
	p_entrance_stone_getter: Callable,
	p_runtime_seconds_getter: Callable,
	p_fire_state_for: Callable,
	p_apply_fire_state: Callable,
	p_is_route_reachable: Callable,
	p_preferred_construction_site: Callable,
	p_construction_source_available: Callable,
	p_citizen_for_ai_id: Callable
) -> void:
	_settlement = p_settlement
	_citizens = p_citizens
	_queued_trades = p_queued_trades
	_pending_trades = p_pending_trades
	_warehouse_positions = p_warehouse_positions
	_pending_arrivals = p_pending_arrivals
	_arrival_greeters = p_arrival_greeters
	_outside_workers = p_outside_workers
	_building_registry = p_building_registry
	_sawmills = p_sawmills
	_water_collector_service = p_water_collector_service
	_trade_service = p_trade_service
	_canteen_service = p_canteen_service
	_canteen_getter = p_canteen_getter
	_canteen_food_getter = p_canteen_food_getter
	_canteen_position_getter = p_canteen_position_getter
	_pending_canteen_delivery_getter = p_pending_canteen_delivery_getter
	_set_canteen_delivery_state = p_set_canteen_delivery_state
	_entrance_stone_getter = p_entrance_stone_getter
	_runtime_seconds_getter = p_runtime_seconds_getter
	_fire_state_for = p_fire_state_for
	_apply_fire_state = p_apply_fire_state
	_is_route_reachable = p_is_route_reachable
	_preferred_construction_site = p_preferred_construction_site
	_construction_source_available = p_construction_source_available
	_citizen_for_ai_id = p_citizen_for_ai_id


func start_courier_canteen_or_trade(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.CANTEEN:
			var canteen: Node3D = _canteen_getter.call()
			var capacity: int = BuildingCatalog.kitchen_food_capacity(_building_registry.building_type_for_node(canteen))
			var amount: int = mini(courier.courier_capacity(), mini(_settlement.amount(ResourceIds.FOOD), capacity - _canteen_food_getter.call()))
			if amount <= 0:
				return false
			_settlement.add(ResourceIds.FOOD, -amount)
			_set_canteen_delivery_state.call(true, courier, amount)
			courier.deliver_food_to_canteen(task.pickup, _canteen_position_getter.call(), amount)
			return true
		CourierTask.Kind.TRADE:
			var order: RefCounted = task.payload.order
			if not _queued_trades.has(order):
				return false
			_queued_trades.erase(order)
			_trade_service.assign_order_to_worker(courier, order)
			return true
	return false


func start_courier_pickup_task(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.SAWMILL_PICKUP:
			var sawmill_stock: Dictionary = _sawmills.stock_at(task.payload.position, _runtime_seconds_getter.call())
			var sawmill_amount: int = mini(courier.courier_capacity(), int(sawmill_stock.boards))
			if sawmill_amount <= 0 or not reserve_task_warehouse_space(task, ResourceIds.BOARDS, sawmill_amount):
				return false
			courier.assign_sawmill_pickup(task.payload.position, task.dropoff)
			return true
		CourierTask.Kind.DEW_PICKUP:
			var dew_stored: int = _water_collector_service.stored_at(task.payload.position)
			var dew_amount: int = mini(courier.courier_capacity(), dew_stored)
			if dew_amount <= 0 or not reserve_task_warehouse_space(task, ResourceIds.WATER, dew_amount):
				return false
			courier.assign_dew_collector_pickup(task.payload.position, task.dropoff)
			return true
		CourierTask.Kind.WORKER_PICKUP:
			var worker: Citizen = task.payload.worker
			var worker_resource: String = worker.resource_type
			var worker_amount: int = worker.carried_amount
			if worker_amount <= 0:
				worker_amount = int(worker.pending_resources.get(worker_resource, 0))
			worker_amount = mini(courier.courier_capacity(), worker_amount)
			if worker_amount <= 0 or worker_resource.is_empty() or not reserve_task_warehouse_space(task, worker_resource, worker_amount):
				return false
			courier.assign_courier_pickup(task.payload.worker, task.dropoff)
			return true
	return false


func start_courier_construction_or_supply(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.CONSTRUCTION:
			var site: ConstructionSite = task.payload.site
			var resource_type: String = str(task.payload.resource)
			var source: Dictionary = task.payload.get("source", {})
			if site == null or not is_instance_valid(site.node):
				return false
			var total_reserved: int = _settlement.construction_reserved_for_site(site.site_id, resource_type)
			var in_transit: int = int(site.reserved_materials.get(resource_type, 0))
			var remaining: int = int(site.required_materials.get(resource_type, 0)) - int(site.delivered_materials.get(resource_type, 0)) - in_transit
			var storage_reserved: int = maxi(0, total_reserved - in_transit)
			var source_available: int = _settlement.amount(resource_type)
			var warehouse_index: int = int(source.get("warehouse_index", -1))
			if warehouse_index >= 0:
				source_available = _settlement.warehouse_amount(resource_type, warehouse_index)
			var amount: int = mini(courier.courier_capacity(), mini(source_available, mini(storage_reserved, remaining)))
			if amount <= 0:
				return false
			if warehouse_index >= 0:
				if _settlement.add_to_warehouse(resource_type, -amount, warehouse_index) != 0:
					return false
			else:
				_settlement.add(resource_type, -amount)
			var reservations: Dictionary = site.reserved_materials
			reservations[resource_type] = int(reservations.get(resource_type, 0)) + amount
			site.reserved_materials = reservations
			courier.assign_construction_delivery(site.node, source.get("position", Vector3.INF), resource_type, amount)
			return true
		CourierTask.Kind.BUILDING_SUPPLY:
			var building: Node3D = task.payload.building
			if not is_instance_valid(building):
				return false
			var supply_kind: String = str(task.payload.get("supply_kind", ""))
			match supply_kind:
				"repair":
					if _settlement.amount(ResourceIds.BRANCHES) <= 0:
						return false
					_settlement.add(ResourceIds.BRANCHES, -1)
					building.set_meta("repair_reserved", true)
					courier.assign_building_supply(building, task.pickup, ResourceIds.BRANCHES, "repair")
					return true
				"firewood":
					if _settlement.amount(ResourceIds.BRANCHES) <= 0:
						return false
					var fire_state: RefCounted = _fire_state_for.call(building)
					if not fire_state.needs_supply(4):
						return false
					_settlement.add(ResourceIds.BRANCHES, -1)
					fire_state.reserve(1)
					_apply_fire_state.call(building, fire_state)
					courier.assign_building_supply(building, task.pickup, ResourceIds.BRANCHES, "firewood")
					return true
			return false
	return false


func start_courier_arrival_or_outside(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.ARRIVAL:
			var arrival_house: Node3D = task.payload.get("house") as Node3D
			for index in _pending_arrivals.size():
				var arrival_order: Dictionary = _pending_arrivals[index]
				if arrival_order.get("house") != arrival_house or bool(arrival_order.get("dispatched", false)):
					continue
				arrival_order.dispatched = true
				arrival_order.greeter_id = courier.ai_id
				_pending_arrivals[index] = arrival_order
				_arrival_greeters[courier.ai_id] = arrival_order
				courier.go_to_arrival_entrance(task.dropoff)
				return true
			return false
		CourierTask.Kind.OUTSIDE_WORK:
			var entrance_stone: Node3D = _entrance_stone_getter.call()
			if task.payload.get("courier") != courier or not is_instance_valid(entrance_stone):
				return false
			courier.assign_outside_work(entrance_stone.global_position)
			return true
	return false


func reserve_task_warehouse_space(task: RefCounted, resource_type: String, amount: int) -> bool:
	if task == null or amount <= 0 or resource_type.is_empty() or _warehouse_positions.is_empty():
		return false
	var index: int = _warehouse_positions.find(task.dropoff)
	if index < 0:
		index = _settlement.find_warehouse_index(task.dropoff, resource_type, amount, _warehouse_positions)
	if index < 0:
		return false
	if not _settlement.reserve_warehouse_room(index, resource_type, amount):
		return false
	task.reserved_warehouse_index = index
	task.reserved_resource_type = resource_type
	task.reserved_amount = amount
	return true


func release_task_warehouse_reservation(task: RefCounted) -> void:
	if task == null or task.reserved_warehouse_index < 0 or task.reserved_amount <= 0 or task.reserved_resource_type.is_empty():
		return
	_settlement.release_warehouse_reservation(task.reserved_warehouse_index, task.reserved_resource_type, task.reserved_amount)
	task.reserved_warehouse_index = -1
	task.reserved_resource_type = ""
	task.reserved_amount = 0


func is_courier_task_reachable(courier: Citizen, task: RefCounted) -> bool:
	if not is_instance_valid(courier) or task == null:
		return false
	var dropoff: Vector3 = task.dropoff
	if task.kind == CourierTask.Kind.CONSTRUCTION:
		var site: ConstructionSite = task.payload.get("site") as ConstructionSite
		if site == null or not is_instance_valid(site.node):
			return false
		dropoff = courier._reachable_construction_approach(site.node)
	if task.pickup == Vector3.INF or dropoff == Vector3.INF:
		return false
	return _is_route_reachable.call(courier.global_position, task.pickup) and _is_route_reachable.call(task.pickup, dropoff)


func cancel_courier_task(courier: Citizen, task: RefCounted) -> void:
	if task == null:
		return
	var carried: int = courier.carried_amount if is_instance_valid(courier) else 0
	match task.kind:
		CourierTask.Kind.CANTEEN:
			if _pending_canteen_delivery_getter.call() and _canteen_service != null:
				_canteen_service.cancel_canteen_delivery()
		CourierTask.Kind.TRADE:
			if is_instance_valid(courier):
				var order: RefCounted = _pending_trades.get(courier.ai_id, null)
				if order != null:
					_pending_trades.erase(courier.ai_id)
					_queued_trades.push_front(order)
		CourierTask.Kind.WORKER_PICKUP:
			var worker: Citizen = task.payload.get("worker") as Citizen
			if carried > 0 and is_instance_valid(worker) and is_instance_valid(courier):
				worker.register_pending_resource(courier.courier_resource_type, carried)
				courier.carried_amount = 0
		CourierTask.Kind.SAWMILL_PICKUP:
			if carried > 0 and is_instance_valid(courier) and courier.courier_resource_type == ResourceIds.BOARDS:
				_sawmills.return_boards(task.pickup, carried, _runtime_seconds_getter.call())
				courier.carried_amount = 0
		CourierTask.Kind.DEW_PICKUP:
			if carried > 0 and is_instance_valid(courier) and courier.courier_resource_type == ResourceIds.WATER:
				_water_collector_service.return_water(task.pickup, carried)
				courier.carried_amount = 0
		CourierTask.Kind.BUILDING_SUPPLY:
			var supply_kind: String = str(task.payload.get("supply_kind", ""))
			if supply_kind == "repair":
				var building: Node3D = task.payload.get("building") as Node3D
				if is_instance_valid(building):
					building.set_meta("repair_reserved", false)
				_settlement.add(str(task.payload.get("resource", ResourceIds.BRANCHES)), 1)
			elif supply_kind == "firewood":
				var fire_building: Node3D = task.payload.get("building") as Node3D
				if is_instance_valid(fire_building):
					var fire_state: RefCounted = _fire_state_for.call(fire_building)
					fire_state.reserved_fuel = maxi(0, fire_state.reserved_fuel - 1)
					_apply_fire_state.call(fire_building, fire_state)
				_settlement.add(str(task.payload.get("resource", ResourceIds.BRANCHES)), 1)


func reconcile_construction_reservations(site: ConstructionSite) -> void:
	if site == null or not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
		return
	var in_transit: Dictionary = {}
	for citizen in _citizens:
		if not is_instance_valid(citizen.construction_site) or citizen.construction_site != site.node:
			continue
		if citizen.state not in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]:
			continue
		if citizen.building_supply_kind != "construction" or citizen.construction_delivery_resource.is_empty():
			continue
		in_transit[citizen.construction_delivery_resource] = int(in_transit.get(citizen.construction_delivery_resource, 0)) + citizen.carried_amount
	var reservations: Dictionary = site.reserved_materials
	for resource_type in reservations:
		var reserved: int = int(reservations[resource_type])
		var active: int = int(in_transit.get(resource_type, 0))
		if reserved <= active:
			continue
		_settlement.add(resource_type, reserved - active)
		reservations[resource_type] = active
	site.reserved_materials = reservations


func start_courier_task(courier: Citizen, task: RefCounted) -> bool:
	if not is_courier_task_reachable(courier, task):
		return false
	match task.kind:
		CourierTask.Kind.CANTEEN, CourierTask.Kind.TRADE:
			return start_courier_canteen_or_trade(courier, task)
		CourierTask.Kind.SAWMILL_PICKUP, CourierTask.Kind.DEW_PICKUP, CourierTask.Kind.WORKER_PICKUP:
			return start_courier_pickup_task(courier, task)
		CourierTask.Kind.CONSTRUCTION, CourierTask.Kind.BUILDING_SUPPLY:
			return start_courier_construction_or_supply(courier, task)
		CourierTask.Kind.ARRIVAL, CourierTask.Kind.OUTSIDE_WORK:
			return start_courier_arrival_or_outside(courier, task)
	return false


func is_courier_task_valid(task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.CANTEEN:
			var canteen: Node3D = _canteen_getter.call()
			return is_instance_valid(canteen) and _settlement.amount(ResourceIds.FOOD) > 0 and not _pending_canteen_delivery_getter.call() and _canteen_food_getter.call() < BuildingCatalog.kitchen_food_capacity(_building_registry.building_type_for_node(canteen))
		CourierTask.Kind.TRADE:
			return _queued_trades.has(task.payload.order)
		CourierTask.Kind.SAWMILL_PICKUP:
			return int(_sawmills.stock_at(task.payload.position, _runtime_seconds_getter.call()).boards) > 0
		CourierTask.Kind.WORKER_PICKUP:
			return is_instance_valid(task.payload.worker) and task.payload.worker.has_pending_resource()
		CourierTask.Kind.DEW_PICKUP:
			return _water_collector_service.stored_at(task.payload.position) > 0
		CourierTask.Kind.CONSTRUCTION:
			var site: ConstructionSite = task.payload.site
			if site == null or not is_instance_valid(site.node):
				return false
			if site != _preferred_construction_site.call():
				return false
			var resource_type := str(task.payload.resource)
			var source: Dictionary = task.payload.get("source", {})
			if not task.is_assigned():
				if source.is_empty() or _construction_source_available.call(resource_type, source) <= 0:
					return false
			var total_reserved: int = _settlement.construction_reserved_for_site(site.site_id, resource_type)
			var in_transit := int(site.reserved_materials.get(resource_type, 0))
			var storage_reserved := maxi(0, total_reserved - in_transit)
			var source_available := storage_reserved > 0
			return int(site.delivered_materials.get(resource_type, 0)) + in_transit < int(site.required_materials.get(resource_type, 0)) and source_available
		CourierTask.Kind.BUILDING_SUPPLY:
			var building: Node3D = task.payload.building
			if not is_instance_valid(building):
				return false
			var supply_kind := str(task.payload.get("supply_kind", ""))
			match supply_kind:
				"repair":
					return bool(building.get_meta("repair_needed", false)) and not bool(building.get_meta("repair_reserved", false)) and _settlement.amount(ResourceIds.BRANCHES) > 0
				"firewood":
					return _fire_state_for.call(building).needs_supply(4) and _settlement.amount(ResourceIds.BRANCHES) > 0
			return false
		CourierTask.Kind.ARRIVAL:
			var arrival_house := task.payload.get("house") as Node3D
			if not is_instance_valid(arrival_house) or bool(arrival_house.get_meta("pending_demolition", false)):
				return false
			for arrival_order: Dictionary in _pending_arrivals:
				if arrival_order.get("house") == arrival_house:
					if not bool(arrival_order.get("dispatched", false)):
						return true
					var greeter: Citizen = _citizen_for_ai_id.call(int(arrival_order.get("greeter_id", -1)))
					return is_instance_valid(greeter) and greeter.ai_id == task.assigned_courier_ai_id
			return false
		CourierTask.Kind.OUTSIDE_WORK:
			var selected: Citizen = task.payload.get("courier") as Citizen
			return is_instance_valid(selected) and not _outside_workers.has(selected.get_stable_id())
	return false
