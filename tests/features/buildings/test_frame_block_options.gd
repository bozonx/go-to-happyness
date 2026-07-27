extends SceneTree

## Scene coverage for the column option rows and the half-column anchor rules.

const EditorScene = preload("res://game/features/buildings/presentation/editor/building_editor.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_frame_block_options.gd ---")
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame
	var frame: FrameModeController = editor.frame_mode

	frame.select_block(&"column_square")
	await process_frame
	_assert_button_labels(frame, "BrushToolbar", ["0.5 м", "0.25 м", "Центр", "К грани", "В угол"])
	_assert_button_labels(frame, "LengthToolbar", ["Полная", "1/2"])

	frame.select_block(&"column_round", &"0.5_quarter")
	await process_frame
	_assert_button_labels(frame, "LengthToolbar", ["Полная", "1/2", "1/4"])
	assert(editor.current_variant == &"0.5_quarter")

	frame.select_block(&"column_half", &"1")
	await process_frame
	_assert_button_labels(frame, "BrushToolbar", ["1 м", "0.5 м", "0.25 м"])
	assert(editor.current_anchor == BuildingBlockCatalog.ANCHOR_EDGE)

	frame.select_block(&"column_half", &"0.5")
	await process_frame
	_assert_button_labels(frame, "BrushToolbar", ["1 м", "0.5 м", "0.25 м", "К грани", "В угол"])
	assert(editor.current_anchor != BuildingBlockCatalog.ANCHOR_CENTER)

	editor.queue_free()
	print("--- test_frame_block_options.gd PASSED ---")
	quit(0)


func _assert_button_labels(frame: FrameModeController, row_name: String, expected: Array[String]) -> void:
	var inspector: Control = frame.get("_brush_inspector")
	var row_index := 1 if row_name == "LengthToolbar" else 0
	var row: Control = inspector.get_child(row_index) if inspector.get_child_count() > row_index else null
	assert(row != null, "%s exists" % row_name)
	var labels: Array[String] = []
	for child in row.get_children():
		if child is Button:
			labels.append(child.text)
	assert(labels == expected, "%s labels: %s" % [row_name, labels])
