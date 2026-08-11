class_name EditorFillTransformInspector
extends VBoxContainer

## Shared transform UI for fill objects in both authored-content editors.

signal property_committed(property_name: StringName, value: Variant)
signal property_reset_requested(property_name: StringName)

const CELL_X := &"editor_cell_x"
const CELL_Z := &"editor_cell_z"
const HEIGHT := &"editor_elevation"
const OFFSET := &"editor_offset"
const ROTATION := &"editor_rotation"
const SCALE := &"editor_scale"

var pos_x_spin: SpinBox
var pos_z_spin: SpinBox
var height_spin: SpinBox
var off_x_spin: SpinBox
var off_y_spin: SpinBox
var off_z_spin: SpinBox
var pitch_spin: SpinBox
var yaw_spin: SpinBox
var roll_spin: SpinBox
var scale_spin: SpinBox
var _body: VBoxContainer
var _header: Button
var _reset_buttons: Array[Button] = []
var _syncing := false


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_header = Button.new()
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.text = "▼ Трансформ"
	_header.pressed.connect(_toggle)
	add_child(_header)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 5)
	add_child(_body)

	pos_x_spin = _spin(1.0, -1000000.0, 1000000.0)
	pos_z_spin = _spin(1.0, -1000000.0, 1000000.0)
	height_spin = _spin(1.0, -128.0, 128.0)
	off_x_spin = _spin(EditorFillConventions.OFFSET_STEP, -1.0, 1.0)
	off_y_spin = _spin(EditorFillConventions.OFFSET_STEP, -1.0, 1.0)
	off_z_spin = _spin(EditorFillConventions.OFFSET_STEP, -1.0, 1.0)
	pitch_spin = _spin(EditorFillConventions.ROTATION_STEP_DEG, -360.0, 360.0)
	yaw_spin = _spin(EditorFillConventions.ROTATION_STEP_DEG, -360.0, 360.0)
	roll_spin = _spin(EditorFillConventions.ROTATION_STEP_DEG, -360.0, 360.0)
	# Keep the minimum aligned to the 0.1 grid. A 0.05 minimum makes Godot
	# quantize an authored 1.0 to 1.05 when the value is displayed.
	scale_spin = _spin(EditorFillConventions.SCALE_STEP, 0.1, EditorFillConventions.SCALE_MAX)

	_body.add_child(_heading("Положение"))
	_body.add_child(_axis_row([["X", pos_x_spin], ["Z", pos_z_spin]]))
	_body.add_child(_single_row("Высота", height_spin, HEIGHT))
	_body.add_child(_heading("Смещение", OFFSET))
	_body.add_child(_axis_row([["X", off_x_spin], ["Y", off_y_spin], ["Z", off_z_spin]]))
	_body.add_child(_heading("Поворот", ROTATION))
	_body.add_child(_axis_row([["X", pitch_spin], ["Y", yaw_spin], ["Z", roll_spin]]))
	_body.add_child(_single_row("Масштаб", scale_spin, SCALE))

	pos_x_spin.value_changed.connect(func(_v: float): _emit_number(CELL_X, pos_x_spin, true))
	pos_z_spin.value_changed.connect(func(_v: float): _emit_number(CELL_Z, pos_z_spin, true))
	height_spin.value_changed.connect(func(_v: float): _emit_number(HEIGHT, height_spin, true))
	for spin: SpinBox in [off_x_spin, off_y_spin, off_z_spin]:
		spin.value_changed.connect(func(_v: float): _emit_vector(OFFSET, [off_x_spin, off_y_spin, off_z_spin]))
	for spin: SpinBox in [pitch_spin, yaw_spin, roll_spin]:
		spin.value_changed.connect(func(_v: float): _emit_vector(ROTATION, [pitch_spin, yaw_spin, roll_spin]))
	scale_spin.value_changed.connect(func(_v: float): _emit_number(SCALE, scale_spin, false))


func set_values(values: Dictionary, editable := true) -> void:
	_syncing = true
	pos_x_spin.value = float(values.get(CELL_X, 0))
	pos_z_spin.value = float(values.get(CELL_Z, 0))
	height_spin.value = float(values.get(HEIGHT, 0))
	_set_vector([off_x_spin, off_y_spin, off_z_spin], values.get(OFFSET, Vector3.ZERO))
	_set_vector([pitch_spin, yaw_spin, roll_spin], values.get(ROTATION, Vector3.ZERO))
	scale_spin.value = float(values.get(SCALE, 1.0))
	for spin: SpinBox in [pos_x_spin, pos_z_spin, height_spin, off_x_spin, off_y_spin, off_z_spin, pitch_spin, yaw_spin, roll_spin, scale_spin]:
		spin.editable = editable
	_syncing = false


func set_position_visible(visible: bool) -> void:
	# Position is the first heading plus its two following rows.
	for index in 3:
		_body.get_child(index).visible = visible


func set_reset_enabled(enabled: bool) -> void:
	for button: Button in _reset_buttons:
		button.disabled = not enabled


func _toggle() -> void:
	_body.visible = not _body.visible
	_header.text = ("▼ " if _body.visible else "▶ ") + "Трансформ"


func _spin(step: float, minimum: float, maximum: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.step = step
	spin.min_value = minimum
	spin.max_value = maximum
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SpinBox has a fairly wide intrinsic minimum. Axis triples must still fit a
	# narrow editor inspector, so rows lay them out vertically and let the field
	# consume the remaining width.
	spin.custom_minimum_size.x = 72.0
	return spin


func _heading(text: String, reset_property: StringName = &"") -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if reset_property != &"":
		var reset := Button.new()
		reset.text = "↺"
		reset.tooltip_text = "Сбросить все значения группы"
		reset.pressed.connect(func(): property_reset_requested.emit(reset_property))
		_reset_buttons.append(reset)
		row.add_child(reset)
	return row


func _axis_row(items: Array) -> Control:
	var row := GridContainer.new()
	row.columns = 2
	for item: Array in items:
		var label := Label.new()
		label.text = item[0]
		row.add_child(label)
		row.add_child(item[1])
	return row


func _single_row(label_text: String, spin: SpinBox, reset_property: StringName) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	row.add_child(spin)
	var reset := Button.new()
	reset.text = "↺"
	reset.pressed.connect(func(): property_reset_requested.emit(reset_property))
	_reset_buttons.append(reset)
	row.add_child(reset)
	return row


func _emit_number(property_name: StringName, spin: SpinBox, integer: bool) -> void:
	if not _syncing:
		property_committed.emit(property_name, int(round(spin.value)) if integer else spin.value)


func _emit_vector(property_name: StringName, spins: Array) -> void:
	if not _syncing:
		property_committed.emit(property_name, Vector3(spins[0].value, spins[1].value, spins[2].value))


func _set_vector(spins: Array, value: Variant) -> void:
	var vector := value as Vector3 if value is Vector3 else Vector3(float(value[0]), float(value[1]), float(value[2])) if value is Array and value.size() >= 3 else Vector3.ZERO
	spins[0].value = vector.x
	spins[1].value = vector.y
	spins[2].value = vector.z
