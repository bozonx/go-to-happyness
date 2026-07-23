class_name WarehouseMenuController
extends RefCounted

const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const WarehouseStateScript = preload("res://game/features/settlement/domain/warehouse_state.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_warehouse_menu() -> void:
	if simulation == null:
		return
	simulation.selected_builder = null
	simulation.ui_manager.build_menu.visible = false
	simulation.build_menu_is_global = false
	simulation.selection_marker.visible = false
	simulation.build_mode = ""
	simulation.ui_manager.warehouse_menu.visible = true
	refresh_warehouse_menu()


func refresh_warehouse_menu() -> void:
	if simulation == null or simulation.selected_warehouse == null:
		return
	if simulation.ui_manager.warehouse_menu == null:
		return
	var selected_position: Vector3 = simulation.selected_warehouse.get_meta("service_position", simulation.selected_warehouse.global_position)
	var index: int = simulation.warehouse_positions.find(selected_position)
	var selected_warehouse_state: WarehouseState = null
	if index >= 0 and index < simulation.settlement.warehouses.size():
		selected_warehouse_state = simulation.settlement.warehouses[index]
	var warehouses: int = simulation.warehouse_positions.size()
	var total_capacity: int = simulation.settlement.storage_capacity(warehouses)
	var total_used: float = simulation.settlement.storage_used_units()
	var free: float = simulation.settlement.storage_free_units(warehouses)
	var title_text := ""
	if selected_warehouse_state != null:
		var selected_used: float = selected_warehouse_state.used_units(SettlementStateScript.STORAGE_WEIGHTS)
		title_text = "Warehouse %d\nThis: %d/%d u   Total: %d/%d u   Free: %d" % [index + 1, int(ceil(selected_used)), selected_warehouse_state.capacity, int(ceil(total_used)), total_capacity, int(floor(free))]
	else:
		title_text = "Storage\nTotal: %d/%d u   Free: %d" % [int(ceil(total_used)), total_capacity, int(floor(free))]

	var resource_rows: Array[Dictionary] = []
	var era_res: Array[String] = simulation.settlement.era_resources()
	for resource_type in era_res:
		var weight: int = simulation.settlement.storage_weight(resource_type)
		var stored: int = simulation.settlement.amount(resource_type) if selected_warehouse_state == null else selected_warehouse_state.amount(resource_type)
		var stored_units: int = stored * weight
		var accepted: bool = selected_warehouse_state != null and selected_warehouse_state.accepts(resource_type)
		resource_rows.append({
			"label": "%s  %d u" % [resource_type, int(ceil(stored_units))],
			"accepted": accepted,
			"stored": stored,
			"resource_type": resource_type,
		})

	var cover_text := ""
	var cover_disabled := false
	if simulation.settlement.warehouse_tarp_covered:
		cover_text = "Tarp cover active"
		cover_disabled = true
	elif simulation.settlement.can_cover_warehouse_with_tarp():
		cover_text = "Stretch tarp cover (-1 tarp)"
	else:
		cover_text = "Needs 1 tarp to cover"
		cover_disabled = true

	var state := {
		"title_text": title_text,
		"resource_rows": resource_rows,
		"cover_button": {"text": cover_text, "disabled": cover_disabled},
	}
	simulation.ui_manager.warehouse_menu.update_state(state)


func toggle_warehouse_accept(accepted: bool, resource_type: String) -> void:
	if simulation == null or simulation.selected_warehouse == null:
		return
	var index: int = simulation.storage_routing_service.warehouse_index_for_building(simulation.selected_warehouse)
	simulation.settlement.set_warehouse_accepted(index, resource_type, accepted)
	refresh_warehouse_menu()


func dump_warehouse_resource(resource_type: String) -> void:
	if simulation == null or simulation.selected_warehouse == null:
		return
	var selected_position: Vector3 = simulation.selected_warehouse.get_meta("service_position", simulation.selected_warehouse.global_position)
	var index: int = simulation.storage_routing_service.warehouse_index_for_building(simulation.selected_warehouse)
	var count: int = simulation.settlement.warehouse_amount(resource_type, index)
	if count <= 0:
		return
	var dumped: int = simulation.settlement.dump_warehouse_resource(index, resource_type, count)
	if dumped > 0:
		var pile: Dictionary = {resource_type: dumped}
		simulation.resource_pile_service.drop_overflow_as_piles(pile, selected_position)
		simulation._update_interface("Dumped %d %s from the warehouse." % [dumped, resource_type])
	refresh_warehouse_menu()


func cover_warehouse_with_tarp() -> void:
	if simulation == null:
		return
	if simulation.settlement.cover_warehouse_with_tarp():
		simulation._update_interface("The open heap is now covered with a tarp.")
	refresh_warehouse_menu()
