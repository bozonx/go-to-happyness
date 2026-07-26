class_name SettlementLogisticsController
extends RefCounted

## Manages courier task support, firewood priority, repair reservation
## reconciliation, construction material sourcing, canteen delivery state,
## and delivery position resolution.
## Extracted from SettlementGame to reduce its method count.


var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func firewood_task_priority(building: Node3D, fire_state: FireSourceState) -> int:
	var phase: int = fire_state.phase_at(int(game.game_minutes))
	var is_main := building == game.campfire_node
	if phase == FireSourceState.Phase.EMBERS or fire_state.fuel <= 1:
		return 120 if is_main else 115
	if phase == FireSourceState.Phase.DYING:
		return 112 if is_main else 110
	return 108 if is_main else 105


func reconcile_repair_reservations() -> void:
	# A repair delivery can be interrupted by the end-of-day scheduler or a route reset.
	# Return its reservation when no courier still owns it, otherwise the building
	# can remain permanently reserved without ever being repaired.
	for record in game.building_registry.records():
		var building := record.node
		if not is_instance_valid(building):
			continue
		var state: BuildingRuntimeState = record.runtime_state()
		if not state.repair_reserved:
			continue
		var has_carrier := false
		for citizen in game.citizens:
			if citizen != null and citizen.state in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE] and citizen.building_supply_kind == "repair" and citizen.construction_site == building:
				has_carrier = true
				break
		if not has_carrier:
			building.set_meta("repair_reserved", false)


func construction_material_sources(resource_type: String, from_position: Vector3 = Vector3.ZERO) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if game.settlement.amount(resource_type) > 0:
		if not game.warehouse_positions.is_empty():
			for index in range(mini(game.warehouse_positions.size(), game.settlement.warehouses.size())):
				if game.settlement.warehouse_amount(resource_type, index) <= 0:
					continue
				var position := game.warehouse_positions[index]
				# The position keeps task identity stable enough to invalidate a task when
				# warehouses are demolished; the index makes pickup remove the same stock.
				sources.append({"kind": "storage", "id": "storage_%s" % game.cell_from_position(position), "position": position, "warehouse_index": index})
			sources.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return from_position.distance_squared_to(left.position) < from_position.distance_squared_to(right.position)
			)
			return sources
		# Before the first warehouse is built, all resources live in the virtual
		# stockpile. Couriers pull from that unlimited reserve at the camp entrance
		# so the bootstrap warehouse and main campfire can still be supplied.
		sources.append({"kind": "open_storage", "id": "open_storage", "position": get_nearest_delivery_position(from_position)})
	# Ground piles belong exclusively to cleaners. Construction starts only after
	# their contents have been delivered to the settlement stock.
	return sources


func construction_source_available(resource_type: String, source: Dictionary) -> int:
	var warehouse_index := int(source.get("warehouse_index", -1))
	return game.settlement.warehouse_amount(resource_type, warehouse_index) if warehouse_index >= 0 else game.settlement.amount(resource_type)


func set_canteen_delivery_state(active: bool, carrier: Citizen, amount: int) -> void:
	game.pending_canteen_delivery = active
	game.pending_canteen_carrier = carrier
	game.pending_canteen_delivery_amount = amount


func set_canteen_food(value: int) -> void:
	game.canteen_food = value


func is_canteen_delivery_in_progress() -> bool:
	return is_instance_valid(game.pending_canteen_carrier) and game.pending_canteen_carrier.state in [Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY]


func return_in_transit_building_supplies(building: Node3D) -> void:
	for citizen in game.citizens:
		if citizen.construction_site != building or citizen.state not in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]:
			continue
		if citizen.carried_amount > 0 and not citizen.construction_delivery_resource.is_empty():
			game.settlement.add(citizen.construction_delivery_resource, citizen.carried_amount)
		citizen.carried_amount = 0
		citizen.construction_site = null
		citizen.idle()


func get_delivery_position() -> Vector3:
	return get_nearest_delivery_position(Vector3.ZERO)


func get_nearest_delivery_position(from: Vector3) -> Vector3:
	var warehouse_index := game.storage_routing_service.find_reachable_warehouse_index(from, "", 1, false)
	if warehouse_index >= 0:
		return game.warehouse_positions[warehouse_index]
	if is_instance_valid(game.campfire_node) and game.is_route_reachable(from, game.campfire_node.global_position, false):
		return game.campfire_node.global_position
	if is_instance_valid(game.entrance_stone):
		return game.entrance_stone.global_position
	return Vector3.ZERO
