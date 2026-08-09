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
@onready var _searchable_list: EditorSearchableList = $Margin/Scroll/Rows/SearchableList

var _has_inspector_lines: bool = false
var _has_inspector_properties: bool = false
var _has_fill_transform: bool = false
var _has_list: bool = false


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
	_searchable_list.entry_activated.connect(func(index: int) -> void: entry_activated.emit(index))
	_searchable_list.entries_selection_changed.connect(func(indices: Array[int]) -> void: entries_selection_changed.emit(indices))


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
	_has_list = not title.is_empty() and (not entries.is_empty() or not empty_hint.is_empty())
	_searchable_list.set_entries(entries, empty_hint, selected_index, filters, selected_indices, allow_multiple)
	_update_section_visibilities()


func _update_section_visibilities() -> void:
	var has_inspector := _has_inspector_lines or _has_inspector_properties or _has_fill_transform
	_inspector_title.visible = has_inspector
	_inspector.visible = _has_inspector_lines
	_fill_transform_fields.visible = _has_fill_transform
	_inspector_fields.visible = _has_inspector_properties
	_list_title.visible = _has_list
	_searchable_list.visible = _has_list
	_map_separator.visible = has_inspector or _has_list
	_separator.visible = has_inspector and _has_list
