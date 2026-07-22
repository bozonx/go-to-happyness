class_name PocketTakeMenuController
extends RefCounted

const PocketTakeItemRowScene = preload("res://game/features/citizens/presentation/pocket_take_item_row.tscn")
const S = preload("res://game/features/ui/domain/game_strings.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_pocket_take_menu(warehouse_index := -1) -> void:
	if simulation == null:
		return
	simulation.pocket_take_warehouse_index = warehouse_index
	simulation.pocket_take_menu.visible = true
	simulation.pocket_menu_open = true
	if simulation.is_first_person:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	refresh_pocket_take_menu()


func close_pocket_take_menu() -> void:
	if simulation == null:
		return
	simulation.pocket_take_menu.visible = false
	simulation.pocket_menu_open = false
	simulation.pocket_take_warehouse_index = -1
	if simulation.is_first_person:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func refresh_pocket_take_menu() -> void:
	if simulation == null or simulation.pocket_take_menu == null:
		return
	simulation.pocket_take_menu.clear_items()
	var warehouse_index: int = simulation.pocket_take_warehouse_index if simulation.pocket_take_warehouse_index >= 0 else simulation._nearby_warehouse_index()
	var warehouse_amount := func(resource_type: String) -> int:
		if warehouse_index >= 0:
			return simulation.settlement.warehouses[warehouse_index].amount(resource_type)
		return simulation.settlement.amount(resource_type)
	var displayed_resources: Array[String] = simulation.settlement.era_resources()
	for resource_type in displayed_resources:
		var stored: int = warehouse_amount.call(resource_type)
		if stored <= 0:
			continue
		var row: PocketTakeItemRow = PocketTakeItemRowScene.instantiate()
		row.setup(resource_type, stored)
		row.take_one_requested.connect(simulation._take_resource_into_pocket.bind(resource_type, 1))
		row.take_all_requested.connect(func():
			simulation._take_resource_into_pocket(resource_type, simulation._pocket_space_for(resource_type))
		)
		simulation.pocket_take_menu.item_list.add_child(row)
	simulation.pocket_take_menu_title.text = S.TAKE_FROM_WAREHOUSE_FORMAT % [simulation._pocket_total(), simulation.POCKET_CAPACITY]
