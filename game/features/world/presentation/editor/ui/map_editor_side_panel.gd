class_name MapEditorSidePanel
extends PanelContainer

## Map card, inspector and entity list, down the right edge (map_editor.md §3.2).
##
## The card at the top is what the document is — name, board, unsaved state,
## how deep the undo stack goes. It sits here rather than in the top bar for the
## reason the building editor puts its blueprint's name and id on the right: the
## top bar is where you act, the right panel is where you read.
##
## The inspector shows the selected object's properties or, with nothing
## selected, the current tool's settings — which is why in phases 1 it is never
## empty even though nothing is selectable yet.
##
## The list is the only way to find an entity a building is standing on top of.
## It stays in the layout from phase 1 with an explanation of what will fill it,
## rather than appearing later and moving everything else on screen.
##
## Everything sits in a scroll because the inspector's length is the mode's
## choice, not the panel's: a mode with four lines more of settings must not be
## able to make the editor taller than the window it is running in.

signal entry_activated(index: int)
signal settings_requested

@onready var _map_title_row: HBoxContainer = $Margin/Scroll/Rows/MapTitleRow
@onready var _map_title: Label = $Margin/Scroll/Rows/MapTitleRow/MapTitle
@onready var _settings_button: Button = $Margin/Scroll/Rows/MapTitleRow/SettingsButton
@onready var _map_info: Label = $Margin/Scroll/Rows/MapInfo
@onready var _inspector_title: Label = $Margin/Scroll/Rows/InspectorTitle
@onready var _inspector: Label = $Margin/Scroll/Rows/Inspector
@onready var _list_title: Label = $Margin/Scroll/Rows/ListTitle
@onready var _list: ItemList = $Margin/Scroll/Rows/List


func _ready() -> void:
	_list.item_activated.connect(func(index: int) -> void: entry_activated.emit(index))
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())


func set_map_info(lines: Array[String]) -> void:
	_map_title.text = lines[0] if not lines.is_empty() else ""
	_map_info.text = "\n".join(lines.slice(1))


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
