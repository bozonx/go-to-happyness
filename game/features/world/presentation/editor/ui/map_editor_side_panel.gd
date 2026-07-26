class_name MapEditorSidePanel
extends PanelContainer

## Inspector above, entity list below, down the right edge (map_editor.md §3.2).
##
## The inspector shows the selected object's properties or, with nothing
## selected, the current tool's settings — which is why in phases 1 it is never
## empty even though nothing is selectable yet.
##
## The list is the only way to find an entity a building is standing on top of.
## It stays in the layout from phase 1 with an explanation of what will fill it,
## rather than appearing later and moving everything else on screen.

signal entry_activated(index: int)

@onready var _inspector_title: Label = $Rows/InspectorTitle
@onready var _inspector: Label = $Rows/Inspector
@onready var _list_title: Label = $Rows/ListTitle
@onready var _list: ItemList = $Rows/List


func _ready() -> void:
	_list.item_activated.connect(func(index: int) -> void: entry_activated.emit(index))


func set_inspector(title: String, lines: Array[String]) -> void:
	_inspector_title.text = title
	_inspector.text = "\n".join(lines)


func set_entries(title: String, entries: Array[String], empty_hint := "") -> void:
	_list_title.text = title
	_list.clear()
	if entries.is_empty():
		if not empty_hint.is_empty():
			var index := _list.add_item(empty_hint)
			_list.set_item_disabled(index, true)
		return
	for entry: String in entries:
		_list.add_item(entry)
