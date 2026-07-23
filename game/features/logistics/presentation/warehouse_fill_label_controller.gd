class_name WarehouseFillLabelController
extends RefCounted

const BillboardLabelScene = preload("res://game/features/ui/presentation/billboard_label.tscn")
const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func add_warehouse_fill_label(building: Node3D) -> void:
	if simulation == null or not is_instance_valid(building) or building.has_meta("warehouse_fill_label"):
		return
	var label := BillboardLabelScene.instantiate() as Label3D
	label.position = Vector3(0.0, 3.6, 0.0)
	label.font_size = 22
	label.outline_size = 4
	label.visible = false
	building.add_child(label)
	building.set_meta("warehouse_fill_label", label)


func update_warehouse_fill_labels() -> void:
	if simulation == null:
		return
	for i in range(simulation.warehouse_positions.size()):
		var service_pos: Vector3 = simulation.warehouse_positions[i]
		var building: Node3D = simulation.building_registry.building_at_service_position(service_pos)
		if not is_instance_valid(building):
			continue
		var label := building.get_meta("warehouse_fill_label") as Label3D
		if label == null:
			continue
		if not simulation.is_first_person:
			label.visible = false
			continue
		var is_nearby: bool = simulation.player_citizen != null and simulation.player_citizen.global_position.distance_to(service_pos) <= simulation.INTERACTION_RANGE
		if not is_nearby:
			label.visible = false
			continue
		var wh_state: WarehouseState = simulation.settlement.warehouses[i] if i < simulation.settlement.warehouses.size() else null
		if wh_state == null:
			label.visible = false
			continue
		var used: int = int(ceil(wh_state.used_units(SettlementStateScript.STORAGE_WEIGHTS)))
		label.text = "%d / %d" % [used, wh_state.capacity]
		label.modulate = Color("8ecae6") if used < wh_state.capacity else Color("ef6b5b")
		label.visible = true
