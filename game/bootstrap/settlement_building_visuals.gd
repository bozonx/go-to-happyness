class_name SettlementBuildingVisuals
extends RefCounted

## Handles procedural visual node creation for buildings: selectors, fire lights,
## status indicators, warehouse fill labels, gathering place visuals, house
## lights, and demolition markers. Extracted from SettlementGame.

const BuildingSelectorScene = preload("res://game/features/buildings/presentation/building_selector.tscn")
const FireLightScene = preload("res://game/features/buildings/presentation/fire_light.tscn")
const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")
const GatheringPlaceVisualScene = preload("res://game/features/buildings/presentation/gathering_place_visual.tscn")

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func add_building_selector(building: Node3D, group_name: String, footprint: Vector2i) -> void:
	var selector := BuildingSelectorScene.instantiate() as Area3D
	selector.add_to_group(group_name)
	var collision := selector.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = Vector3(footprint.x + 0.25, 4.5, footprint.y + 0.25)
	collision.position.y = 2.0
	building.add_child(selector)


func add_selector_to_node(node: Node3D, group_name: String, shape_size: Vector3, offset := Vector3.ZERO) -> void:
	var selector := BuildingSelectorScene.instantiate() as Area3D
	selector.add_to_group(group_name)
	var collision := selector.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	shape.size = shape_size
	collision.position = offset
	node.add_child(selector)


func add_fire_light(building: Node3D, energy := 2.5, light_range := 8.0) -> void:
	var fire_light := FireLightScene.instantiate() as OmniLight3D
	fire_light.light_energy = energy
	fire_light.omni_range = light_range
	building.add_child(fire_light)


func add_building_status_indicator(building: Node3D) -> void:
	if not is_instance_valid(building) or building.has_meta("status_indicator"):
		return
	var indicator := BillboardLabelScene.instantiate() as Label3D
	indicator.position = Vector3(0.0, 4.2, 0.0)
	indicator.font_size = 28
	indicator.outline_size = 5
	indicator.visible = false
	building.add_child(indicator)
	building.set_meta("status_indicator", indicator)
	game.building_status_indicators.append(indicator)


func add_warehouse_fill_label(building: Node3D) -> void:
	if game.warehouse_fill_label_controller != null:
		game.warehouse_fill_label_controller.add_warehouse_fill_label(building)


func create_gathering_place_visual(building: Node3D) -> void:
	var visual := GatheringPlaceVisualScene.instantiate() as Node3D
	building.add_child(visual)


func add_house_light(house: Node3D) -> void:
	if game.building_visuals_service != null:
		game.building_visuals_service.add_house_light(house)


func add_demolition_marker(building: Node3D) -> void:
	if building.has_meta("demolition_marker"):
		return
	var marker: Label3D = BillboardLabelScene.instantiate() as Label3D
	marker.text = "DEMOLISH"
	marker.position = Vector3(0.0, 5.2, 0.0)
	marker.font_size = 32
	marker.outline_size = 6
	marker.modulate = Color("ef4f45")
	building.add_child(marker)
	building.set_meta("demolition_marker", marker)
