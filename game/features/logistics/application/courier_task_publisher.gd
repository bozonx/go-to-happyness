class_name CourierTaskPublisher
extends RefCounted

const CourierTaskScript = preload("res://game/features/logistics/domain/courier_task.gd")
const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func publish_courier_tasks(dispatcher: RefCounted) -> void:
	if simulation == null or dispatcher == null:
		return

	# Reconcile reservations left by interrupted or removed carriers before task
	# validity is evaluated.
	for construction_site in simulation.construction_sites:
		simulation._reconcile_construction_reservations(construction_site)
	simulation._reconcile_repair_reservations()

	if is_instance_valid(simulation.entrance_stone):
		for arrival_order: Dictionary in simulation.pending_arrivals:
			if bool(arrival_order.get("dispatched", false)):
				continue
			var arrival_house := arrival_order.get("house") as Node3D
			if is_instance_valid(arrival_house) and not bool(arrival_house.get_meta("pending_demolition", false)):
				dispatcher.publish(
					StringName("arrival_%s" % simulation._cell_from_position(arrival_house.global_position)),
					CourierTaskScript.Kind.ARRIVAL,
					89,
					simulation.entrance_stone.global_position,
					simulation.entrance_stone.global_position,
					{"house": arrival_house}
				)

	if not simulation.warehouse_positions.is_empty():
		if is_instance_valid(simulation.canteen) and simulation.settlement.amount("food") > 0 and not simulation.pending_canteen_delivery:
			var food_capacity: int = BuildingCatalogScript.kitchen_food_capacity(str(simulation.canteen.get_meta("building_type", "")))
			if food_capacity > simulation.canteen_food:
				var food_source: Vector3 = simulation._get_nearest_delivery_position(simulation.canteen_position)
				dispatcher.publish(&"canteen_food", CourierTaskScript.Kind.CANTEEN, 100, food_source, simulation.canteen_position)
		for order in simulation.queued_trades:
			var trade: Dictionary = order.trade
			dispatcher.publish(StringName("trade_%s" % str(trade)), CourierTaskScript.Kind.TRADE, 80, order.source, order.destination, {"order": order})
		for position in simulation.sawmill_positions:
			if int(simulation.sawmills.stock_at(position, simulation.runtime_seconds).boards) > 0:
				var sawmill_dropoff: Vector3 = simulation._warehouse_delivery_position(position, "boards", 1)
				dispatcher.publish(StringName("sawmill_%s" % simulation._cell_from_position(position)), CourierTaskScript.Kind.SAWMILL_PICKUP, 50, position, sawmill_dropoff, {"position": position})
		for collector: Dictionary in simulation.water_collectors:
			if int(collector.get("stored", 0)) > 0:
				var collector_node: Node3D = collector.get("node") as Node3D
				if is_instance_valid(collector_node):
					var collector_position: Vector3 = collector_node.get_meta("service_position", collector_node.global_position)
					var dew_dropoff: Vector3 = simulation._warehouse_delivery_position(collector_position, "water", int(collector.get("stored", 0)))
					dispatcher.publish(StringName("dew_%s" % simulation._cell_from_position(collector_position)), CourierTaskScript.Kind.DEW_PICKUP, 40, collector_position, dew_dropoff, {"position": collector_position})
		for worker in simulation.citizens:
			if worker != null and worker.has_pending_resource() and not simulation.courier_dispatcher.is_manually_targeted(worker):
				var worker_position: Vector3 = worker.global_position
				var worker_dropoff: Vector3 = simulation._warehouse_delivery_position(worker_position, worker.resource_type, worker.carried_amount)
				dispatcher.publish(StringName("worker_%d" % worker.ai_id), CourierTaskScript.Kind.WORKER_PICKUP, 45, worker_position, worker_dropoff, {"worker": worker})

	var site = simulation._preferred_construction_site()
	if site != null and is_instance_valid(site.node) and not site.node.is_queued_for_deletion():
		var site_position: Vector3 = site.node.global_position
		for resource_type in site.required_materials:
			var required: int = int(site.required_materials[resource_type])
			var delivered: int = int(site.delivered_materials.get(resource_type, 0))
			var in_transit: int = int(site.reserved_materials.get(resource_type, 0))
			var sources: Array[Dictionary] = simulation._construction_material_sources(str(resource_type), site_position)
			if sources.is_empty():
				continue
			var total_reserved: int = simulation.settlement.construction_reserved_for_site(site.site_id, str(resource_type))
			var still_needed: int = maxi(0, required - delivered - total_reserved)
			if still_needed > 0:
				simulation.settlement.reserve_for_construction(site.site_id, str(resource_type), still_needed)
			total_reserved = simulation.settlement.construction_reserved_for_site(site.site_id, str(resource_type))
			var storage_reserved: int = maxi(0, total_reserved - in_transit)
			if storage_reserved > 0:
				var smallest_courier_capacity := 0
				for citizen in simulation.citizens:
					if is_instance_valid(citizen) and citizen.can_handle_entry_logistics():
						var courier_capacity: int = citizen.courier_capacity()
						smallest_courier_capacity = courier_capacity if smallest_courier_capacity == 0 else mini(smallest_courier_capacity, courier_capacity)
				var unallocated := storage_reserved
				for source: Dictionary in sources:
					if unallocated <= 0:
						break
					var source_available: int = simulation._construction_source_available(str(resource_type), source)
					var source_allocation: int = mini(unallocated, source_available)
					if source_allocation <= 0:
						continue
					var source_id: String = str(source.get("id", "storage"))
					var delivery_slots: int = ceili(float(source_allocation) / float(maxi(1, smallest_courier_capacity)))
					for slot in range(delivery_slots):
						dispatcher.publish(
							StringName("construction_%s_%s_%s_%d" % [site.cell, resource_type, source_id, slot]),
							CourierTaskScript.Kind.CONSTRUCTION,
							70,
							source.position,
							site.node.global_position,
							{"site": site, "resource": resource_type, "source": source}
						)
					unallocated -= source_allocation

	if not simulation.warehouse_positions.is_empty() and simulation.settlement.amount("branches") > 0:
		for record in simulation.building_registry.records():
			var building: Node3D = record.node as Node3D
			if not is_instance_valid(building) or not bool(building.get_meta("repair_needed", false)) or bool(building.get_meta("repair_reserved", false)):
				continue
			var repair_position: Vector3 = building.get_meta("service_position", building.global_position)
			var repair_source: Vector3 = simulation._get_nearest_delivery_position(repair_position)
			dispatcher.publish(
				StringName("repair_%s" % record.cell),
				CourierTaskScript.Kind.BUILDING_SUPPLY,
				60,
				repair_source,
				repair_position,
				{"building": building, "supply_kind": "repair", "resource": "branches"}
			)
		for record in simulation.building_registry.records():
			var fire_building: Node3D = record.node as Node3D
			if not is_instance_valid(fire_building):
				continue
			var building_type: String = record.building_type
			if building_type not in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
				continue
			var fire_state = simulation._fire_state_for(fire_building)
			if not fire_state.needs_supply(4) or simulation.settlement.amount("branches") <= 0:
				continue
			var fire_position: Vector3 = fire_building.get_meta("service_position", fire_building.global_position)
			dispatcher.publish(
				StringName("firewood_%s" % record.cell),
				CourierTaskScript.Kind.BUILDING_SUPPLY,
				simulation._firewood_task_priority(fire_building, fire_state),
				simulation._get_nearest_delivery_position(fire_position),
				fire_position,
				{"building": fire_building, "supply_kind": "firewood", "resource": "branches"}
			)
