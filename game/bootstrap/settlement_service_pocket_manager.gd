class_name SettlementServicePocketManager
extends RefCounted

## Manages service pocket registration/unregistration and building entrance
## position metadata. Extracted from SettlementGame to reduce monolithic
## file size.

const SERVICE_PAD_OFFSET := 1.0

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func register_service_entrance(building: Node3D, blueprint: Dictionary, home_entrance := false, show_marker := true) -> void:
	var building_type := str(blueprint.get("type", ""))
	var service_positions := BuildingEntrancePositions.positions(building, blueprint.footprint, SERVICE_PAD_OFFSET)
	if not service_positions.is_empty():
		building.set_meta("service_positions", service_positions)
		building.set_meta("service_position", service_positions[0])
		for position in service_positions:
			game.service_pockets.append({"cell": game._cell_from_position(position), "node": building})
		if show_marker:
			var offsets := BuildingEntrancePositions.offsets(building_type)
			if offsets.is_empty():
				offsets = [Vector2i(0, -blueprint.footprint.y / 2)]
			var local_positions := BuildingEntrancePositions.local_positions(blueprint.footprint, offsets, SERVICE_PAD_OFFSET)
			for local in local_positions:
				if game.building_visuals_service != null:
					game.building_visuals_service.add_service_entrance_marker(building, local)
	var visitor_positions := BuildingEntrancePositions.visitor_positions(building, blueprint.footprint, SERVICE_PAD_OFFSET)
	if visitor_positions.is_empty() and home_entrance and not service_positions.is_empty():
		visitor_positions = service_positions
	if not visitor_positions.is_empty():
		building.set_meta("entrance_positions", visitor_positions)
		building.set_meta("entrance_position", visitor_positions[0])
		if service_positions.is_empty():
			building.set_meta("service_positions", visitor_positions)
			building.set_meta("service_position", visitor_positions[0])
		var v_offsets := BuildingEntrancePositions.visitor_offsets(building_type)
		if not v_offsets.is_empty():
			var v_local_positions := BuildingEntrancePositions.local_positions(blueprint.footprint, v_offsets, SERVICE_PAD_OFFSET)
			for local in v_local_positions:
				if game.building_visuals_service != null:
					game.building_visuals_service.add_visitor_entrance_marker(building, local)


func register_service_pockets(node: Node3D) -> void:
	if not node.has_meta("service_positions"):
		return
	var positions: Array = node.get_meta("service_positions")
	for position in positions:
		if position is Vector3:
			game.service_pockets.append({"cell": game._cell_from_position(position), "node": node})


func unregister_service_pockets(node: Node3D) -> void:
	for index in range(game.service_pockets.size() - 1, -1, -1):
		if game.service_pockets[index].node == node:
			game.service_pockets.remove_at(index)


func unregister_navigation_footprint(center: Vector3, footprint: Vector2i) -> void:
	for index in range(game.service_pockets.size() - 1, -1, -1):
		var pocket: Dictionary = game.service_pockets[index]
		if is_instance_valid(pocket.node) and pocket.node.global_position == center:
			game.service_pockets.remove_at(index)
