extends SceneTree

## End-to-end test of the editor's decor mode against the real scene: mode
## switching, snapping, the click path, selection, dragging, property bindings,
## undo and save/load.
##
## It drives BuildingEditor + DecorModeController the way the UI does, which is
## what the previous unit-only coverage missed — decor mode could not place a
## single object while every catalog assertion still passed.

const EditorScene = preload("res://game/features/buildings/presentation/editor/building_editor.tscn")


func _initialize() -> void:
	# The scene tree is not up during `_init`, so defer until it is.
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_decor_mode_editor.gd ---")
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	var decor = editor.decor_mode
	assert(decor != null, "controller exists")

	# Enter decor mode the way the UI does.
	editor._select_mode(editor.EditMode.DECOR)
	assert(decor.is_active(), "decor panel visible")
	assert(not editor._metadata_panel.visible, "metadata panel yields to the inspector")
	assert(editor.get_node("%DecorToolbar").visible, "decor toolbar visible")
	assert(not editor.get_node("%FrameToolbar").visible, "frame toolbar hidden")
	print("  mode switch ok, asset=", decor.current_asset_id)

	# Snapping: 0.5 step lands on half-block centres, not on the origin.
	decor.current_snap_step = 0.5
	var snapped: Vector3 = decor.snapped_position(Vector3(3.13, 0.0, -1.4))
	assert(snapped.is_equal_approx(Vector3(3.25, 0.0, -1.25)), "snap 0.5 -> %s" % snapped)
	decor.current_snap_step = 1.0
	snapped = decor.snapped_position(Vector3(3.13, 0.0, -1.4))
	assert(snapped.is_equal_approx(Vector3(3.5, 0.0, -1.5)), "snap 1.0 -> %s" % snapped)
	print("  snapping ok")

	# Place two objects through the real click path.
	editor.cursor_valid = true
	decor.current_asset_id = &"campfire"
	decor._set_tool(decor.Tool.PLACE)
	editor.cursor_hit_pos = Vector3(2.2, 0.0, 2.2)
	decor.on_left_pressed()
	editor.cursor_hit_pos = Vector3(5.4, 0.0, 5.4)
	decor.current_asset_id = &"flag"
	decor.on_left_pressed()
	await process_frame
	assert(editor.blueprint.objects.size() == 2, "two objects placed, got %d" % editor.blueprint.objects.size())
	assert(decor._nodes.size() == 2, "two instances spawned")
	print("  placement ok, ids=", editor.blueprint.objects.map(func(r): return r.id))

	# Selection by clicking an existing object.
	decor._set_tool(decor.Tool.SELECT)
	editor.cursor_hit_pos = Vector3(2.3, 0.0, 2.3)
	decor.on_left_pressed()
	assert(decor.selected_object_id == editor.blueprint.objects[0].id, "picked the campfire")
	assert(editor.get_node("%DecorInspectorPanel").visible, "inspector shown")
	print("  selection ok ->", decor.selected_object_id)

	# Drag it.
	var before: Vector3 = editor.blueprint.objects[0].pos
	editor.cursor_hit_pos = Vector3(4.3, 0.0, 2.3)
	decor.on_drag()
	decor.on_left_released()
	assert(editor.blueprint.objects[0].pos != before, "drag moved the object")
	print("  drag ok ", before, " -> ", editor.blueprint.objects[0].pos)

	# Properties reach the instance.
	decor._set_property("is_lit", false)
	var node = decor._nodes[decor.selected_object_id]
	assert(node.get_node("Fire").visible == false, "is_lit=false hides the flame")
	decor._set_property("light_color", "44aaff")
	assert(node.get_node("Light").light_color.is_equal_approx(Color("44aaff")), "colour binding applied")
	print("  property bindings ok")

	# Duplicate, delete, undo.
	decor.duplicate_selection()
	assert(editor.blueprint.objects.size() == 3, "duplicated")
	decor.delete_selection()
	assert(editor.blueprint.objects.size() == 2, "deleted")
	decor.undo()
	assert(editor.blueprint.objects.size() == 3, "undo restored the delete")
	decor.undo()
	assert(editor.blueprint.objects.size() == 2, "undo restored the duplicate")
	print("  undo ok")

	# The whole thing must serialize.
	var json: String = editor.blueprint.to_json()
	assert(not json.is_empty(), "blueprint serializes")
	var reloaded = load("res://game/features/buildings/domain/editor/building_blueprint.gd").from_json(json)
	assert(editor.blueprint.validation_errors().is_empty(),
		"a decor-only blueprint must validate: %s" % [editor.blueprint.validation_errors()])
	assert(reloaded != null, "serialized blueprint is valid")
	assert(reloaded.objects.size() == 2, "objects survive save/load")
	assert(reloaded.objects[0].appearance["is_lit"] == false, "authored property survives")
	print("  save/load ok")

	# Leaving decor mode cleans up.
	editor._select_mode(editor.EditMode.FRAME)
	assert(not decor.is_active(), "decor deactivated")
	assert(editor._metadata_panel.visible, "metadata panel back")
	print("--- test_decor_mode_editor.gd PASSED ---")
	quit(0)
