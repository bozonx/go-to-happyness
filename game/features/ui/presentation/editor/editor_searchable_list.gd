class_name EditorSearchableList
extends VBoxContainer

## Reusable editor list: free-text search, category filters and single or
## multiple selection. Owners provide labels and receive original indices back.

signal entry_activated(index: int)
signal entries_selection_changed(indices: Array[int])
signal entry_selection_toggled(index: int, selected: bool)

@onready var _search: LineEdit = $Search
@onready var _filters_row: HFlowContainer = $Filters
@onready var _list: ItemList = $List

var _all_entries: Array[String] = []
var _source_indices: Array[int] = []
var _selected_source_index := -1
var _selected_source_indices: Array[int] = []
var _filters: Array[String] = []
var _active_filter := ""
var _empty_hint := ""
var _has_content := false


func _ready() -> void:
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_entries())
	_list.item_selected.connect(_on_item_selected)
	_list.multi_selected.connect(_on_multi_selected)
	_list.item_activated.connect(_on_item_selected)


func set_entries(entries: Array[String], empty_hint := "", selected_index := -1,
		filters: Array[String] = [], selected_indices: Array = [], allow_multiple := false) -> void:
	_all_entries = entries.duplicate()
	_empty_hint = empty_hint
	_selected_source_index = selected_index
	_selected_source_indices.assign(selected_indices)
	_filters = filters.duplicate()
	if not _filters.has(_active_filter):
		_active_filter = ""
	_has_content = not entries.is_empty() or not empty_hint.is_empty()
	_list.select_mode = ItemList.SELECT_MULTI if allow_multiple else ItemList.SELECT_SINGLE
	_search.visible = _has_content and not entries.is_empty()
	_rebuild_filter_buttons()
	_rebuild_entries()


func has_content() -> bool:
	return _has_content


func item_count() -> int:
	return _list.item_count


func _rebuild_entries() -> void:
	_list.clear()
	_source_indices.clear()
	var query := _search.text.strip_edges().to_lower()
	for source_index in _all_entries.size():
		var entry := _all_entries[source_index]
		if not _active_filter.is_empty() and not entry.begins_with(_active_filter):
			continue
		if not query.is_empty() and not entry.to_lower().contains(query):
			continue
		var visible_index := _list.add_item(entry)
		_source_indices.append(source_index)
		if source_index == _selected_source_index or source_index in _selected_source_indices:
			_list.select(visible_index)
	if _all_entries.is_empty() and not _empty_hint.is_empty():
		var hint_index := _list.add_item(_empty_hint)
		_list.set_item_disabled(hint_index, true)


func _rebuild_filter_buttons() -> void:
	for child in _filters_row.get_children():
		child.queue_free()
	_filters_row.visible = _has_content and not _all_entries.is_empty() and not _filters.is_empty()
	if not _filters_row.visible:
		return
	for filter in ["Все"] + _filters:
		var button := Button.new()
		button.text = filter
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = (_active_filter.is_empty() and filter == "Все") or filter == _active_filter
		var target_filter: String = "" if filter == "Все" else filter
		button.pressed.connect(func() -> void:
			_active_filter = target_filter
			_rebuild_filter_buttons()
			_rebuild_entries())
		_filters_row.add_child(button)


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _source_indices.size() and _list.select_mode == ItemList.SELECT_SINGLE:
		entry_activated.emit(_source_indices[index])


func _on_multi_selected(_index: int, _selected: bool) -> void:
	if _list.select_mode != ItemList.SELECT_MULTI:
		return
	var indices: Array[int] = []
	for visible_index: int in _list.get_selected_items():
		if visible_index >= 0 and visible_index < _source_indices.size():
			indices.append(_source_indices[visible_index])
	entries_selection_changed.emit(indices)
	if _index >= 0 and _index < _source_indices.size():
		entry_selection_toggled.emit(_source_indices[_index], _selected)
