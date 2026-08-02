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
signal entries_selection_changed(indices: Array[int])
signal property_committed(property_name: StringName, value: Variant)
signal property_reset_requested(property_name: StringName)
signal reference_pick_requested(property_name: StringName, reference_type: StringName)

@onready var _map_title: Label = $Margin/Scroll/Rows/MapTitleRow/MapTitle
@onready var _map_info: Label = $Margin/Scroll/Rows/MapInfo
@onready var _map_separator: HSeparator = $Margin/Scroll/Rows/MapSeparator
@onready var _inspector_title: Label = $Margin/Scroll/Rows/InspectorTitle
@onready var _inspector: Label = $Margin/Scroll/Rows/Inspector
@onready var _fill_transform_fields: EditorFillTransformInspector = $Margin/Scroll/Rows/FillTransformFields
@onready var _inspector_fields: EditorPropertyInspector = $Margin/Scroll/Rows/InspectorFields
@onready var _separator: HSeparator = $Margin/Scroll/Rows/Separator
@onready var _list_title: Label = $Margin/Scroll/Rows/ListTitle
@onready var _list_search: LineEdit = $Margin/Scroll/Rows/ListSearch
@onready var _list_filters: HFlowContainer = $Margin/Scroll/Rows/ListFilters
@onready var _list: ItemList = $Margin/Scroll/Rows/List

var _has_inspector_lines: bool = false
var _has_inspector_properties: bool = false
var _has_fill_transform: bool = false
var _has_list: bool = false
var _all_entries: Array[String] = []
var _source_indices: Array[int] = []
var _selected_source_index := -1
var _filters: Array[String] = []
var _active_filter := ""


func _ready() -> void:
	_fill_transform_fields.property_committed.connect(func(property_name: StringName, value: Variant) -> void:
		property_committed.emit(property_name, value))
	_fill_transform_fields.property_reset_requested.connect(func(property_name: StringName) -> void:
		property_reset_requested.emit(property_name))
	_inspector_fields.property_committed.connect(func(property_name: StringName, value: Variant) -> void:
		property_committed.emit(property_name, value))
	_inspector_fields.property_reset_requested.connect(func(property_name: StringName) -> void:
		property_reset_requested.emit(property_name))
	_inspector_fields.reference_pick_requested.connect(func(property_name: StringName, reference_type: StringName) -> void:
		reference_pick_requested.emit(property_name, reference_type))
	_list.item_selected.connect(_on_list_item_selected)
	_list.multi_selected.connect(_on_list_multi_selected)
	_list.item_activated.connect(_on_list_item_selected)
	_list_search.text_changed.connect(func(_text: String) -> void: _rebuild_filtered_entries())


func set_map_info(lines: Array[String]) -> void:
	_map_title.text = lines[0] if not lines.is_empty() else ""
	_map_info.text = "\n".join(lines.slice(1))


func set_inspector(title: String, lines: Array[String]) -> void:
	_inspector_title.text = title
	_inspector.text = "\n".join(lines)
	_has_inspector_lines = not lines.is_empty()
	_update_section_visibilities()


## Generic schema-driven inspector for map entities. The panel knows control
## types, never archetype ids; gameplay modules only provide `EntityPropertyDef`.
func set_property_fields(properties: Array[EntityPropertyDef], values: Dictionary) -> void:
	_inspector_fields.set_fields(properties, values)
	_has_inspector_properties = not properties.is_empty()
	_update_section_visibilities()


func set_fill_transform(values: Dictionary, visible: bool, editable := true) -> void:
	_has_fill_transform = visible
	if visible:
		_fill_transform_fields.set_position_visible(values.has(EditorFillTransformInspector.CELL_X))
		_fill_transform_fields.set_values(values, editable)
	_update_section_visibilities()


func set_entries(
	title: String,
	entries: Array[String],
	empty_hint := "",
	selected_index := -1,
	filters: Array[String] = [],
	selected_indices: Array = [],
	allow_multiple := false,
) -> void:
	_list_title.text = title
	_all_entries = entries.duplicate()
	_selected_source_index = selected_index
	_list.select_mode = ItemList.SELECT_MULTI if allow_multiple else ItemList.SELECT_SINGLE
	_list.set_meta("selected_indices", selected_indices)
	_filters = filters.duplicate()
	if not _filters.has(_active_filter):
		_active_filter = ""
	_has_list = not title.is_empty() and (not entries.is_empty() or not empty_hint.is_empty())
	_list_search.visible = _has_list and not entries.is_empty() and _filters.is_empty()
	_list_search.set_meta("empty_hint", empty_hint)
	_rebuild_filter_buttons()
	_rebuild_filtered_entries()
	_update_section_visibilities()


func _rebuild_filtered_entries() -> void:
	_list.clear()
	_source_indices.clear()
	var query := _list_search.text.strip_edges().to_lower()
	for source_index in _all_entries.size():
		var entry := _all_entries[source_index]
		if not _active_filter.is_empty() and not entry.begins_with(_active_filter):
			continue
		if not query.is_empty() and not entry.to_lower().contains(query):
			continue
		var visible_index := _list.add_item(entry)
		_source_indices.append(source_index)
		var selected_indices: Array = _list.get_meta("selected_indices", [])
		if source_index == _selected_source_index or source_index in selected_indices:
			_list.select(visible_index)
	if _all_entries.is_empty():
		var hint := String(_list_search.get_meta("empty_hint", ""))
		if not hint.is_empty():
			var index := _list.add_item(hint)
			_list.set_item_disabled(index, true)


func _rebuild_filter_buttons() -> void:
	for child in _list_filters.get_children():
		child.queue_free()
	_list_filters.visible = _has_list and not _all_entries.is_empty() and not _filters.is_empty()
	if not _list_filters.visible:
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
			_rebuild_filtered_entries())
		_list_filters.add_child(button)


func _on_list_item_selected(index: int) -> void:
	if index >= 0 and index < _source_indices.size():
		if _list.select_mode == ItemList.SELECT_SINGLE:
			entry_activated.emit(_source_indices[index])


func _on_list_multi_selected(_index: int, _selected: bool) -> void:
	if _list.select_mode != ItemList.SELECT_MULTI:
		return
	var indices: Array[int] = []
	for visible_index: int in _list.get_selected_items():
		if visible_index >= 0 and visible_index < _source_indices.size():
			indices.append(_source_indices[visible_index])
	entries_selection_changed.emit(indices)


func _update_section_visibilities() -> void:
	var has_inspector := _has_inspector_lines or _has_inspector_properties or _has_fill_transform
	_inspector_title.visible = has_inspector
	_inspector.visible = _has_inspector_lines
	_fill_transform_fields.visible = _has_fill_transform
	_inspector_fields.visible = _has_inspector_properties
	_list_title.visible = _has_list
	_list_search.visible = _has_list and not _all_entries.is_empty() and _filters.is_empty()
	_list_filters.visible = _has_list and not _all_entries.is_empty() and not _filters.is_empty()
	_list.visible = _has_list
	_map_separator.visible = has_inspector or _has_list
	_separator.visible = has_inspector and _has_list
