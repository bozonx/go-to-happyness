extends SceneTree

## Scene coverage for the column option rows and subgrid anchoring.

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
	_assert_button_labels(frame, "BrushToolbar", ["0.5 м", "0.25 м"])
	_assert_button_labels(frame, "LengthToolbar", ["Полная", "1/2"])

	frame.select_block(&"column_round", &"0.5_quarter")
	await process_frame
	_assert_button_labels(frame, "LengthToolbar", ["Полная", "1/2", "1/4"])
	assert(editor.current_variant == &"0.5_quarter")

	frame.select_block(&"column_half", &"1")
	await process_frame
	_assert_button_labels(frame, "BrushToolbar", ["1 м", "0.5 м", "0.25 м"])

	frame.select_block(&"column_half", &"0.5")
	await process_frame
	_assert_button_labels(frame, "BrushToolbar", ["1 м", "0.5 м", "0.25 м"])

	_test_top_face_uses_the_hit_block_cell(editor, frame)
	_test_quarter_block_stacks_in_the_same_subslot(editor, frame)
	_test_quarter_block_snaps_to_each_side(editor, frame)
	_test_upper_active_layer_is_not_stolen_by_a_lower_block(editor, frame)
	_test_drag_does_not_bridge_different_subslots(editor, frame)
	_test_subcube_stack_and_history(editor, frame)

	editor.queue_free()
	print("--- test_frame_block_options.gd PASSED ---")
	quit(0)


## A ray through a block top and the active-layer plane crosses different X/Z
## coordinates at an angled camera.  The next block must belong to the hit
## block's cell, not the ground-plane cell behind it.
func _test_top_face_uses_the_hit_block_cell(editor: BuildingEditor, frame: FrameModeController) -> void:
	editor.grid_model.clear()
	assert(editor.grid_model.place(Vector3i(3, 0, 3), &"cube", 0, &"stone", &"1"))
	frame.select_block(&"cube", &"0.25")
	var block := editor.grid_model.get_block_at(Vector3i(3, 0, 3))
	var origin := Vector3(3.5, 5.0, 8.0)
	var direction := (Vector3(3.5, 1.0, 3.5) - origin).normalized()
	var ray_hit := frame._placement_block_hit_info_on_ray(origin, direction, 0)
	assert(ray_hit.get("block", null) == block and ray_hit.get("normal", Vector3.ZERO).y > 0.5,
		"placement picker keeps the visible top face before the active layer")
	var target := frame._placement_target_from_hit(Vector3i(3, 0, 2), {
		"block": block, "normal": Vector3.UP, "hit_pos": Vector3(3.5, 1.0, 3.5)})
	assert(target["cell"] == Vector3i(3, 1, 3), "top face places in the cell directly above the hit cube")
	var offset := BuildingBlockCatalog.anchor_base_offset_3d(&"cube", &"0.25", target["anchor"])
	assert(is_zero_approx(offset.y), "the first quarter-block above a full cube starts at the new cell floor")


## A sub-block does not always create a new grid Y cell.  Its top must select
## the next valid Y slot in its own anchor cell, while preserving X/Z.
func _test_quarter_block_stacks_in_the_same_subslot(editor: BuildingEditor, frame: FrameModeController) -> void:
	editor.grid_model.clear()
	var base_anchor := BuildingBlockCatalog.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.25, -0.375))
	assert(editor.grid_model.place(Vector3i(3, 0, 3), &"cube", 0, &"stone", &"0.25", base_anchor))
	frame.select_block(&"cube", &"0.25")
	var block := editor.grid_model.get_block_at(Vector3i(3, 0, 3))
	var target := frame._placement_target_from_hit(Vector3i(3, 0, 2), {
		"block": block, "normal": Vector3.UP, "hit_pos": Vector3(3.125, 0.5, 3.125)})
	assert(target["cell"] == Vector3i(3, 0, 3), "quarter-block top keeps placement in its anchor cell")
	var offset := BuildingBlockCatalog.anchor_base_offset_3d(&"cube", &"0.25", target["anchor"])
	assert(is_equal_approx(offset.x, -0.375) and is_equal_approx(offset.z, -0.375), "quarter-block top preserves its X/Z subslot")
	assert(is_equal_approx(offset.y, 0.5), "quarter-block top selects the Y slot immediately above it")


## Side faces use the same placement rule as the top face. Internal faces stay
## in the voxel; faces on a voxel boundary correctly cross into its neighbour.
func _test_quarter_block_snaps_to_each_side(editor: BuildingEditor, frame: FrameModeController) -> void:
	editor.grid_model.clear()
	var base_anchor := BuildingBlockCatalog.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.0, -0.375))
	assert(editor.grid_model.place(Vector3i(3, 0, 3), &"cube", 0, &"stone", &"0.25", base_anchor))
	frame.select_block(&"cube", &"0.25")
	var block := editor.grid_model.get_block_at(Vector3i(3, 0, 3))
	var cases := [
		{"normal": Vector3.RIGHT, "hit": Vector3(3.25, 0.125, 3.125), "cell": Vector3i(3, 0, 3), "offset": Vector3(-0.125, 0.0, -0.375)},
		{"normal": Vector3.LEFT, "hit": Vector3(3.0, 0.125, 3.125), "cell": Vector3i(2, 0, 3), "offset": Vector3(0.375, 0.0, -0.375)},
		{"normal": Vector3.BACK, "hit": Vector3(3.125, 0.125, 3.25), "cell": Vector3i(3, 0, 3), "offset": Vector3(-0.375, 0.0, -0.125)},
		{"normal": Vector3.FORWARD, "hit": Vector3(3.125, 0.125, 3.0), "cell": Vector3i(3, 0, 2), "offset": Vector3(-0.375, 0.0, 0.375)},
	]
	for side in cases:
		var target := frame._placement_target_from_hit(Vector3i(0, 0, 0), {
			"block": block, "normal": side["normal"], "hit_pos": side["hit"]})
		assert(target["cell"] == side["cell"], "side snap chooses adjacent anchor cell for %s" % side["normal"])
		var offset := BuildingBlockCatalog.anchor_base_offset_3d(&"cube", &"0.25", target["anchor"])
		assert(offset.is_equal_approx(side["offset"]), "side snap offset for %s: %s" % [side["normal"], offset])
		assert(editor.grid_model.can_place(target["cell"], &"cube", 0, &"stone", &"0.25", target["anchor"]),
			"side ghost is valid and its click can place for %s" % side["normal"])


## Choosing a higher layer is explicit user intent.  A lower block that is
## farther down the ray must not redirect the ghost back onto its top face.
func _test_upper_active_layer_is_not_stolen_by_a_lower_block(editor: BuildingEditor, frame: FrameModeController) -> void:
	editor.grid_model.clear()
	assert(editor.grid_model.place(Vector3i(3, 0, 3), &"cube", 0, &"stone", &"1"))
	frame.select_block(&"cube", &"0.25")
	var origin := Vector3(3.5, 5.0, 8.0)
	var direction := (Vector3(3.5, 2.0, 3.5) - origin).normalized()
	var hit := frame._placement_block_hit_info_on_ray(origin, direction, 2)
	assert(hit.is_empty(), "a block behind the active-layer plane cannot replace the cursor target")


## A pointer jump to another surface/anchor during a held stroke must place only
## that resolved target, never a Bresenham bridge through unrelated cells.
func _test_drag_does_not_bridge_different_subslots(editor: BuildingEditor, frame: FrameModeController) -> void:
	editor.grid_model.clear()
	editor.blueprint.clear_blocks()
	frame.rebuild_all_block_nodes()
	frame.select_block(&"cube", &"0.25")
	editor.current_brush = FrameModeController.Brush.LINE
	var first := Vector3i(1, 0, 1)
	var second := Vector3i(4, 0, 4)
	var first_anchor := BuildingBlockCatalog.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.0, -0.375))
	var second_anchor := BuildingBlockCatalog.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(0.375, 0.0, 0.375))
	frame._apply_tool_at_cell(first, first_anchor)
	frame.last_paint_cell = first
	frame.set("_paint_anchor", first_anchor)
	frame._continue_paint_to_target(second, second_anchor)
	assert(editor.grid_model.count() == 2, "a sub-slot change adds only its resolved target, without stray bridge blocks")
	assert(editor.grid_model.blocks_anchored_at(second).size() == 1, "the resolved second sub-block is placed")


## Four quarter-cubes share an anchor cell.  Every click must create its own
## model record and visual node, and history must restore that exact stack.
func _test_subcube_stack_and_history(editor: BuildingEditor, frame: FrameModeController) -> void:
	editor.grid_model.clear()
	editor.blueprint.clear_blocks()
	editor.reset_history()
	frame.rebuild_all_block_nodes()
	frame.select_block(&"cube", &"0.25")
	var cell := Vector3i(4, 0, 4)
	var anchors: Array[int] = []
	for y in [0.0, 0.25, 0.5, 0.75]:
		anchors.append(BuildingBlockCatalog.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, y, -0.375)))
	for anchor in anchors:
		editor.current_anchor = anchor
		frame._apply_tool_at_cell(cell)

	assert(editor.grid_model.blocks_anchored_at(cell).size() == 4, "four subcubes can share one anchor cell")
	assert(editor.blueprint.blocks.size() == 4, "history snapshot receives every placed subcube")
	assert((frame.get("_block_nodes") as Dictionary).size() == 4, "each subcube has one visual node")

	for expected_count in [3, 2, 1, 0]:
		assert(editor.undo(), "undo succeeds for subcube placement")
		var restored_count := editor.grid_model.blocks_anchored_at(cell).size()
		assert(restored_count == expected_count,
			"undo restores %d subcubes (got %d)" % [expected_count, restored_count])
		assert((frame.get("_block_nodes") as Dictionary).size() == expected_count,
			"undo restores %d subcube visuals" % expected_count)

	for expected_count in [1, 2, 3, 4]:
		assert(editor.redo(), "redo succeeds for subcube placement")
		assert(editor.grid_model.blocks_anchored_at(cell).size() == expected_count,
			"redo restores %d subcubes" % expected_count)
		assert((frame.get("_block_nodes") as Dictionary).size() == expected_count,
			"redo restores %d subcube visuals" % expected_count)


func _assert_button_labels(frame: FrameModeController, row_name: String, expected: Array[String]) -> void:
	var inspector: Control = frame.get("_brush_inspector")
	var row_index := 1 if row_name == "LengthToolbar" else 0
	var row: Control = inspector.get_child(row_index) if inspector.get_child_count() > row_index else null
	assert(row != null, "%s exists" % row_name)
	var labels: Array[String] = []
	for child in row.get_children():
		if child is Button:
			labels.append(child.text)
	assert(labels == expected, "%s labels: %s (expected %s)" % [row_name, labels, expected])
