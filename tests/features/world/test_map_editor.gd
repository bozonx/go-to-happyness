extends SceneTree

## End-to-end test of the territory editor against the real scene
## (design_docs/core/map_editor.md §15 "Тесты").
##
## Modelled on `test_decor_mode_editor.gd` for a reason that is already paid for:
## the old catalog-only coverage of decor mode passed green while the entire mode
## could not place a single object. Unit tests over the brush and the format prove
## the parts; only running the actual scene proves the editor.
##
## What it drives is the path the UI drives: switch mode, pick from the palette,
## press the mouse button, press undo, save, reopen.

const EditorScene = preload("res://game/features/world/presentation/editor/map_editor.tscn")

const TEST_PACKAGE := "user://test_maps/editor_round_trip.gdmap"


func _initialize() -> void:
	# The scene tree is not up during `_init`, so defer until it is.
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_map_editor.gd ---")
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	_test_scene_came_up(editor)
	_test_mode_switching(editor)
	await _test_terrain_editing_and_shared_undo(editor)
	_test_surface_painting_moves_no_geometry(editor)
	_test_save_and_reopen(editor)

	editor.queue_free()
	print("--- test_map_editor.gd PASSED ---")
	quit(0)


func _test_scene_came_up(editor: Node) -> void:
	assert(editor.document != null, "editor opened a document")
	assert(editor.document.terrain.board_cells == MapMeta.DEFAULT_BOARD_CELLS, "board is the default preset")
	assert(editor.terrain_world != null and editor.camera != null, "world and camera wired")
	# The camera frames the whole board rather than a fixed distance: a 512 m map
	# must not open with the author inside a hill.
	assert(editor.camera.distance > editor.document.meta.board_metres() * 0.5, "camera framed the board")
	print("  scene up: board %d, camera at %.1f" % [editor.document.board_cells(), editor.camera.distance])


## The mode strip is data. Two modes work, the rest are visibly present and
## disabled, which is what tells the author the editor is unfinished rather than
## broken.
func _test_mode_switching(editor: Node) -> void:
	assert(editor._modes.size() == 2, "phase 1 ships relief and surface")
	assert(editor._active.id == &"terrain", "opens on relief")

	editor._select_mode(&"surface")
	assert(editor._active.id == &"surface", "switched to surface")
	assert(not editor._active.palette_entries().is_empty(), "surface palette is the material catalog")
	assert(editor._active.palette_entries().size() == TerrainMaterialCatalog.count(), "every catalog material, and only those")

	editor._select_mode(&"water")
	assert(editor._active.id == &"surface", "an unbuilt mode cannot be entered")

	editor._select_mode(&"terrain")
	assert(editor._active.id == &"terrain", "switched back")
	print("  modes ok")


func _test_terrain_editing_and_shared_undo(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	var cell := Vector2i(0, 0)
	editor._brush.hovered_cell = cell
	editor._brush.has_hover = true

	# The click path of relief mode, exactly as the mouse drives it.
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(terrain.height_of(cell) == 1, "left button raised the column, got %d" % terrain.height_of(cell))
	assert(editor.history.undo_depth() == 1, "the edit landed on the editor's stack")
	assert(editor.document.dirty, "the document knows it changed")

	# Switch mode, then undo. This is the case the building editor gets wrong:
	# there, undo after a mode change does not undo the author's last action.
	editor._select_mode(&"surface")
	editor._undo()
	assert(terrain.height_of(cell) == 0, "undo across a mode switch reverted the ground")
	assert(editor.history.undo_depth() == 0 and editor.history.can_redo(), "stack moved to redo")

	editor._redo()
	assert(terrain.height_of(cell) == 1, "redo re-applied it")
	editor._undo()
	assert(terrain.height_of(cell) == 0, "back to flat")

	editor._select_mode(&"terrain")
	await process_frame

	# A drag commits one delta per column it crosses. The stack has to gain one
	# command per delta, not one per click — otherwise undo reaches the first
	# column of the stroke and the rest are stranded on the service's stack with
	# no way back to them.
	assert(editor.history.undo_depth() == 0, "clean stack before the drag")
	# A frame has passed, and with no real pointer over the 3D view the editor
	# cleared the hover. Put the cursor back on the board.
	editor._brush.hovered_cell = Vector2i(0, 0)
	editor._brush.has_hover = true
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	for x in range(1, 5):
		editor._brush.hovered_cell = Vector2i(x, 0)
		editor._brush.apply_height_brush(1)
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(editor.history.undo_depth() == 5, "five columns, five commands, got %d" % editor.history.undo_depth())
	for _step in 5:
		editor._undo()
	assert(editor.history.undo_depth() == 0, "the whole stroke undid")
	for x in range(0, 5):
		assert(terrain.height_of(Vector2i(x, 0)) == 0, "column %d back to flat" % x)
	print("  terrain edit + cross-mode undo + per-column drag ok")


## The claim that makes surface a separate mode rather than a terrain brush: a
## material stroke moves a navigation weight and rebuilds no geometry.
func _test_surface_painting_moves_no_geometry(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	editor._select_mode(&"surface")
	editor._brush.hovered_cell = Vector2i(3, 3)
	editor._brush.has_hover = true

	terrain.take_dirty_chunks()
	var topology_before: int = editor._nav_grid.topology_revision()

	editor._active.select_palette_entry(TerrainMaterialCatalog.MUD)
	# Palette controls are clicked after the pointer leaves the 3D viewport.  A
	# variant is therefore brush state, not an immediate repaint under hover.
	editor._brush.clear_hover()
	editor._active.activate_option(&"variant_1")
	assert(editor._brush.variant == 1, "variant picker updates brush state without hover")
	assert(terrain.variant_at(Vector2i(3, 3)) != 1, "picking a variant did not repaint")
	editor._brush.hovered_cell = Vector2i(3, 3)
	editor._brush.has_hover = true
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))

	assert(terrain.material_of(Vector2i(3, 3)) == TerrainMaterialCatalog.MUD, "painted through the palette")
	assert(terrain.variant_at(Vector2i(3, 3)) == 1, "paint applied the selected variant")
	assert(not terrain.has_dirty_chunks(), "painting queued no chunk rebuild")
	assert(editor._nav_grid.topology_revision() == topology_before, "painting did not move topology")
	assert(editor.history.undo_depth() == 1, "the paint is undoable on the same stack")

	editor._undo()
	assert(terrain.material_of(Vector2i(3, 3)) != TerrainMaterialCatalog.MUD, "undo restored the material")
	print("  surface paint ok, zero chunks queued")


## Everything the author built has to survive the round trip through the package,
## through the editor's own save path rather than a test-only one.
func _test_save_and_reopen(editor: Node) -> void:
	MapDocumentService._remove_directory("user://test_maps")
	DirAccess.make_dir_recursive_absolute("user://test_maps")

	editor._select_mode(&"terrain")
	editor._brush.hovered_cell = Vector2i(5, -5)
	editor._brush.has_hover = true
	editor._brush.adjust_brush_size(1)
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	editor.document.meta.name = "Сохранённая"

	var service := MapDocumentService.new()
	var path := service.save_map_to(editor.document, TEST_PACKAGE)
	assert(not path.is_empty(), "saved: %s" % service.last_error)
	assert(not editor.document.dirty, "saving cleared the dirty flag")

	var reopened := service.load_package(TEST_PACKAGE)
	assert(reopened != null, "reopened")
	assert(reopened.meta.name == "Сохранённая", "name survived")
	assert(reopened.meta.board_cells == editor.document.meta.board_cells, "board survived")
	assert(MapTerrainCodec.encode(reopened.terrain) == MapTerrainCodec.encode(editor.document.terrain), "ground survived byte for byte")

	MapDocumentService._remove_directory("user://test_maps")
	print("  save + reopen ok")


func _click(button: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
