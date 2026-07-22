class_name CourierTaskService
extends RefCounted

## Handles courier task lifecycle: starting tasks (canteen, trade, sawmill,
## dew, worker pickup, construction, building supply, arrival, outside work),
## warehouse space reservation, reachability checks, task cancellation,
## and construction reservation reconciliation.

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const BuildingCatalog = preload("res://game/features/buildings/domain/building_catalog.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func start_courier_canteen_or_trade(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.CANTEEN:
			var capacity: int = BuildingCatalog.kitchen_food_capacity(str(simulation.canteen.get_meta("building_type", "")))
			var amount: int = mini(courier.courier_capacity(), mini(simulation.settlement.amount("food"), capacity - simulation.canteen_food))
			if amount <= 0:
				return false
			simulation.settlement.add("food", -amount)
			simulation.pending_canteen_delivery = true
			simulation.pending_canteen_carrier = courier
			simulation.pending_canteen_delivery_amount = amount
			courier.deliver_food_to_canteen(task.pickup, simulation.canteen_position, amount)
			return true
		CourierTask.Kind.TRADE:
			var order: RefCounted = task.payload.order
			if not simulation.queued_trades.has(order):
				return false
			simulation.queued_trades.erase(order)
			simulation.trade_service.assign_order_to_worker(courier, order)
			return true
	return false


func start_courier_pickup_task(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.SAWMILL_PICKUP:
			var sawmill_stock: Dictionary = simulation.sawmills.stock_at(task.payload.position, simulation.runtime_seconds)
			var sawmill_amount: int = mini(courier.courier_capacity(), int(sawmill_stock.boards))
			if sawmill_amount <= 0 or not reserve_task_warehouse_space(task, "boards", sawmill_amount):
				return false
			courier.assign_sawmill_pickup(task.payload.position, task.dropoff)
			return true
		CourierTask.Kind.DEW_PICKUP:
			var dew_stored: int = simulation.water_collector_service.stored_at(task.payload.position)
			var dew_amount: int = mini(courier.courier_capacity(), dew_stored)
			if dew_amount <= 0 or not reserve_task_warehouse_space(task, "water", dew_amount):
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
			var settlement: SettlementState = simulation.settlement
			var total_reserved: int = settlement.construction_reserved_for_site(site.site_id, resource_type)
			var in_transit: int = int(site.reserved_materials.get(resource_type, 0))
			var remaining: int = int(site.required_materials.get(resource_type, 0)) - int(site.delivered_materials.get(resource_type, 0)) - in_transit
			var storage_reserved: int = maxi(0, total_reserved - in_transit)
			var source_available: int = settlement.amount(resource_type)
			var warehouse_index: int = int(source.get("warehouse_index", -1))
			if warehouse_index >= 0:
				source_available = settlement.warehouse_amount(resource_type, warehouse_index)
			var amount: int = mini(courier.courier_capacity(), mini(source_available, mini(storage_reserved, remaining)))
			if amount <= 0:
				return false
			if warehouse_index >= 0:
				if settlement.add_to_warehouse(resource_type, -amount, warehouse_index) != 0:
					return false
			else:
				settlement.add(resource_type, -amount)
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
					if simulation.settlement.amount("branches") <= 0:
						return false
					simulation.settlement.add("branches", -1)
					building.set_meta("repair_reserved", true)
					courier.assign_building_supply(building, task.pickup, "branches", "repair")
					return true
				"firewood":
					if simulation.settlement.amount("branches") <= 0:
						return false
					var fire_state: RefCounted = simulation._fire_state_for(building)
					if not fire_state.needs_supply(4):
						return false
					simulation.settlement.add("branches", -1)
					fire_state.reserve(1)
					simulation._apply_fire_state(building, fire_state)
					courier.assign_building_supply(building, task.pickup, "branches", "firewood")
					return true
			return false
	return false


func start_courier_arrival_or_outside(courier: Citizen, task: RefCounted) -> bool:
	match task.kind:
		CourierTask.Kind.ARRIVAL:
			var arrival_house: Node3D = task.payload.get("house") as Node3D
			for index in simulation.pending_arrivals.size():
				var arrival_order: Dictionary = simulation.pending_arrivals[index]
				if arrival_order.get("house") != arrival_house or bool(arrival_order.get("dispatched", false)):
					continue
				arrival_order.dispatched = true
				arrival_order.greeter_id = courier.ai_id
				simulation.pending_arrivals[index] = arrival_order
				simulation.arrival_greeters[courier.ai_id] = arrival_order
				courier.go_to_arrival_entrance(task.dropoff)
				return true
			return false
		CourierTask.Kind.OUTSIDE_WORK:
			if task.payload.get("courier") != courier or not is_instance_valid(simulation.entrance_stone):
				return false
			courier.assign_outside_work(simulation.entrance_stone.global_position)
			return true
	return false


func reserve_task_warehouse_space(task: RefCounted, resource_type: String, amount: int) -> bool:
	if task == null or amount <= 0 or resource_type.is_empty() or simulation.warehouse_positions.is_empty():
		return false
	var index: int = simulation.warehouse_positions.find(task.dropoff)
	if index < 0:
		index = simulation.settlement.find_warehouse_index(task.dropoff, resource_type, amount, simulation.warehouse_positions)
	if index < 0:
		return false
	if not simulation.settlement.reserve_warehouse_room(index, resource_type, amount):
		return false
	task.reserved_warehouse_index = index
	task.reserved_resource_type = resource_type
	task.reserved_amount = amount
	return true


func release_task_warehouse_reservation(task: RefCounted) -> void:
	if task == null or task.reserved_warehouse_index < 0 or task.reserved_amount <= 0 or task.reserved_resource_type.is_empty():
		return
	simulation.settlement.release_warehouse_reservation(task.reserved_warehouse_index, task.reserved_resource_type, task.reserved_amount)
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
	return simulation._is_route_reachable(courier.global_position, task.pickup) and simulation._is_route_reachable(task.pickup, dropoff)


func cancel_courier_task(courier: Citizen, task: RefCounted) -> void:
	if task == null:
		return
	var carried: int = courier.carried_amount if is_instance_valid(courier) else 0
	match task.kind:
		CourierTask.Kind.CANTEEN:
			if simulation.pending_canteen_delivery and simulation.pending_canteen_carrier == courier:
				simulation.canteen_service.cancel_canteen_delivery()
		CourierTask.Kind.TRADE:
			if is_instance_valid(courier):
				var order: RefCounted = simulation.pending_trades.get(courier.ai_id, null)
				if order != null:
					simulation.pending_trades.erase(courier.ai_id)
					simulation.queued_trades.push_front(order)
		CourierTask.Kind.WORKER_PICKUP:
			var worker: Citizen = task.payload.get("worker") as Citizen
			if carried > 0 and is_instance_valid(worker) and is_instance_valid(courier):
				worker.register_pending_resource(courier.courier_resource_type, carried)
				courier.carried_amount = 0
		CourierTask.Kind.SAWMILL_PICKUP:
			if carried > 0 and is_instance_valid(courier) and courier.courier_resource_type == "boards":
				simulation.sawmills.return_boards(task.pickup, carried, simulation.runtime_seconds)
				courier.carried_amount = 0
		CourierTask.Kind.DEW_PICKUP:
			if carried > 0 and is_instance_valid(courier) and courier.courier_resource_type == "water":
				simulation.water_collector_service.return_water(task.pickup, carried)
				courier.carried_amount = 0
		CourierTask.Kind.BUILDING_SUPPLY:
			var supply_kind: String = str(task.payload.get("supply_kind", ""))
			if supply_kind == "repair":
				var building: Node3D = task.payload.get("building") as Node3D
				if is_instance_valid(building):
					building.set_meta("repair_reserved", false)
				simulation.settlement.add(str(task.payload.get("resource", "branches")), 1)
			elif supply_kind == "firewood":
				var fire_building: Node3D = task.payload.get("building") as Node3D
				if is_instance_valid(fire_building):
					var fire_state: RefCounted = simulation._fire_state_for(fire_building)
					fire_state.reserved_fuel = maxi(0, fire_state.reserved_fuel - 1)
					simulation._apply_fire_state(fire_building, fire_state)
				simulation.settlement.add(str(task.payload.get("resource", "branches")), 1)


func reconcile_construction_reservations(site: ConstructionSite) -> void:
	if site == null or not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
		return
	var in_transit: Dictionary = {}
	for citizen in simulation.citizens:
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
		simulation.settlement.add(resource_type, reserved - active)
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
			return is_instance_valid(simulation.canteen) and simulation.settlement.amount("food") > 0 and not simulation.pending_canteen_delivery and simulation.canteen_food < BuildingCatalog.kitchen_food_capacity(str(simulation.canteen.get_meta("building_type", "")))
		CourierTask.Kind.TRADE:
			return simulation.queued_trades.has(task.payload.order)
		CourierTask.Kind.SAWMILL_PICKUP:
			return int(simulation.sawmills.stock_at(task.payload.position, simulation.runtime_seconds).boards) > 0
		CourierTask.Kind.WORKER_PICKUP:
			return is_instance_valid(task.payload.worker) and task.payload.worker.has_pending_resource()
		CourierTask.Kind.DEW_PICKUP:
			return simulation.water_collector_service.stored_at(task.payload.position) > 0
		CourierTask.Kind.CONSTRUCTION:
			var site: ConstructionSite = task.payload.site
			if site == null or not is_instance_valid(site.node):
				return false
			if site != simulation._preferred_construction_site():
				return false
			var resource_type := str(task.payload.resource)
			var source: Dictionary = task.payload.get("source", {})
			if not task.is_assigned():
				if source.is_empty() or simulation._construction_source_available(resource_type, source) <= 0:
					return false
			var total_reserved: int = simulation.settlement.construction_reserved_for_site(site.site_id, resource_type)
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
					return bool(building.get_meta("repair_needed", false)) and not bool(building.get_meta("repair_reserved", false)) and simulation.settlement.amount("branches") > 0
				"firewood":
					return simulation._fire_state_for(building).needs_supply(4) and simulation.settlement.amount("branches") > 0
			return false
		CourierTask.Kind.ARRIVAL:
			var arrival_house := task.payload.get("house") as Node3D
			if not is_instance_valid(arrival_house) or bool(arrival_house.get_meta("pending_demolition", false)):
				return false
			for arrival_order: Dictionary in simulation.pending_arrivals:
				if arrival_order.get("house") == arrival_house:
					if not bool(arrival_order.get("dispatched", false)):
						return true
					var greeter := simulation._citizen_for_ai_id(int(arrival_order.get("greeter_id", -1)))
					return is_instance_valid(greeter) and greeter.ai_id == task.assigned_courier_ai_id
			return false
		CourierTask.Kind.OUTSIDE_WORK:
			var selected: Citizen = task.payload.get("courier") as Citizen
			return is_instance_valid(selected) and not simulation.outside_workers.has(selected.get_stable_id())
	return false
