class_name SettlementServicePocketManager
extends RefCounted

## Manages service pocket registration/unregistration and building entrance
## position metadata. Extracted from SettlementGame to reduce monolithic
## file size.

const SERVICE_PAD_OFFSET := 1.0

var runtime: BuildingServicePocketPort


func _init(p_runtime: BuildingServicePocketPort) -> void:
	runtime = p_runtime


func register_service_entrance(building: Node3D, blueprint: Dictionary, home_entrance := false, show_marker := true) -> void:
	# A completed construction-site node may still carry builder access metadata.
	# Rebuild the public/staff endpoints from the completed blueprint only.
	for key in [&"service_positions", &"service_position", &"entrance_positions", &"entrance_position"]:
		if building.has_meta(key):
			building.remove_meta(key)
	var service_positions := BuildingAccessPoints.worker_positions(building, blueprint, SERVICE_PAD_OFFSET)
	var service_local_positions := BuildingAccessPoints.worker_local_positions(blueprint, SERVICE_PAD_OFFSET)
	if not service_positions.is_empty():
		building.set_meta("service_positions", service_positions)
		building.set_meta("service_position", service_positions[0])
		for position in service_positions:
			runtime.service_pockets.append(ServicePocketRecord.new(runtime.cell_from_position.call(position), building))
		if show_marker:
			for local in service_local_positions:
				if runtime.add_service_marker.is_valid():
					runtime.add_service_marker.call(building, local)
	var visitor_positions := BuildingAccessPoints.visitor_positions(building, blueprint, SERVICE_PAD_OFFSET)
	var visitor_local_positions := BuildingAccessPoints.visitor_local_positions(blueprint, SERVICE_PAD_OFFSET)
	if visitor_positions.is_empty() and home_entrance and not service_positions.is_empty():
		visitor_positions = service_positions
		visitor_local_positions = service_local_positions
	if not visitor_positions.is_empty():
		building.set_meta("entrance_positions", visitor_positions)
		building.set_meta("entrance_position", visitor_positions[0])
		if service_positions.is_empty():
			building.set_meta("service_positions", visitor_positions)
			building.set_meta("service_position", visitor_positions[0])
		for local in visitor_local_positions:
			if runtime.add_visitor_marker.is_valid():
				runtime.add_visitor_marker.call(building, local)


func register_service_pockets(node: Node3D) -> void:
	if not node.has_meta("service_positions"):
		return
	var positions: Array = node.get_meta("service_positions")
	for position in positions:
		if position is Vector3:
			runtime.service_pockets.append(ServicePocketRecord.new(runtime.cell_from_position.call(position), node))


func unregister_service_pockets(node: Node3D) -> void:
	for index in range(runtime.service_pockets.size() - 1, -1, -1):
		if runtime.service_pockets[index].node == node:
			runtime.service_pockets.remove_at(index)


func unregister_navigation_footprint(center: Vector3, footprint: Vector2i) -> void:
	for index in range(runtime.service_pockets.size() - 1, -1, -1):
		var pocket: ServicePocketRecord = runtime.service_pockets[index]
		if is_instance_valid(pocket.node) and pocket.node.global_position == center:
			runtime.service_pockets.remove_at(index)
