class_name SettlementBuildingManagement
extends RefCounted

## Manages building setup and queries: entrance sign node creation, canteen
## selection, kitchen activation, and entrance anchor position resolution.
## Extracted from SettlementGame.

const CELL_SIZE := BuildingBlueprints.BLOCK_SIZE

var runtime: BuildingManagementPort


func _init(p_runtime: BuildingManagementPort) -> void:
	runtime = p_runtime


func setup_entrance_sign_node(building: Node3D) -> void:
	if not is_instance_valid(building):
		return
	runtime.entrance_setter.call(building)
	runtime.add_selector.call(building, "entrance_selector", Vector3(2.2, 2.4, 1.0), Vector3(0.0, 1.1, 0.0))
	var label := Label3D.new()
	label.position = Vector3(0.0, 1.26, 0.09)
	label.text = "Settlement"
	label.font_size = 28
	label.modulate = Color("f0dfb2")
	building.add_child(label)
	var light := OmniLight3D.new()
	light.name = "EntranceSignLight"
	light.position = Vector3(0.0, 2.2, 0.0)
	light.light_color = Color(1.0, 0.8353, 0.5412, 1.0)
	light.light_energy = 2.0
	light.light_volumetric_fog_energy = 0.5
	light.omni_range = 5.0
	light.shadow_enabled = true
	building.add_child(light)
	if runtime.configure_entrance_ambient.is_valid():
		runtime.configure_entrance_ambient.call(building)


func entrance_anchor_position() -> Vector3:
	var entrance: Node3D = runtime.entrance_getter.call()
	if is_instance_valid(entrance):
		return entrance.global_position
	var nav_grid: NavGrid = runtime.nav_grid_getter.call()
	return nav_grid.cell_center(Vector2i(-22, 1)) if nav_grid != null else Vector3((Vector2i(-22, 1).x + 0.5) * CELL_SIZE, 0.0, (Vector2i(-22, 1).y + 0.5) * CELL_SIZE)


func activate_kitchen_if_better(building: Node3D, service_position: Vector3) -> void:
	var capacity := BuildingCatalog.kitchen_food_capacity(runtime.building_registry.building_type_for_node(building))
	var canteen: Node3D = runtime.canteen_getter.call()
	var active_capacity := BuildingCatalog.kitchen_food_capacity(runtime.building_registry.building_type_for_node(canteen)) if is_instance_valid(canteen) else 0
	if capacity >= active_capacity:
		runtime.canteen_setter.call(building)
		if building.has_meta("entrance_position"):
			runtime.canteen_position_setter.call(building.get_meta("entrance_position"))
		else:
			runtime.canteen_position_setter.call(building.get_meta("service_position", building.global_position))


func select_best_canteen() -> void:
	var best_kitchen: Node3D = null
	var best_capacity := 0
	for record in runtime.building_registry.records():
		var candidate: Node3D = record.node
		if not is_instance_valid(candidate):
			continue
		var capacity := BuildingCatalog.kitchen_food_capacity(record.building_type)
		if capacity > best_capacity:
			best_kitchen = candidate
			best_capacity = capacity
	runtime.canteen_setter.call(best_kitchen)
	if best_kitchen != null:
		if best_kitchen.has_meta("entrance_position"):
			runtime.canteen_position_setter.call(best_kitchen.get_meta("entrance_position"))
		else:
			runtime.canteen_position_setter.call(best_kitchen.get_meta("service_position", best_kitchen.global_position))
