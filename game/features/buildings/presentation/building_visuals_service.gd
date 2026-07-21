class_name BuildingVisualsService
extends RefCounted

## Handles building presentation visuals: entrance markers (staff & visitor),
## and house light instantiations.

const EntranceMarkerScene = preload("res://game/features/buildings/presentation/entrance_marker.tscn")
const HouseLightScene = preload("res://game/features/buildings/presentation/house_light.tscn")

var simulation: Node


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func add_service_entrance_marker(building: Node3D, marker_local: Vector3) -> void:
	var marker_node := EntranceMarkerScene.instantiate() as Node3D
	marker_node.position = marker_local
	var marker := marker_node.get_node("Marker") as MeshInstance3D
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("17191c")
	marker_material.roughness = 0.95
	marker.material_override = marker_material
	var sign := marker_node.get_node("Sign") as Label3D
	sign.text = "STAFF"
	sign.modulate = Color("e5c86b")
	var light := marker_node.get_node("Light") as OmniLight3D
	building.add_child(marker_node)
	simulation.entrance_lights.append(light)


func add_visitor_entrance_marker(building: Node3D, marker_local: Vector3) -> void:
	var marker_node := EntranceMarkerScene.instantiate() as Node3D
	marker_node.position = marker_local
	var marker := marker_node.get_node("Marker") as MeshInstance3D
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("1a3a2a")
	marker_material.roughness = 0.95
	marker.material_override = marker_material
	var sign := marker_node.get_node("Sign") as Label3D
	sign.text = "VISITOR"
	sign.modulate = Color("7ec8a0")
	var light := marker_node.get_node("Light") as OmniLight3D
	light.light_color = Color("a8e6c0")
	building.add_child(marker_node)
	simulation.entrance_lights.append(light)


func add_house_light(house: Node3D) -> void:
	var light := HouseLightScene.instantiate() as OmniLight3D
	var entrance_local := Vector3(0.0, 2.0, -house.get_meta("footprint", Vector2i(5, 5)).y * 0.5 - 0.35)
	if house.has_meta("service_positions"):
		var positions: Array = house.get_meta("service_positions")
		if not positions.is_empty() and positions[0] is Vector3:
			entrance_local = house.to_local(positions[0]) + Vector3.UP * 2.0
	light.position = entrance_local
	house.add_child(light)
	var off_minute: int = simulation.random.randi_range(22 * 60, 26 * 60) % (24 * 60)
	simulation.house_lights.append({"light": light, "house": house, "off_minute": off_minute})
