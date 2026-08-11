class_name CourierTaskPublisher
extends RefCounted

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const WaterCollectorRecordScript = preload("res://game/features/logistics/domain/water_collector_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _construction_sites: Array = []
var _warehouse_positions: Array[Vector3] = []
var _pending_arrivals: Array = []
var _queued_trades: Array = []
var _sawmill_positions: Array[Vector3] = []
var _water_collectors: Array = []
var _building_registry: Variant
var _sawmills: Variant
var _courier_dispatcher: CourierDispatcher
var _entrance_stone_getter: Callable
var _canteen_getter: Callable
var _canteen_food_getter: Callable
var _canteen_position_getter: Callable
var _pending_canteen_delivery_getter: Callable
var _runtime_seconds_getter: Callable
var _reconcile_construction_reservations: Callable
var _reconcile_repair_reservations: Callable
var _cell_from_position: Callable
var _get_nearest_delivery_position: Callable
var _warehouse_delivery_position: Callable
var _construction_priority: Callable
var _construction_material_sources: Callable
var _construction_source_available: Callable
var _fire_state_for: Callable
var _firewood_task_priority: Callable
var _is_managed_fire_source: Callable


func configure(port: CourierTaskPublisherRuntimePort) -> void:
	_settlement = port.settlement
	_citizens = port.citizens
	_construction_sites = port.construction_sites
	_warehouse_positions = port.warehouse_positions
	_pending_arrivals = port.pending_arrivals
	_queued_trades = port.queued_trades
	_sawmill_positions = port.sawmill_positions
	_water_collectors = port.water_collectors
	_building_registry = port.building_registry
	_sawmills = port.sawmills
	_courier_dispatcher = port.courier_dispatcher
	_entrance_stone_getter = port.entrance_stone_getter
	_canteen_getter = port.canteen_getter
	_canteen_food_getter = port.canteen_food_getter
	_canteen_position_getter = port.canteen_position_getter
	_pending_canteen_delivery_getter = port.pending_canteen_delivery_getter
	_runtime_seconds_getter = port.runtime_seconds_getter
	_reconcile_construction_reservations = port.reconcile_construction_reservations
	_reconcile_repair_reservations = port.reconcile_repair_reservations
	_cell_from_position = port.cell_from_position
	_get_nearest_delivery_position = port.get_nearest_delivery_position
	_warehouse_delivery_position = port.warehouse_delivery_position
	_construction_priority = port.construction_priority
	_construction_material_sources = port.construction_material_sources
	_construction_source_available = port.construction_source_available
	_fire_state_for = port.fire_state_for
	_firewood_task_priority = port.firewood_task_priority
	_is_managed_fire_source = port.is_managed_fire_source


func publish_courier_tasks(dispatcher: RefCounted) -> void:
	if dispatcher == null:
		return

	# Reconcile reservations left by interrupted or removed carriers before task
	# validity is evaluated.
	for construction_site in _construction_sites:
		_reconcile_construction_reservations.call(construction_site)
	_reconcile_repair_reservations.call()

	var entrance_stone: Node3D = _entrance_stone_getter.call()
	if is_instance_valid(entrance_stone):
		for arrival_order: Dictionary in _pending_arrivals:
			if bool(arrival_order.get("dispatched", false)):
				continue
			var arrival_house := arrival_order.get("house") as Node3D
			if is_instance_valid(arrival_house) and not bool(arrival_house.get_meta("pending_demolition", false)):
				dispatcher.publish(
					StringName("arrival_%s" % _cell_from_position.call(arrival_house.global_position)),
					CourierTaskScript.Kind.ARRIVAL,
					89,
					entrance_stone.global_position,
					entrance_stone.global_position,
					{"house": arrival_house}
				)

	if not _warehouse_positions.is_empty():
		var canteen: Node3D = _canteen_getter.call()
		if is_instance_valid(canteen) and _settlement.amount(ResourceIds.FOOD) > 0 and not _pending_canteen_delivery_getter.call():
			var food_capacity: int = BuildingCatalogScript.kitchen_food_capacity(_building_registry.building_type_for_node(canteen))
			if food_capacity > _canteen_food_getter.call():
				var food_source: Vector3 = _get_nearest_delivery_position.call(_canteen_position_getter.call())
				dispatcher.publish(&"canteen_food", CourierTaskScript.Kind.CANTEEN, 100, food_source, _canteen_position_getter.call())
		for order in _queued_trades:
			var trade: Dictionary = order.trade
			dispatcher.publish(StringName("trade_%s" % str(trade)), CourierTaskScript.Kind.TRADE, 80, order.source, order.destination, {"order": order})
		for position in _sawmill_positions:
			if int(_sawmills.stock_at(position, _runtime_seconds_getter.call()).boards) > 0:
				var sawmill_dropoff: Vector3 = _warehouse_delivery_position.call(position, ResourceIds.BOARDS, 1)
				dispatcher.publish(StringName("sawmill_%s" % _cell_from_position.call(position)), CourierTaskScript.Kind.SAWMILL_PICKUP, 50, position, sawmill_dropoff, {"position": position})
		for collector: WaterCollectorRecordScript in _water_collectors:
			if collector.stored > 0:
				if is_instance_valid(collector.node):
					var collector_position: Vector3 = collector.node.get_meta("service_position", collector.node.global_position)
					var dew_dropoff: Vector3 = _warehouse_delivery_position.call(collector_position, ResourceIds.WATER, collector.stored)
					dispatcher.publish(StringName("dew_%s" % _cell_from_position.call(collector_position)), CourierTaskScript.Kind.DEW_PICKUP, 40, collector_position, dew_dropoff, {"position": collector_position})
		for worker in _citizens:
			if worker != null and worker.has_pending_resource() and not _courier_dispatcher.is_manually_targeted(worker):
				var worker_position: Vector3 = worker.global_position
				var worker_dropoff: Vector3 = _warehouse_delivery_position.call(worker_position, worker.resource_type, worker.carried_amount)
				dispatcher.publish(StringName("worker_%d" % worker.ai_id), CourierTaskScript.Kind.WORKER_PICKUP, 45, worker_position, worker_dropoff, {"worker": worker})

	var supply_sites: Array = _construction_sites.duplicate()
	supply_sites.sort_custom(func(left: ConstructionSite, right: ConstructionSite) -> bool:
		var left_score := float(_construction_priority.call(left)) if _construction_priority.is_valid() else 0.0
		var right_score := float(_construction_priority.call(right)) if _construction_priority.is_valid() else 0.0
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return left.site_id < right.site_id
	)
	for site_index in supply_sites.size():
		var site: ConstructionSite = supply_sites[site_index]
		if site == null or not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
			continue
		var site_position: Vector3 = site.node.global_position
		for resource_type in site.required_materials:
			var required: int = int(site.required_materials[resource_type])
			var delivered: int = int(site.delivered_materials.get(resource_type, 0))
			var in_transit: int = int(site.reserved_materials.get(resource_type, 0))
			var sources: Array[Dictionary] = _construction_material_sources.call(str(resource_type), site_position)
			if sources.is_empty():
				continue
			var total_reserved: int = _settlement.construction_reserved_for_site(site.site_id, str(resource_type))
			# The settlement reservation includes cargo already in transit.
			var still_needed: int = maxi(0, required - delivered - total_reserved)
			if still_needed > 0:
				_settlement.reserve_for_construction(site.site_id, str(resource_type), still_needed)
			total_reserved = _settlement.construction_reserved_for_site(site.site_id, str(resource_type))
			var storage_reserved: int = maxi(0, total_reserved - in_transit)
			var smallest_courier_capacity := 0
			for citizen in _citizens:
				if is_instance_valid(citizen) and citizen.can_handle_entry_logistics():
					var courier_capacity: int = citizen.courier_capacity()
					smallest_courier_capacity = courier_capacity if smallest_courier_capacity == 0 else mini(smallest_courier_capacity, courier_capacity)
			var unallocated := maxi(0, required - delivered - in_transit)
			var storage_left := storage_reserved
			var published_slot := 0
			for source_index in sources.size():
				if unallocated <= 0:
					break
				var source: Dictionary = sources[source_index]
				var source_available: int = _construction_source_available.call(str(resource_type), source)
				if str(source.get("kind", "")) != "pile":
					source_available = mini(source_available, storage_left)
				var source_allocation: int = mini(unallocated, source_available)
				if source_allocation <= 0:
					continue
				var delivery_slots: int = ceili(float(source_allocation) / float(maxi(1, smallest_courier_capacity)))
				for _slot in range(delivery_slots):
					dispatcher.publish(
						StringName("construction_%s_%s_%d" % [site.site_id, resource_type, published_slot]),
						CourierTaskScript.Kind.CONSTRUCTION,
						maxi(70, 89 - site_index * 3 - source_index),
						source.position,
						site.node.global_position,
						{"site": site, "resource": resource_type, "source": source}
					)
					published_slot += 1
				unallocated -= source_allocation
				if str(source.get("kind", "")) != "pile":
					storage_left -= source_allocation

	if not _warehouse_positions.is_empty() and _settlement.amount(ResourceIds.BRANCHES) > 0:
		for record in _building_registry.records():
			var building: Node3D = record.node as Node3D
			if not is_instance_valid(building) or not bool(building.get_meta("repair_needed", false)) or bool(building.get_meta("repair_reserved", false)):
				continue
			var repair_position: Vector3 = building.get_meta("service_position", building.global_position)
			var repair_source: Vector3 = _get_nearest_delivery_position.call(repair_position)
			dispatcher.publish(
				StringName("repair_%s" % record.cell),
				CourierTaskScript.Kind.BUILDING_SUPPLY,
				60,
				repair_source,
				repair_position,
				{"building": building, "supply_kind": "repair", "resource": ResourceIds.BRANCHES}
			)
		for record in _building_registry.records():
			var fire_building: Node3D = record.node as Node3D
			if not is_instance_valid(fire_building):
				continue
			if _is_managed_fire_source.is_valid():
				if not _is_managed_fire_source.call(fire_building):
					continue
			else:
				var building_type: String = record.building_type
				if not BuildingTypes.is_fire_source(building_type):
					continue
			var fire_state = _fire_state_for.call(fire_building)
			if not fire_state.needs_supply(4) or _settlement.amount(ResourceIds.BRANCHES) <= 0:
				continue
			var fire_position: Vector3 = fire_building.get_meta("service_position", fire_building.global_position)
			dispatcher.publish(
				StringName("firewood_%s" % record.cell),
				CourierTaskScript.Kind.BUILDING_SUPPLY,
				_firewood_task_priority.call(fire_building, fire_state),
				_get_nearest_delivery_position.call(fire_position),
				fire_position,
				{"building": fire_building, "supply_kind": "firewood", "resource": ResourceIds.BRANCHES}
			)
