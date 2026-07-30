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
signal property_committed(property_name: StringName, value: Variant)

@onready var _map_title: Label = $Margin/Scroll/Rows/MapTitleRow/MapTitle
@onready var _map_info: Label = $Margin/Scroll/Rows/MapInfo
@onready var _map_separator: HSeparator = $Margin/Scroll/Rows/MapSeparator
@onready var _inspector_title: Label = $Margin/Scroll/Rows/InspectorTitle
@onready var _inspector: Label = $Margin/Scroll/Rows/Inspector
@onready var _inspector_fields: VBoxContainer = $Margin/Scroll/Rows/InspectorFields
@onready var _separator: HSeparator = $Margin/Scroll/Rows/Separator
@onready var _list_title: Label = $Margin/Scroll/Rows/ListTitle
@onready var _list: ItemList = $Margin/Scroll/Rows/List

var _has_inspector_lines: bool = false
var _has_inspector_properties: bool = false
var _has_list: bool = false


func _ready() -> void:
	_list.item_activated.connect(func(index: int) -> void: entry_activated.emit(index))


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
	for child in _inspector_fields.get_children():
		child.queue_free()
	_has_inspector_properties = false
	if not properties.is_empty():
		var sections: Dictionary = {}
		for property: EntityPropertyDef in properties:
			if property.is_visible_for(values):
				if not sections.has(property.section):
					sections[property.section] = []
				sections[property.section].append(property)
				_has_inspector_properties = true
		for section: StringName in EntityPropertyDef.SECTIONS:
			if not sections.has(section):
				continue
			var heading := Label.new()
			heading.text = _section_name(section)
			heading.add_theme_font_size_override("font_size", 12)
			_inspector_fields.add_child(heading)
			for property: EntityPropertyDef in sections[section]:
				_add_property_control(property, values.get(property.name, property.default))
	_update_section_visibilities()


func _add_property_control(property: EntityPropertyDef, value: Variant) -> void:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = property.label + (" · " + property.unit if not property.unit.is_empty() else "")
	row.add_child(label)
	var control: Control = null
	match property.type:
		EntityPropertyDef.TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(value)
			check.toggled.connect(func(next: bool) -> void: property_committed.emit(property.name, next))
			control = check
		EntityPropertyDef.TYPE_INT, EntityPropertyDef.TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.allow_greater = property.maximum == null
			spin.allow_lesser = property.minimum == null
			spin.min_value = float(property.minimum) if property.minimum != null else -1000000.0
			spin.max_value = float(property.maximum) if property.maximum != null else 1000000.0
			spin.step = float(property.step) if property.step != null else (1.0 if property.type == EntityPropertyDef.TYPE_INT else 0.1)
			spin.value = float(value) if value != null else 0.0
			var line := spin.get_line_edit()
			line.text_submitted.connect(func(_text: String) -> void: property_committed.emit(property.name, int(spin.value) if property.type == EntityPropertyDef.TYPE_INT else spin.value))
			line.focus_exited.connect(func() -> void: property_committed.emit(property.name, int(spin.value) if property.type == EntityPropertyDef.TYPE_INT else spin.value))
			control = spin
		EntityPropertyDef.TYPE_ENUM:
			var option := OptionButton.new()
			for entry: Variant in property.options:
				option.add_item(String(entry))
				if String(entry) == String(value):
					option.select(option.item_count - 1)
			option.disabled = option.item_count == 0
			option.item_selected.connect(func(index: int) -> void: property_committed.emit(property.name, option.get_item_text(index)))
			control = option
		EntityPropertyDef.TYPE_STRING, EntityPropertyDef.TYPE_TEXT:
			var edit: Control = TextEdit.new() if property.type == EntityPropertyDef.TYPE_TEXT else LineEdit.new()
			if edit is TextEdit:
				(edit as TextEdit).text = String(value)
				(edit as TextEdit).focus_exited.connect(func() -> void: property_committed.emit(property.name, (edit as TextEdit).text))
			else:
				(edit as LineEdit).text = String(value)
				(edit as LineEdit).text_submitted.connect(func(text: String) -> void: property_committed.emit(property.name, text))
				(edit as LineEdit).focus_exited.connect(func() -> void: property_committed.emit(property.name, (edit as LineEdit).text))
			control = edit
		EntityPropertyDef.TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = value if value is Color else Color.html(String(value))
			picker.color_changed.connect(func(next: Color) -> void: property_committed.emit(property.name, next))
			control = picker
		EntityPropertyDef.TYPE_VECTOR2, EntityPropertyDef.TYPE_VECTOR3:
			control = _vector_control(property, value)
		EntityPropertyDef.TYPE_FLAGS:
			control = _flags_control(property, value)
		EntityPropertyDef.TYPE_ASSET_REF, EntityPropertyDef.TYPE_ARCHETYPE_REF, EntityPropertyDef.TYPE_ENTITY_REF, EntityPropertyDef.TYPE_ZONE_REF, EntityPropertyDef.TYPE_POINT_REF, EntityPropertyDef.TYPE_ROUTE_REF, EntityPropertyDef.TYPE_ITEM_REF, EntityPropertyDef.TYPE_DIALOG_REF, EntityPropertyDef.TYPE_QUEST_REF, EntityPropertyDef.TYPE_FLAG_REF:
			var reference := LineEdit.new()
			reference.placeholder_text = "идентификатор"
			reference.text = String(value)
			reference.text_submitted.connect(func(text: String) -> void: property_committed.emit(property.name, text))
			reference.focus_exited.connect(func() -> void: property_committed.emit(property.name, reference.text))
			control = reference
		_:
			var unsupported := Label.new()
			unsupported.text = "Тип «%s» будет доступен в следующем подшаге" % property.type
			unsupported.modulate = Color(0.75, 0.65, 0.35)
			control = unsupported
	row.add_child(control)
	_inspector_fields.add_child(row)


func _vector_control(property: EntityPropertyDef, value: Variant) -> Control:
	var row := HBoxContainer.new()
	var count := 2 if property.type == EntityPropertyDef.TYPE_VECTOR2 else 3
	var values: Array = value as Array if value is Array else ([value.x, value.y] if value is Vector2 else ([value.x, value.y, value.z] if value is Vector3 else []))
	while values.size() < count:
		values.append(0.0)
	var spins: Array[SpinBox] = []
	for index in count:
		var spin := SpinBox.new()
		spin.step = float(property.step) if property.step != null else 0.1
		spin.value = float(values[index])
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		spins.append(spin)
		spin.get_line_edit().focus_exited.connect(func() -> void:
			var result: Array = spins.map(func(item: SpinBox) -> float: return item.value)
			property_committed.emit(property.name, result))
	return row


func _flags_control(property: EntityPropertyDef, value: Variant) -> Control:
	var row := VBoxContainer.new()
	var selected: Dictionary = {}
	if value is Array:
		for entry: Variant in value as Array:
			selected[String(entry)] = true
	for entry: Variant in property.options:
		var check := CheckBox.new()
		check.text = String(entry)
		check.button_pressed = selected.has(String(entry))
		check.toggled.connect(func(_pressed: bool) -> void:
			var values: Array = []
			for child: Node in row.get_children():
				if child is CheckBox and (child as CheckBox).button_pressed:
					values.append((child as CheckBox).text)
			property_committed.emit(property.name, values))
		row.add_child(check)
	return row


static func _section_name(section: StringName) -> String:
	return {
		&"main": "Основное", &"transform": "Трансформ", &"appearance": "Внешний вид",
		&"state": "Состояние", &"gameplay": "Игровые свойства", &"behavior": "Поведение", &"links": "Связи",
	}.get(section, String(section))


func set_entries(title: String, entries: Array[String], empty_hint := "") -> void:
	_list_title.text = title
	_list.clear()
	_has_list = not title.is_empty() and (not entries.is_empty() or not empty_hint.is_empty())
	if _has_list:
		if entries.is_empty():
			if not empty_hint.is_empty():
				var index := _list.add_item(empty_hint)
				_list.set_item_disabled(index, true)
		else:
			for entry: String in entries:
				_list.add_item(entry)
	_update_section_visibilities()


func _update_section_visibilities() -> void:
	var has_inspector := _has_inspector_lines or _has_inspector_properties
	_inspector_title.visible = has_inspector
	_inspector.visible = _has_inspector_lines
	_inspector_fields.visible = _has_inspector_properties
	_list_title.visible = _has_list
	_list.visible = _has_list
	_map_separator.visible = has_inspector or _has_list
	_separator.visible = has_inspector and _has_list
