class_name EditorPropertyInspector
extends VBoxContainer

## Shared schema-driven property editor used by every authored-content editor.
## Feature modes provide EntityPropertyDef values and receive user intent back;
## this widget owns only consistent controls, section layout and reset affordances.

signal property_committed(property_name: StringName, value: Variant)
signal property_reset_requested(property_name: StringName)

var _collapsed_sections: Dictionary[StringName, bool] = {}


func set_fields(properties: Array[EntityPropertyDef], values: Dictionary, show_sections := true, editable := true) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if properties.is_empty():
		return
	var sections: Dictionary = {}
	for property: EntityPropertyDef in properties:
		if not property.is_visible_for(values):
			continue
		if not sections.has(property.section):
			sections[property.section] = []
		sections[property.section].append(property)
	for section: StringName in EntityPropertyDef.SECTIONS:
		if not sections.has(section):
			continue
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 4)
		if show_sections:
			var heading := Button.new()
			heading.flat = true
			heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
			heading.add_theme_font_size_override("font_size", 12)
			add_child(heading)
			add_child(body)
			var collapsed: bool = bool(_collapsed_sections.get(section, false))
			body.visible = not collapsed
			_set_heading_text(heading, section, collapsed)
			heading.pressed.connect(_toggle_section.bind(section, heading, body))
		else:
			add_child(body)
		var section_properties: Array = sections[section] as Array
		for property: EntityPropertyDef in section_properties:
			body.add_child(_build_property_row(property, values.get(property.name, property.default), editable))


func _toggle_section(section: StringName, heading: Button, body: VBoxContainer) -> void:
	var collapsed: bool = not bool(_collapsed_sections.get(section, false))
	_collapsed_sections[section] = collapsed
	body.visible = not collapsed
	_set_heading_text(heading, section, collapsed)


func _set_heading_text(heading: Button, section: StringName, collapsed: bool) -> void:
	heading.text = ("▶ " if collapsed else "▼ ") + section_name(section)


func _build_property_row(property: EntityPropertyDef, value: Variant, editable: bool) -> Control:
	var row := VBoxContainer.new()
	var heading := HBoxContainer.new()
	var label := Label.new()
	label.text = property.label + (" · " + property.unit if not property.unit.is_empty() else "")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	if editable and property.default != null and not _values_equivalent(value, property.default):
		var reset := Button.new()
		reset.flat = true
		reset.text = "↺"
		reset.tooltip_text = "Сбросить к значению по умолчанию"
		reset.pressed.connect(func() -> void: property_reset_requested.emit(property.name))
		heading.add_child(reset)
	row.add_child(heading)
	var control := _build_control(property, value)
	_set_editable(control, editable)
	row.add_child(control)
	return row


func _values_equivalent(left: Variant, right: Variant) -> bool:
	if left is Color or right is Color:
		var left_color := left as Color if left is Color else Color.html(String(left))
		var right_color := right as Color if right is Color else Color.html(String(right))
		return left_color.is_equal_approx(right_color)
	return var_to_str(left) == var_to_str(right)


func _set_editable(control: Control, editable: bool) -> void:
	if control is BaseButton:
		(control as BaseButton).disabled = not editable
	if control is LineEdit:
		(control as LineEdit).editable = editable
	if control is TextEdit:
		(control as TextEdit).editable = editable
	if control is SpinBox:
		(control as SpinBox).editable = editable
	for child: Node in control.get_children():
		if child is Control:
			_set_editable(child as Control, editable)


func _build_control(property: EntityPropertyDef, value: Variant) -> Control:
	match property.type:
		EntityPropertyDef.TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = bool(value)
			check.toggled.connect(func(next: bool) -> void: property_committed.emit(property.name, next))
			return check
		EntityPropertyDef.TYPE_INT, EntityPropertyDef.TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.allow_greater = property.maximum == null
			spin.allow_lesser = property.minimum == null
			spin.min_value = float(property.minimum) if property.minimum != null else -1000000.0
			spin.max_value = float(property.maximum) if property.maximum != null else 1000000.0
			spin.step = float(property.step) if property.step != null else (1.0 if property.type == EntityPropertyDef.TYPE_INT else 0.1)
			spin.value = float(value) if value != null else 0.0
			var commit := func() -> void:
				property_committed.emit(property.name, int(spin.value) if property.type == EntityPropertyDef.TYPE_INT else spin.value)
			spin.get_line_edit().text_submitted.connect(func(_text: String) -> void: commit.call())
			spin.get_line_edit().focus_exited.connect(commit)
			return spin
		EntityPropertyDef.TYPE_ENUM:
			var option := OptionButton.new()
			for entry: Variant in property.options:
				option.add_item(String(entry))
				if String(entry) == String(value):
					option.select(option.item_count - 1)
			option.disabled = option.item_count == 0
			option.item_selected.connect(func(index: int) -> void: property_committed.emit(property.name, option.get_item_text(index)))
			return option
		EntityPropertyDef.TYPE_STRING, EntityPropertyDef.TYPE_TEXT:
			if property.type == EntityPropertyDef.TYPE_TEXT:
				var text_edit := TextEdit.new()
				text_edit.custom_minimum_size.y = 72.0
				text_edit.text = String(value)
				text_edit.focus_exited.connect(func() -> void: property_committed.emit(property.name, text_edit.text))
				return text_edit
			var line_edit := LineEdit.new()
			line_edit.text = String(value)
			line_edit.text_submitted.connect(func(text: String) -> void: property_committed.emit(property.name, text))
			line_edit.focus_exited.connect(func() -> void: property_committed.emit(property.name, line_edit.text))
			return line_edit
		EntityPropertyDef.TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = value if value is Color else Color.html(String(value))
			picker.custom_minimum_size.y = 28.0
			# A drag through the colour wheel is one author action and therefore one
			# history command, not hundreds of intermediate `color_changed` values.
			picker.popup_closed.connect(func() -> void: property_committed.emit(property.name, picker.color))
			return picker
		EntityPropertyDef.TYPE_VECTOR2, EntityPropertyDef.TYPE_VECTOR3:
			return _vector_control(property, value)
		EntityPropertyDef.TYPE_FLAGS:
			return _flags_control(property, value)
		_:
			if property.is_reference():
				var reference := LineEdit.new()
				reference.placeholder_text = "идентификатор"
				reference.text = String(value)
				reference.text_submitted.connect(func(text: String) -> void: property_committed.emit(property.name, text))
				reference.focus_exited.connect(func() -> void: property_committed.emit(property.name, reference.text))
				return reference
			var unsupported := Label.new()
			unsupported.text = "Тип «%s» пока не поддерживается" % property.type
			unsupported.modulate = Color(0.75, 0.65, 0.35)
			return unsupported


func _vector_control(property: EntityPropertyDef, value: Variant) -> Control:
	var row := HBoxContainer.new()
	var count := 2 if property.type == EntityPropertyDef.TYPE_VECTOR2 else 3
	var values: Array = value as Array if value is Array else ([value.x, value.y] if value is Vector2 else ([value.x, value.y, value.z] if value is Vector3 else []))
	while values.size() < count:
		values.append(0.0)
	var spins: Array[SpinBox] = []
	for index in count:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var axis := Label.new()
		axis.text = ["X", "Y", "Z"][index]
		axis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(axis)
		var spin := SpinBox.new()
		spin.step = float(property.step) if property.step is float or property.step is int else 0.1
		spin.value = float(values[index])
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(spin)
		row.add_child(column)
		spins.append(spin)
		spin.get_line_edit().focus_exited.connect(func() -> void:
			property_committed.emit(property.name, spins.map(func(item: SpinBox) -> float: return item.value)))
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
			var next: Array = []
			for child: Node in row.get_children():
				if child is CheckBox and (child as CheckBox).button_pressed:
					next.append((child as CheckBox).text)
			property_committed.emit(property.name, next))
		row.add_child(check)
	return row


static func section_name(section: StringName) -> String:
	return {
		EntityPropertyDef.SECTION_MAIN: "Основное",
		EntityPropertyDef.SECTION_TRANSFORM: "Трансформ",
		EntityPropertyDef.SECTION_APPEARANCE: "Внешний вид",
		EntityPropertyDef.SECTION_STATE: "Состояние",
		EntityPropertyDef.SECTION_GAMEPLAY: "Игровые свойства",
		EntityPropertyDef.SECTION_BEHAVIOR: "Поведение",
		EntityPropertyDef.SECTION_LINKS: "Связи",
	}.get(section, String(section))
