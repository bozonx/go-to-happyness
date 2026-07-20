class_name WarehouseMenu
extends Panel

signal accept_toggled(accepted: bool, resource_type: String)
signal dump_requested(resource_type: String)
signal cover_requested
signal demolish_requested
signal close_requested

const WarehouseItemRowScene = preload("res://game/features/logistics/presentation/warehouse_item_row.tscn")

@onready var title_label: Label = $TitleLabel
@onready var item_list: VBoxContainer = $ScrollContainer/ItemList
@onready var cover_btn: Button = $ActionsVBox/CoverButton
@onready var demolish_btn: Button = $ActionsVBox/DemolishButton
@onready var close_btn: Button = $ActionsVBox/CloseButton


func _ready() -> void:
	cover_btn.pressed.connect(func(): cover_requested.emit())
	demolish_btn.pressed.connect(func(): demolish_requested.emit())
	close_btn.pressed.connect(func(): close_requested.emit())


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text

	for child in item_list.get_children():
		child.queue_free()

	for item in state.resource_rows:
		var row: WarehouseItemRow = WarehouseItemRowScene.instantiate()
		row.setup(item)
		row.accept_toggled.connect(func(accepted: bool):
			accept_toggled.emit(accepted, item.resource_type)
		)
		row.dump_requested.connect(func():
			dump_requested.emit(item.resource_type)
		)
		item_list.add_child(row)

	var cover: Dictionary = state.cover_button
	cover_btn.text = cover.text
	cover_btn.disabled = cover.disabled
