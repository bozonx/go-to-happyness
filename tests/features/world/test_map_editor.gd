extends SceneTree

## End-to-end test of the territory editor against the real scene
## (design_docs/engine/map_editor.md §15 "Тесты").
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
	await _test_water_mode(editor)
	_test_ocean_boundary_floods_only_from_the_edge(editor)
	_test_save_and_reopen(editor)
	_test_new_map_is_unnamed_until_asked()
	_test_save_writes_back_to_the_same_file(editor)
	_test_read_only_source_detaches(editor)

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


## The mode strip is data. Three modes work, the rest are visibly present and
## disabled, which is what tells the author the editor is unfinished rather than
## broken.
func _test_mode_switching(editor: Node) -> void:
	assert(editor._modes.size() == 3, "relief, surface and water")
	assert(editor._active.id == &"terrain", "opens on relief")

	editor._select_mode(&"surface")
	assert(editor._active.id == &"surface", "switched to surface")
	assert(not editor._active.palette_entries().is_empty(), "surface palette is the material catalog")
	assert(editor._active.palette_entries().size() == TerrainMaterialCatalog.count(), "every catalog material, and only those")

	editor._select_mode(&"water")
	assert(editor._active.id == &"water", "switched to water")
	# With no body authored yet the palette is exactly the five ways to make one:
	# the type belongs to the body, so creating and choosing are one gesture.
	assert(editor._active.palette_entries().size() == WaterBody.TYPE_IDS.size(), "palette is the five body types")

	editor._select_mode(&"roads")
	assert(editor._active.id == &"water", "an unbuilt mode cannot be entered")

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


## Water mode end to end: make a body from the palette, dig a hollow, fill it,
## and check that the layer, the undo stack and the navigation field all moved
## together. The last of those is the one that matters — a lake the routing does
## not know about is a lake citizens walk across.
func _test_water_mode(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	var water: WaterGrid = editor.document.water
	var cell := Vector2i(-6, 6)

	# A hollow two steps deep, cut with the relief tool the same way an author
	# would, so the water has somewhere to stand.
	editor._select_mode(&"terrain")
	editor._brush.hovered_cell = cell
	editor._brush.has_hover = true
	editor._brush.adjust_brush_size(-1)
	editor._brush.apply_height_brush(-1)
	editor._brush.apply_height_brush(-1)
	assert(terrain.height_of(cell) == -2, "dug a hollow, got %d" % terrain.height_of(cell))

	editor._select_mode(&"water")
	await process_frame
	editor._active.select_palette_entry(&"new_lake")
	assert(water.body_count() == 1, "the palette made a body")
	var body_id: int = editor._water_brush.body_id
	assert(body_id != WaterBody.NO_BODY, "and selected it")

	var undo_before: int = editor.history.undo_depth()
	var topology_before: int = editor._nav_grid.topology_revision()
	editor._water_brush.hovered_cell = cell
	editor._water_brush.has_hover = true
	editor._water_brush.level = 0
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))

	assert(water.is_wet(terrain, cell), "the stroke filled the hollow")
	assert(water.depth_steps_at(terrain, cell) == 2, "two steps deep")
	assert(editor.history.undo_depth() == undo_before + 1, "the stroke is on the SHARED stack")
	assert(editor._nav_grid.topology_revision() != topology_before, "routing heard about it")
	assert(not editor._nav_grid.is_walkable(cell), "and refuses to walk through it")

	# The neighbouring cells were dug by the same brush one step down, so the same
	# level leaves them as a ford: crossable, three times the price.
	editor._undo()
	assert(not water.is_wet(terrain, cell), "undo drained it")
	assert(editor._nav_grid.is_walkable(cell), "and gave routing the ground back")
	editor._redo()
	assert(water.is_wet(terrain, cell), "redo filled it again")

	# The inverse of Flood is intentionally whole-body drainage, never a patch
	# erase. It is one shared-history command and returns navigation immediately.
	editor._active.handle_input(_click(MOUSE_BUTTON_RIGHT, true))
	assert(not water.has_body(body_id), "reverse flood removed the whole body")
	assert(editor._nav_grid.is_walkable(cell), "draining republished navigation")
	editor._undo()
	assert(water.has_body(body_id) and water.is_wet(terrain, cell), "undo restored the flooded body")
	print("  water fill + shared undo + republished navigation ok")


func _test_ocean_boundary_floods_only_from_the_edge(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	var water: WaterGrid = editor.document.water
	var edge := terrain.min_cell()
	var inland := Vector2i(20, 20)
	# Nothing outside leaves even an exposed low edge dry.
	editor._on_map_menu_item_pressed(editor.MENU_BORDER_NOTHING)
	editor._terrain_service.apply_operation(TerrainEditOperation.offset([edge, inland], -1))
	assert(not water.is_wet(terrain, edge), "an empty border does not flood")
	assert(not water.is_wet(terrain, inland), "an inland hollow stays dry")
	# Switching to ocean fills the edge-connected lowland, but never the separate
	# depression: an author remains responsible for filling that one in Water.
	editor._on_map_menu_item_pressed(editor.MENU_BORDER_OCEAN)
	assert(water.is_wet(terrain, edge), "ocean reached the exposed edge")
	assert(not water.is_wet(terrain, inland), "ocean did not fill a closed inland hollow")
	assert(editor.document.meta.border_kind == MapMeta.BORDER_OCEAN)

	# From here on the rule holds per stroke, and the fill it causes is part of that
	# stroke: one Ctrl+Z gives back both the trench and the dry ground in it.
	var trench := Vector2i(edge.x, edge.y + 2)
	var depth_before: int = editor.history.undo_depth()
	editor._terrain_service.apply_operation(TerrainEditOperation.offset([trench], -1))
	assert(water.is_wet(terrain, trench), "digging at the rim let the sea in")
	assert(editor.history.undo_depth() == depth_before + 1, "one action, one undo entry")
	assert(editor._undo_button.disabled == false)
	editor._undo()
	assert(not water.is_wet(terrain, trench), "undo took the water back out")
	assert(terrain.height_of(trench) == 0, "...and the ground with it")
	print("  ocean border fill ok")


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
	# ...and so did the water: the cells in `water.bin` and the registry in
	# `map.json`, which are useless without each other.
	assert(reopened.water.body_count() == editor.document.water.body_count(), "the registry survived")
	assert(MapWaterCodec.encode(reopened.water) == MapWaterCodec.encode(editor.document.water), "water survived byte for byte")

	MapDocumentService._remove_directory("user://test_maps")
	print("  save + reopen ok")


## A blank map has no id, and that is the point: `new_map` as a default meant the
## second map an author created silently overwrote the first. Naming happens in the
## creation dialog, which is also where the board size is chosen — the one moment
## it can still be chosen at all (§6.2).
func _test_new_map_is_unnamed_until_asked() -> void:
	var blank := MapDocument.create(&"", "Новая карта", MapMeta.DEFAULT_BOARD_CELLS)
	var service := MapDocumentService.new(false)
	assert(service.save_map(blank).is_empty(), "an unnamed map cannot be saved by id")
	assert(service.last_error.contains("id"), "and the reason names the id: %s" % service.last_error)

	# The dialog is what turns intent into a document, so drive its signal rather
	# than its widgets: the editor must react to the same thing the UI emits.
	var named := MapDocument.create(&"my_map", "Моя карта", MapMeta.PRESET_ARENA)
	assert(named.meta.board_cells == MapMeta.PRESET_ARENA, "the chosen preset reached the board")
	assert(named.terrain.board_cells == MapMeta.PRESET_ARENA, "and the terrain grid with it")
	print("  new map naming ok")


## Ctrl+S goes back into the file the document came from, subfolder included. The
## old behaviour rebuilt the path from the id every time, which turned a blueprint
## or map living in a subfolder into a second file with the same id.
func _test_save_writes_back_to_the_same_file(editor: Node) -> void:
	# Inside the writable source on purpose: a subfolder of the player's own maps
	# is exactly the case the old id-derived path destroyed.
	var nested_dir := MapDocumentService.PLAYER_ROOT + "/_test_nested/deep"
	var nested := nested_dir + "/keeps_place.gdmap"
	MapDocumentService._remove_directory(MapDocumentService.PLAYER_ROOT + "/_test_nested")
	DirAccess.make_dir_recursive_absolute(nested_dir)

	var service := MapDocumentService.new(false)
	var document := MapDocument.create(&"keeps_place", "На месте", MapMeta.PRESET_ARENA)
	assert(not service.save_map_to(document, nested).is_empty(), "first write: %s" % service.last_error)

	# Reopening from that path is what the editor's Open does, and it is what binds
	# `current_path`.
	var previous_document: MapDocument = editor.document
	var previous_path: String = editor.current_path
	var previous_service = editor._service
	# Run as a player: the scene opened straight from Godot defaults to dev mode,
	# which writes the shipped pack and would rightly refuse this path.
	editor._service = MapDocumentService.new(false)
	editor._on_open_requested(nested)
	assert(editor.current_path == nested, "opened document remembers its file")

	editor.document.meta.name = "Переименована"
	editor.document.mark_dirty()
	editor._save()
	assert(editor.current_path == nested, "save stayed on the same path")
	assert(not editor.document.dirty, "and cleared the dirty flag")

	var reread := service.load_package(nested)
	assert(reread != null and reread.meta.name == "Переименована", "the edit landed in the original file")
	# Nothing was minted at the source root next to it.
	assert(not DirAccess.dir_exists_absolute(MapDocumentService.PLAYER_ROOT + "/keeps_place.gdmap"),
		"a save must not also create a copy under the source root")

	editor._service = previous_service
	editor.document = previous_document
	editor.current_path = previous_path
	editor._build_services()
	MapDocumentService._remove_directory(MapDocumentService.PLAYER_ROOT + "/_test_nested")
	print("  save-to-original-path ok")


## Opening content this mode cannot write detaches the document instead of failing
## later: the player keeps the shipped map as a starting point, and the result goes
## to their own folder (content_packaging.md §6.4).
func _test_read_only_source_detaches(editor: Node) -> void:
	var shipped := MapDocumentService.package_path(MapDocumentService.SOURCE_BUILTIN, &"green_valley")
	if not FileAccess.file_exists(shipped.path_join(MapDocumentService.MAP_JSON)):
		print("  detach skipped: no shipped map to open")
		return

	var previous_document: MapDocument = editor.document
	var previous_path: String = editor.current_path
	var previous_service = editor._service
	# Force player mode regardless of how the test process was launched.
	editor._service = MapDocumentService.new(false)

	editor._on_open_requested(shipped)
	assert(editor.document != null, "the shipped map opened")
	assert(editor.current_path.is_empty(),
		"a map from a source this mode cannot write must detach, got %s" % editor.current_path)
	assert(editor._binding_line().contains(MapDocumentService.PLAYER_ROOT),
		"and the panel says where a save would go instead: %s" % editor._binding_line())

	editor._service = previous_service
	editor.document = previous_document
	editor.current_path = previous_path
	editor._build_services()
	print("  read-only detach ok")


func _click(button: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
