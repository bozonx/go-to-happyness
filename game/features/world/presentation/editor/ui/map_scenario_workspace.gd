class_name MapScenarioWorkspace
extends PanelContainer

## Full-width, non-spatial workspace for the scenario layer. Scenario rows need
## room to read as when / if / then; keeping them in the narrow entity list left
## an unused map between the row and its inspector.

signal entry_selected(index: int)
signal map_requested

@onready var _summary: Label = $Margin/Rows/Header/Summary
@onready var _map_button: Button = $Margin/Rows/Header/MapButton
@onready var _search: LineEdit = $Margin/Rows/Search
@onready var _list: ItemList = $Margin/Rows/List
@onready var _empty_hint: Label = $Margin/Rows/EmptyHint

var _entries: Array[String] = []
var _source_indices: Array[int] = []
var _selected_source_index := -1


func _ready() -> void:
	_list.item_selected.connect(_on_item_selected)
	_list.item_activated.connect(_on_item_selected)
	_search.text_changed.connect(func(_value: String) -> void: _rebuild())
	_map_button.pressed.connect(func() -> void: map_requested.emit())


func set_content(summary: String, entries: Array[String], empty_hint: String,
		selected_index: int, zone_id: StringName) -> void:
	_summary.text = summary
	_entries = entries.duplicate()
	_selected_source_index = selected_index
	_empty_hint.text = empty_hint
	_map_button.text = (
		"◎ Показать область «%s»" % zone_id
		if not String(zone_id).is_empty()
		else "◎ Показать карту"
	)
	_rebuild()


func _rebuild() -> void:
	_list.clear()
	_source_indices.clear()
	var query := _search.text.strip_edges().to_lower()
	for source_index in _entries.size():
		var entry := _entries[source_index]
		if not query.is_empty() and not entry.to_lower().contains(query):
			continue
		var visible_index := _list.add_item(entry)
		_source_indices.append(source_index)
		if source_index == _selected_source_index:
			_list.select(visible_index)
	_empty_hint.visible = _entries.is_empty()
	_search.visible = not _entries.is_empty()


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _source_indices.size():
		entry_selected.emit(_source_indices[index])
