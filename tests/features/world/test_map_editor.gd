extends SceneTree

## End-to-end test of the territory editor against the real scene
## (design_docs/engine/map_editor.md §15 "Тесты").
##
## Modelled on `test_fill_mode_editor.gd` for a reason that is already paid for:
## the old catalog-only coverage of fill mode passed green while the entire mode
## could not place a single object. Unit tests over the brush and the format prove
## the parts; only running the actual scene proves the editor.
##
## What it drives is the path the UI drives: switch mode, pick from the palette,
## press the mouse button, press undo, save, reopen.

const EditorScene = preload("res://game/features/world/presentation/editor/map_editor.tscn")

const TEST_PACKAGE := "user://test_maps/editor_round_trip.gdmap"
const TEST_PROJECT_ROOT := "user://content/projects/test_author.test_maps"
const TEST_PROJECT_MAPS := TEST_PROJECT_ROOT + "/maps"
const TEST_PROJECT_SOURCE := &"pack:test_author.test_maps"


func _initialize() -> void:
	# The scene tree is not up during `_init`, so defer until it is.
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_map_editor.gd ---")
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	_test_scene_came_up(editor)
	_test_validation(editor)
	_test_mode_switching(editor)
	_test_scenario_workspace_replaces_the_map(editor)
	_test_entities_mode_renders_anchor_markers(editor)
	_test_zones_mode_authoring(editor)
	_test_zones_mode_cascade_and_rename(editor)
	_test_a_party_point_makes_the_map_launchable(editor)
	_test_start_dialog_edits_spawn_groups(editor)
	_test_test_points_aim_the_run(editor)
	await _test_terrain_editing_and_shared_undo(editor)
	_test_ramp_connection_and_shared_undo(editor)
	_test_fill_placement_and_shared_undo(editor)
	_test_building_placement_and_shared_undo(editor)
	_test_surface_painting_moves_no_geometry(editor)
	await _test_water_mode(editor)
	_test_snow_paint_respects_water_and_slope(editor)
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


## The coverage half of the same palette. Selecting a surface arms the coverage
## brush, a stroke lands in the coverage layer and not in the ground, and undo
## takes it back off — all without leaving the Surface mode.
func _test_coverage_palette(editor: Node) -> void:
	var mode: SurfaceModeController = editor._active
	mode.select_palette_entry(SurfaceModeController.ACCORDION_COVERAGE)
	var entries: Array = mode.palette_entries()
	# Three headers, the eraser, and one entry per catalog surface.
	assert(entries.size() == 3 + 1 + CoverageCatalog.indices().size(), "coverage group lists the catalog")

	var stone_entry: StringName = StringName(SurfaceModeController.COVERAGE_ENTRY_PREFIX + String(CoverageCatalog.STONE))
	mode.select_palette_entry(stone_entry)
	assert(mode.selected_palette_entry() == stone_entry, "the coverage entry is selected")
	assert(editor._coverage_brush.coverage_index == CoverageCatalog.index_of_id(CoverageCatalog.STONE))

	var material_before: int = editor.document.terrain.material_index_at(Vector2i.ZERO)
	var undo_before: int = editor.history.undo_depth()
	assert(editor._coverage_service.paint([Vector2i.ZERO] as Array[Vector2i], editor._coverage_brush.coverage_index))
	assert(editor.document.coverage.index_at(Vector2i.ZERO) != CoverageLayer.NO_COVERAGE, "the stroke landed in the coverage layer")
	assert(editor.document.terrain.material_index_at(Vector2i.ZERO) == material_before, "and not in the ground")
	assert(editor.history.undo_depth() == undo_before + 1, "one stroke, one entry on the shared stack")
	assert(editor.document.dirty)
	editor._undo()
	assert(editor.document.coverage.index_at(Vector2i.ZERO) == CoverageLayer.NO_COVERAGE, "undo removes the coverage")

	# Picking a material disarms the coverage brush, so what the next click does is
	# never a question of which panel was touched last.
	mode.select_palette_entry(TerrainMaterialCatalog.GRASS)
	assert(mode.selected_palette_entry() == TerrainMaterialCatalog.GRASS)
	print("  coverage palette ok")


func _test_validation(editor: Node) -> void:
	var result: Dictionary = editor._validate_map()
	assert((result["errors"] as Array).is_empty(), "a blank sandbox map is valid for the generic test run")
	assert(editor.document.meta.start.game_definition == &"core:world_showcase", "new maps choose the generic game definition")
	assert(not editor._validate_button.disabled and not editor._test_button.disabled, "validation and test-run are available")
	print("  validation ok")


## The mode strip is data. Coverage is deliberately not one of its entries: it is
## the second half of the surface palette, because a mode is a set of tools and
## not the name of a storage layer (map_editor.md §5.2).
func _test_mode_switching(editor: Node) -> void:
	assert(editor._modes.size() == 6, "relief, surface, water, zones, fill and scenario")
	assert(editor.PLANNED_MODES.is_empty(), "no mode is a placeholder any more")
	assert(editor._active.id == &"terrain", "opens on relief")

	var terrain_ctrl: TerrainModeController = editor._active
	var nav_props := terrain_ctrl.inspector_properties()
	assert(nav_props.size() == 1 and nav_props[0].name == TerrainModeController.INSPECTOR_NAV_OVERLAY, "relief mode exposes nav overlay inspector property")
	assert(terrain_ctrl.inspector_values()[TerrainModeController.INSPECTOR_NAV_OVERLAY] == "Нет", "starts hidden")
	assert(terrain_ctrl.apply_inspector_value(TerrainModeController.INSPECTOR_NAV_OVERLAY, "Pedestrian"), "applies pedestrian overlay")
	assert(editor.nav_overlay.visible and terrain_ctrl.inspector_values()[TerrainModeController.INSPECTOR_NAV_OVERLAY] == "Pedestrian")
	assert(terrain_ctrl.apply_inspector_value(TerrainModeController.INSPECTOR_NAV_OVERLAY, "Cart"), "applies cart overlay")
	assert(editor.nav_overlay.visible and terrain_ctrl.inspector_values()[TerrainModeController.INSPECTOR_NAV_OVERLAY] == "Cart")
	assert(terrain_ctrl.apply_inspector_value(TerrainModeController.INSPECTOR_NAV_OVERLAY, "Нет"), "hides overlay")
	assert(not editor.nav_overlay.visible)

	editor._select_mode(&"surface")
	assert(editor._active.id == &"surface", "switched to surface")
	assert(not editor._active.palette_entries().is_empty(), "surface palette is non-empty")
	var initial_entries: Array = editor._active.palette_entries()
	# Earth is open by default: catalog earth materials + 3 group headers
	# (Земля, Экзопланеты, Покрытие).
	assert(initial_entries.size() == TerrainMaterialCatalog.indices_of_origin(TerrainMaterialCatalog.ORIGIN_EARTH).size() + 3, "initial palette contains earth materials and group headers")
	# Click Earth header to collapse it
	editor._active.select_palette_entry(&"accordion_earth")
	assert(editor._active.palette_entries().size() == 3, "collapsing earth leaves only the group headers")
	# Click Exoplanets header to expand it
	editor._active.select_palette_entry(&"accordion_exoplanet")
	assert(editor._active.palette_entries().size() == _exoplanet_material_count() + 3, "expanding exoplanets shows exoplanet materials")
	# Select an exoplanet material
	editor._active.select_palette_entry(TerrainMaterialCatalog.LUNAR_REGOLITH)
	assert(editor._active.selected_palette_entry() == TerrainMaterialCatalog.LUNAR_REGOLITH, "selected lunar regolith")
	# Select an earth material - automatically switches accordion back to earth
	editor._active.select_palette_entry(TerrainMaterialCatalog.GRASS)
	assert(editor._active.selected_palette_entry() == TerrainMaterialCatalog.GRASS, "selected grass")
	assert(editor._active.palette_entries().size() == TerrainMaterialCatalog.indices_of_origin(TerrainMaterialCatalog.ORIGIN_EARTH).size() + 3, "accordion switched back to earth")
	var surface_ctrl := editor._active as SurfaceModeController
	var init_wear := surface_ctrl._wear_level
	surface_ctrl.activate_option(SurfaceModeController.OPTION_WEAR)
	assert(surface_ctrl._tool == SurfaceModeController.TOOL_WEAR, "wear option activated wear tool")
	assert(surface_ctrl._wear_level == (init_wear + 1) % (TerrainDetailCodec.MAX_WEAR + 1), "wear option stepped level on first click")
	var init_snow := surface_ctrl._snow_level
	surface_ctrl.activate_option(SurfaceModeController.OPTION_SNOW)
	assert(surface_ctrl._tool == SurfaceModeController.TOOL_SNOW, "snow option activated snow tool")
	assert(surface_ctrl._snow_level == (init_snow + 1) % (TerrainDetailCodec.MAX_SNOW_DEPTH + 1), "snow option stepped level on first click")
	surface_ctrl.select_palette_entry(TerrainMaterialCatalog.DIRT)
	assert(surface_ctrl._tool == SurfaceModeController.TOOL_MATERIAL, "selecting material resets tool to material painting")
	_test_coverage_palette(editor)

	editor._select_mode(&"water")
	assert(editor._active.id == &"water", "switched to water")
	assert(editor._active.palette_entries().is_empty(), "water palette entries are empty (moved to tool options)")
	assert(editor._active.selected_palette_entry() == &"liquid_water", "water is selected by default")
	editor._active.select_palette_entry(&"liquid_lava")
	assert(editor._active.selected_palette_entry() == &"liquid_lava", "lava is selected directly")
	editor._active.select_palette_entry(&"liquid_water")

	editor._select_mode(&"zones")
	assert(editor._active.id == &"zones", "switched to zones")
	assert(editor._active.palette_entries().size() == 4, "area, point, route and select tools")

	editor._select_mode(&"fill")
	assert(editor._active.id == &"fill", "switched to fill")
	assert(not editor._active.palette_entries().is_empty(), "fill palette lists map archetypes")

	editor._select_mode(&"roads")
	assert(editor._active.id == &"fill", "an unbuilt mode cannot be entered")
	editor._select_mode(&"terrain")

	editor._select_mode(&"terrain")
	assert(editor._active.id == &"terrain", "switched back")
	print("  modes ok")


func _test_scenario_workspace_replaces_the_map(editor: Node) -> void:
	editor._select_mode(&"scenario")
	assert(editor._scenario_workspace.visible, "scenario opens its central workspace")
	assert(not editor._viewport_area.visible, "the inactive 3D map does not waste the centre")
	assert(not editor._scenario_map_bar.visible, "map preview bar is hidden in the workspace")
	assert(not editor._side_panel._has_list, "the scenario list is not duplicated on the right")

	var mode := editor._active as ScenarioModeController
	mode.select_palette_entry(&"flags")
	mode.activate_option(&"add_flag_bool")
	editor._refresh_panels()
	assert(editor._scenario_workspace._entries.size() == 1, "the central list reads the mode list API")
	# Leave the shared stack exactly as this UI-only check found it; the editing
	# tests below intentionally start from depth zero.
	editor.history.undo()
	editor._refresh_panels()

	editor._show_scenario_map()
	assert(not editor._scenario_workspace.visible and editor._viewport_area.visible,
		"map preview temporarily replaces the scenario workspace")
	assert(editor._scenario_map_bar.visible, "map preview always offers an explicit return")
	editor._show_scenario_workspace()
	assert(editor._scenario_workspace.visible and not editor._viewport_area.visible,
		"return restores the scenario workspace")

	editor._select_mode(&"terrain")
	assert(editor._viewport_area.visible and not editor._scenario_workspace.visible,
		"spatial modes restore the regular map")
	print("  scenario workspace ok")


## Spawn anchors render as 3D markers in the zones mode, so an author can tell the
## leader's place from a party slot at a glance instead of reading the list.
## This is the presentation counterpart of `MapSpawnService`'s data contract.
func _test_entities_mode_renders_anchor_markers(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	var zones: MapZoneLayer = editor.document.zones
	# Snapshot anchors so the test leaves the document the way it found it — later
	# tests assert on terrain/fill state and must not see these samples.
	var prior_count := zones.anchors.size()
	var hero := ZoneAnchorRecord.new()
	hero.id = &"party_leader"
	hero.role = ZoneAnchorRecord.ROLE_SPAWN
	hero.function = MapSpawnService.PARTY_LEADER
	hero.pos = Vector3(2.5, 0.0, 3.5)
	zones.anchors.append(hero)
	var companion := ZoneAnchorRecord.new()
	companion.id = &"party_slot_1"
	companion.role = ZoneAnchorRecord.ROLE_SPAWN
	companion.function = MapSpawnService.PARTY_SLOT
	companion.pos = Vector3(3.5, 0.0, 3.5)
	zones.anchors.append(companion)

	editor._select_mode(&"zones")
	var controller: MapZonesModeController = editor._active
	# The visual root holds one MeshInstance3D per anchor; the Label3D is a child
	# of that mesh, so the root's direct children equal the authored anchor count.
	var marker_root: Node3D = controller._root
	assert(marker_root != null, "zones mode owns a marker root")
	assert(marker_root.get_child_count() == 2, "each anchor renders a marker: %d" % marker_root.get_child_count())
	for marker in marker_root.get_children():
		assert(marker is MeshInstance3D, "anchor marker is a mesh")
		# The marker lifts onto the live terrain, like the runtime spawn does.
		var expected_height := terrain.height_at(Vector3(marker.position.x, 0.0, marker.position.z))
		assert(marker.position.y > expected_height, "marker sits above the ground, not inside it")
		# Each marker carries a Label3D so its role reads from any angle.
		var has_label := false
		for child in marker.get_children():
			if child is Label3D:
				has_label = true
				break
		assert(has_label, "anchor marker has a readable label")
	# Restore the document so subsequent tests see a clean board.
	zones.anchors.resize(prior_count)
	editor._select_mode(&"terrain")
	print("  anchor markers ok")


## The zones mode driven the way the mouse drives it. Markers alone used to be
## the whole coverage here, and under them the mode could not author an area the
## author had actually dragged: a drag up or left collapsed to a single cell, and
## nothing on the map drew the area at all.
func _test_zones_mode_authoring(editor: Node) -> void:
	editor._select_mode(&"zones")
	var mode: MapZonesModeController = editor._active
	var zones: MapZoneLayer = editor.document.zones
	var prior_areas := zones.areas.size()
	var depth: int = editor.history.undo_depth()

	# A drag from (2,2) *back* to (-1,-1): the direction of a drag must not change
	# the rectangle, and negative cells are ordinary board cells.
	mode.select_palette_entry(&"area")
	editor._brush.has_hover = true
	editor._brush.hovered_cell = Vector2i(2, 2)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._brush.hovered_cell = Vector2i(-1, -1)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(zones.areas.size() == prior_areas + 1, "the drag created one area")
	var area: ZoneAreaRecord = zones.areas[zones.areas.size() - 1]
	assert(area.rects.size() == 1 and area.rects[0] == Rect2i(-1, -1, 4, 4),
		"a reversed drag yields the rectangle the author dragged, got %s" % area.rects)
	assert(area.contains_cell(Vector2i(-1, -1)) and area.contains_cell(Vector2i(2, 2)),
		"both ends of the drag are inside the area")

	# It is visible: an area nobody can see is an area nobody can place.
	assert(mode._root.get_child_count() > 0, "the area draws in the 3D view")

	# The typed inspector edits the record — role and, for an overlay, the effects
	# that carry the landscape on a map (§18). Every commit rebuilds the layer from
	# its snapshot, so records are re-read by id rather than held across edits —
	# the same discipline the controller itself keeps.
	var area_id := area.id
	assert(mode._selected_area() != null, "the new area is selected")
	assert(mode.apply_inspector_value(MapZonesModeController.P_ROLE, "Оверлей"), "role is editable")
	assert(mode.apply_inspector_value(MapZonesModeController.P_COST, 2.5), "cost is editable")
	assert(is_equal_approx(float(zones.area_by_id(area_id).effects[ZoneEffects.KEY_COST]), 2.5),
		"the effect landed on the record")
	assert(mode.apply_inspector_value(MapZonesModeController.P_DENY, ["builder"]), "rights are editable")
	var denied: Array[StringName] = zones.area_by_id(area_id).deny
	assert(denied.size() == 1 and denied[0] == &"builder", "the denial landed on the record")

	# An overlay in negative cells has to reach the runtime; that was the bug that
	# made three quarters of every map's zones inert.
	var overlay_index := ZoneOverlayIndex.new()
	overlay_index.rebuild(zones, editor.document.board_cells())
	assert(is_equal_approx(overlay_index.cost_at(Vector2i(-1, -1)), 2.5),
		"an overlay drawn west of the origin still costs what it says")

	# Everything above is one undo stack with the rest of the editor.
	while editor.history.undo_depth() > depth:
		editor._undo()
	assert(zones.areas.size() == prior_areas, "undo removed the authored area")
	editor._select_mode(&"terrain")
	print("  zones authoring ok")


## Deleting an area takes what it owns with it (§7.7), and renaming one follows
## every reference — a rule pointing at the old id is a rule that silently never
## fires again.
func _test_zones_mode_cascade_and_rename(editor: Node) -> void:
	editor._select_mode(&"zones")
	var mode: MapZonesModeController = editor._active
	var zones: MapZoneLayer = editor.document.zones
	var prior_areas := zones.areas.size()
	var prior_anchors := zones.anchors.size()
	var depth: int = editor.history.undo_depth()

	mode.select_palette_entry(&"area")
	editor._brush.has_hover = true
	editor._brush.hovered_cell = Vector2i(5, 5)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._brush.hovered_cell = Vector2i(7, 7)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	var area_id: StringName = zones.areas[zones.areas.size() - 1].id

	# A point placed inside the region is adopted by it.
	mode.select_palette_entry(&"point")
	mode.activate_option(&"anchor_waypoint")
	editor._brush.hovered_cell = Vector2i(6, 6)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	var anchor_id: StringName = zones.anchors[zones.anchors.size() - 1].id
	var anchor := zones.anchor_by_id(anchor_id)
	assert(anchor.owner_id == area_id, "the point under a region is owned by it")
	# Cells, not metres: `pos.y` is the level the author placed it on (§6).
	assert(is_equal_approx(anchor.pos.x, 6.5) and is_equal_approx(anchor.pos.z, 6.5),
		"the point sits at the centre of its cell, in board coordinates")
	assert(is_equal_approx(anchor.pos.y, float(editor.document.terrain.height_of(Vector2i(6, 6)))),
		"the point carries a terrain level, not a height in metres")

	# A rule addressing the region follows the rename.
	var rule := MapRule.new()
	rule.id = &"zone_rule"
	rule.trigger.kind = MapRuleTrigger.AREA_ENTERED
	rule.trigger.zone = area_id
	editor.document.scenario.rules.append(rule)
	mode._select_area(area_id)
	assert(mode.apply_inspector_value(MapZonesModeController.P_ID, "gate_yard"), "the area was renamed")
	assert(zones.area_by_id(&"gate_yard") != null, "the record carries the new id")
	assert(zones.anchor_by_id(anchor_id).owner_id == &"gate_yard", "the point it owns followed the rename")
	assert(rule.trigger.zone == &"gate_yard", "the rule addressing it followed the rename")

	# Deleting the area cascades to the point it owned.
	mode._select_area(&"gate_yard")
	assert(mode._delete_selection(), "the selected area was deleted")
	assert(zones.area_by_id(&"gate_yard") == null, "the area is gone")
	assert(zones.anchor_by_id(anchor_id) == null, "the point it owned went with it, not orphaned")

	editor.document.scenario.rules.clear()
	while editor.history.undo_depth() > depth:
		editor._undo()
	assert(zones.areas.size() == prior_areas and zones.anchors.size() == prior_anchors,
		"undo walked the whole gesture back")
	editor._select_mode(&"terrain")
	print("  zones cascade and rename ok")


## The gesture the whole editor exists to make possible: put the party's start
## point down, and the map launches.
##
## It used not to. A spawn group and an entrance were what the launch looks up,
## and neither was authorable anywhere — `MapSpawnGroup` had one caller, the
## v7→v8 migration. So the author placed the point, the editor accepted it, and
## `F5` answered "вариант старта не называет группу появления": a record they
## could not create, about a map that looked finished.
func _test_a_party_point_makes_the_map_launchable(editor: Node) -> void:
	editor._select_mode(&"zones")
	var mode: MapZonesModeController = editor._active
	var document: MapDocument = editor.document
	var depth: int = editor.history.undo_depth()
	assert(document.zones.spawn_groups.is_empty(), "a fresh map has no spawn group")
	assert(document.meta.start.starts.is_empty(), "a fresh map has no entrance")

	mode.select_palette_entry(&"point")
	mode.activate_option(&"anchor_spawn")
	mode.activate_option(StringName("function_%s" % MapSpawnService.PARTY_LEADER))
	editor._brush.has_hover = true
	editor._brush.hovered_cell = Vector2i(3, -4)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, true))

	assert(document.zones.spawn_groups.size() == 1, "the party point built a spawn group")
	var group: MapSpawnGroup = document.zones.spawn_groups[0]
	assert(group.slot_with_tag(MapSpawnGroup.TAG_LEADER) != null, "the point is the leader's place")
	assert(document.meta.start.starts.size() == 1, "and the entrance that names it")
	assert(document.meta.start.starts[0].spawn_group == group.id, "the entrance points at the group")

	# The gate that used to refuse: a settlement launch asking for four settlers.
	var capacity_errors := MapValidator.validate_party_capacity(document, &"", 4)
	assert(capacity_errors.is_empty(), "the map seats a party of four: %s" % "; ".join(capacity_errors))
	# And the rules the save path runs agree, so the map that launches also saves.
	var errors := document.zones.validate(document.board_cells())
	errors.append_array(MapValidator.validate(document, document.terrain, document.water, null))
	assert(errors.is_empty(), "the built structure validates: %s" % "; ".join(errors))

	# A second party point is a second place in the same group, not a second group.
	mode.activate_option(StringName("function_%s" % MapSpawnService.PARTY_SLOT))
	editor._brush.hovered_cell = Vector2i(4, -4)
	mode.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	assert(document.zones.spawn_groups.size() == 1, "the second point joined the group")
	assert(document.zones.spawn_groups[0].slots.size() == 2, "as a second place in it")

	# One click, one undo — the group and the entrance come back together, because
	# the half-state between them is a map the validator refuses.
	editor._undo()
	assert(document.zones.spawn_groups[0].slots.size() == 1, "undo took the second place back")
	while editor.history.undo_depth() > depth:
		editor._undo()
	assert(document.zones.spawn_groups.is_empty(), "undo removed the group")
	assert(document.meta.start.starts.is_empty(), "and the entrance with it, in the same step")
	editor._select_mode(&"terrain")
	print("  party start authoring ok")


## The explicit half: the start dialog can build and edit a group by hand, for the
## map whose author wants two entrances rather than the one the point implied.
## Driven through the real dialog scene because the whole failure mode here is a
## control that exists in the script and not in the `.tscn`.
func _test_start_dialog_edits_spawn_groups(editor: Node) -> void:
	var document: MapDocument = editor.document
	var depth: int = editor.history.undo_depth()
	editor._open_start_settings()
	var dialogs: MapEditorDialogs = editor._dialogs

	dialogs._add_group()
	var group: MapSpawnGroup = dialogs._selected_group_record()
	assert(group != null, "a group was added to the working copy")
	assert(document.zones.spawn_groups.is_empty(), "and not to the document until confirmed")
	dialogs._group_name_edit.text = "Северный лагерь"
	dialogs._group_id_edit.text = "north_camp"
	MapEditorDialogs._select_metadata(dialogs._group_fallback_option, MapSpawnGroup.FALLBACK_FAIL)
	dialogs._commit_group_fields()

	# An entrance added now can name it — the dropdown reads the working copies,
	# not the document, which is the difference between authoring both in one
	# sitting and having to reopen the dialog.
	dialogs._add_start_option()
	dialogs._refresh_start_option_fields()
	assert(dialogs._selected_start_option().spawn_group == &"north_camp",
		"the only group there is becomes the new entrance's group")

	dialogs._on_start_settings_confirmed()
	assert(document.zones.spawn_groups.size() == 1, "the confirmed group reached the document")
	assert(document.zones.spawn_groups[0].id == &"north_camp", "with the id the author typed")
	assert(document.zones.spawn_groups[0].fallback == MapSpawnGroup.FALLBACK_FAIL, "and its fallback")
	# The dialog is part of the one undo stack like every other gesture (§3.3).
	assert(editor.history.undo_depth() == depth + 1, "a confirmed dialog is one undo step")
	editor._undo()
	assert(document.zones.spawn_groups.is_empty(), "undo took the group back off")
	assert(document.meta.start.starts.is_empty(), "and the entrance with it")
	print("  start dialog spawn groups ok")


## Test points, and the bug they exist to end: the top bar's `▶⌖` could never
## work, because reaching the button meant leaving the map and the brush dropped
## its hover on the way. The editor remembers the last cell the cursor was over,
## so a button press acts on where the author was looking.
func _test_test_points_aim_the_run(editor: Node) -> void:
	editor._select_mode(&"terrain")
	editor._brush.has_hover = true
	editor._brush.hovered_cell = Vector2i(11, -7)
	editor._remember_hovered_cell()
	# Exactly what happens when the pointer travels to the toolbar.
	editor._brush.has_hover = false
	assert(editor._has_last_hovered_cell, "the cell survived the cursor leaving the map")

	editor._add_test_point_here()
	assert(editor.test_points.points.size() == 1, "the toolbar command placed a point")
	assert(editor.test_points.points[0].cell == Vector2i(11, -7), "on the cell the author was over")
	assert(editor.test_points.selected == 0, "and the run is aimed at it")
	assert(editor._test_point_views.get_child_count() == 1, "the marker is drawn")

	# Pressing it again on the same cell selects rather than stacks a second cone.
	editor._add_test_point_here()
	assert(editor.test_points.points.size() == 1, "a second press on the same cell adds nothing")

	# `F5` now runs from the point, and the position is read off the live terrain —
	# an author digs under their own test point constantly.
	var expected := MapSpawnService.cell_to_world(
		Vector2i(11, -7), float(editor.document.terrain.height_of(Vector2i(11, -7))),
		editor.document.meta.cell_size)
	assert(editor._world_position_of_cell(Vector2i(11, -7)) == expected, "the run starts on the ground")

	# The menu shows what F5 will do; the map's own entrance is always the first row.
	editor._refresh_run_menu()
	var popup: PopupMenu = editor._test_target_button.get_popup()
	# Menu ids are deliberately positive: `PopupMenu` reads a negative id as
	# "assign one for me", which turned the entrance row into item 0 and made the
	# menu answer with an index into the list of points.
	assert(popup.get_item_id(0) == editor.MENU_MAP_START, "the entrance is offered too")
	assert(popup.is_item_checked(1), "the point is the checked target")

	editor._select_test_target(editor.RUN_TARGET_MAP_START)
	assert(editor.test_points.selected == -1, "aiming back at the map's entrance")
	# `Alt+5` on a map with one point means nothing rather than "the last one".
	editor._select_test_target(4)
	assert(editor.test_points.selected == -1, "a shortcut past the end of the list does nothing")

	editor._select_test_target(0)
	editor._remove_selected_test_point()
	assert(editor.test_points.points.is_empty(), "the point was removed")
	assert(editor._test_point_views.get_child_count() == 0, "and its marker with it")
	print("  test points ok")


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


## The real palette and mouse path must create a ramp, not merely expose the
## catalog. This is the regression the unit-level grid tests cannot catch.
func _test_ramp_connection_and_shared_undo(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	editor._select_mode(&"terrain")
	assert(editor.history.undo_depth() == 0)
	terrain.set_height(Vector2i(2, 0), 3)
	terrain.set_height(Vector2i(4, 0), 1)
	editor._active.select_palette_entry(&"ramp")
	editor._brush.hovered_cell = Vector2i(0, 0)
	editor._brush.has_hover = true
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._brush.hovered_cell = Vector2i(4, 0)
	editor._active._update_ramp_preview()
	assert(editor.ramp_preview.visible, "drag shows a ramp preview")
	assert(editor.ramp_preview.mesh.get_aabb().size.y > 0.4, "preview is an inclined surface, not flat squares")
	assert(editor._message.contains("будет изменено клеток: 1"), "preview explains the pending reshape")
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(terrain.is_ramp_valid_at(Vector2i(2, 0)), "drag connected the two height anchors")
	assert(terrain.slope_class_at(Vector2i(2, 0)) == SlopeCatalog.CLASS_GENTLE, "Auto selected the 1:4 profile")
	assert(terrain.height_of(Vector2i(2, 0)) == 0, "connection reshaped uneven ground")
	assert(editor.history.undo_depth() == 1, "reshape and ramp are one editor command")
	editor._undo()
	assert(terrain.height_of(Vector2i(2, 0)) == 3, "undo restored reshaped ground")
	assert(terrain.slope_class_at(Vector2i(2, 0)) == SlopeCatalog.CLASS_FLAT, "undo removed the ramp")
	# Test setup is not an authored command; return the shared document to the flat
	# state expected by the following mode tests.
	terrain.set_height(Vector2i(2, 0), 0)
	terrain.set_height(Vector2i(4, 0), 0)
	editor._active.select_palette_entry(&"sculpt")
	print("  ramp connection + shared undo ok")


## The first Fill Mode slice must use the same real input, document and history
## path as every other editor mode. A green marker is not enough: the entity has
## to serialize through the typed layer and disappear on the shared Ctrl+Z.
func _test_fill_placement_and_shared_undo(editor: Node) -> void:
	editor._select_mode(&"fill")
	editor._active.select_palette_entry(&"core:campfire")
	editor._brush.hovered_cell = Vector2i(7, 7)
	editor._brush.has_hover = true
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	assert(editor.document.entities.entities.size() == 1, "fill placed one typed entity")
	var entity: MapEntityRecord = editor.document.entities.entities[0]
	assert(entity.archetype_id == &"core:campfire")
	assert(entity.cell(editor.document.terrain) == Vector2i(7, 7), "entity attached to hovered cell")
	assert(editor.history.undo_depth() == 1, "fill uses the shared undo stack")
	editor._undo()
	assert(editor.document.entities.entities.is_empty(), "undo removed the placed entity")
	editor._redo()
	assert(editor.document.entities.entities.size() == 1, "redo restored it")
	# Select, duplicate, rotate and delete use the same record layer and history;
	# these shortcuts keep common authoring work out of a bespoke inspector.
	# There is no tool to switch to: a click on an occupied cell selects, exactly
	# as in the building editor.
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	assert(editor._side_panel.get_node("Margin/Scroll/Rows/InspectorFields").get_child_count() > 0, "schema generated inspector controls")
	assert(editor._active.apply_inspector_value(&"editor_scale", 1.5),
		"asset metadata does not lock authoring scale")
	assert(is_equal_approx(editor.document.entities.entities[0].scale, 1.5),
		"free authoring scale reaches the map record")
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_PITCH, 30.0))
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_ROLL, 345.0))
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_ELEVATION, 2.4))
	entity = editor.document.entities.entities[0]
	assert(is_equal_approx(entity.pitch_degrees, 30.0) and is_equal_approx(entity.roll_degrees, 345.0),
		"map record authors all three rotation axes")
	assert(entity.elevation_blocks == 2, "map Y level is stored in whole blocks")
	assert(editor._active.reset_inspector_value(FillModeController.INSPECTOR_PITCH))
	assert(editor._active.reset_inspector_value(FillModeController.INSPECTOR_ROLL))
	assert(editor._active.reset_inspector_value(FillModeController.INSPECTOR_ELEVATION))
	assert(editor._active.reset_inspector_value(FillModeController.INSPECTOR_SCALE))
	assert(editor._active.apply_inspector_value(&"fuel_units", 5), "inspector applied authored property")
	assert(editor.document.entities.entities[0].props == {&"fuel_units": 5}, "only authored difference is stored")
	assert(editor._active.reset_inspector_value(&"fuel_units"), "inspector reset restores archetype default")
	assert(editor.document.entities.entities[0].props.is_empty(), "reset removes the authored override")
	editor._undo()
	assert(editor.document.entities.entities[0].props == {&"fuel_units": 5}, "reset is undoable")
	editor._undo()
	assert(editor.document.entities.entities[0].props.is_empty(), "property undo restored defaults")
	# Дублирования нет: пипетка снимает полный образец, и следующий клик ставит
	# такой же объект в свободные клетки.
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true, true))
	editor._brush.hovered_cell = Vector2i(9, 9)
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	assert(editor.document.entities.entities.size() == 2, "пипетка + клик заменяют дублирование")
	assert(editor.document.entities.entities[1].archetype_id == editor.document.entities.entities[0].archetype_id,
		"копия несёт архетип образца")
	editor._active.handle_input(_key(KEY_R))
	assert(is_equal_approx(editor.document.entities.entities[1].yaw_degrees, 15.0), "R повернул поставленную копию")
	var side_list := editor._side_panel.get_node("Margin/Scroll/Rows/List") as ItemList
	side_list.select(0, true)
	side_list.multi_selected.emit(0, true)
	assert(editor._active.selected_list_index() == 0, "side list selects the corresponding map entity")
	var side_search := editor._side_panel.get_node("Margin/Scroll/Rows/ListSearch") as LineEdit
	side_search.text = "entity_2"
	side_search.text_changed.emit(side_search.text)
	assert(side_list.item_count == 1, "side-list search filters entities")
	side_search.text = ""
	side_search.text_changed.emit("")
	editor._active.handle_input(_key(KEY_DELETE))
	assert(editor.document.entities.entities.size() == 1, "Delete removed the selection")
	editor._undo()
	editor._undo()
	editor._undo()
	assert(editor.document.entities.entities.size() == 1, "shortcut edits undo back to the original")

	# Одна раскладка с редактором зданий: Shift+ЛКМ — пипетка, Shift+ПКМ —
	# удаление под курсором, Ctrl+ЛКМ — добавить в выделение, Esc — снять его.
	var fill_ctrl: FillModeController = editor._active as FillModeController
	editor._brush.hovered_cell = editor.document.entities.entities[0].cell(editor.document.terrain)
	editor._brush.has_hover = true
	fill_ctrl._archetype_id = &""
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true, true))
	assert(fill_ctrl._archetype_id == editor.document.entities.entities[0].archetype_id, "Shift+ЛКМ берёт архетип в кисть")
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	assert(fill_ctrl._selected_id != &"", "клик по занятой клетке выделяет, а не ставит второй объект")
	editor._active.handle_input(_key(KEY_ESCAPE))
	assert(fill_ctrl._selected_id == &"", "Esc снимает выделение")
	var before_erase: int = editor.document.entities.entities.size()
	editor._active.handle_input(_click(MOUSE_BUTTON_RIGHT, true, true))
	assert(editor.document.entities.entities.size() == before_erase - 1, "Shift+ПКМ удаляет объект под курсором")
	editor._undo()
	assert(editor.document.entities.entities.size() == before_erase, "удаление отменяется общей историей")
	# Призрак живёт в том же корне, что и виды: пересборка видов не должна его
	# освобождать, иначе следующий кадр обратится к уничтоженному инстансу.
	editor._brush.hovered_cell = Vector2i(20, 20)
	fill_ctrl._archetype_id = &"core:campfire"
	fill_ctrl._refresh_ghost()
	fill_ctrl.rebuild_views()
	fill_ctrl._refresh_ghost()
	assert(is_instance_valid(fill_ctrl._ghost), "призрак выжил пересборку видов")
	# Удерживание ЛКМ рисует объектами по всем пройденным клеткам; быстрый
	# motion sample не оставляет пунктир, а весь жест остаётся одним undo.
	fill_ctrl._archetype_id = &"core:campfire"
	fill_ctrl._select(&"", false)
	var stroke_count_before: int = editor.document.entities.entities.size()
	var stroke_depth_before: int = editor.history.undo_depth()
	var stroke_start := Vector2i.ZERO
	for x in range(1, editor.document.terrain.board_cells - 5):
		for z in range(1, editor.document.terrain.board_cells - 1):
			var candidate := Vector2i(x, z)
			if fill_ctrl._cells_placeable(Rect2i(candidate, Vector2i(4, 1))) and fill_ctrl._entity_at(candidate) == &"" and fill_ctrl._entity_at(candidate + Vector2i(1, 0)) == &"" \
					and fill_ctrl._entity_at(candidate + Vector2i(2, 0)) == &"" and fill_ctrl._entity_at(candidate + Vector2i(3, 0)) == &"":
				stroke_start = candidate
				break
		if stroke_start != Vector2i.ZERO:
			break
	assert(stroke_start != Vector2i.ZERO, "на карте нашлась свободная полоса для stroke")
	editor._brush.hovered_cell = stroke_start
	editor._brush.has_hover = true
	fill_ctrl.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	assert(fill_ctrl._placing_stroke, "первый клик начал stroke постановки")
	editor._brush.hovered_cell = stroke_start + Vector2i(3, 0)
	fill_ctrl.handle_input(InputEventMouseMotion.new())
	fill_ctrl.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(editor.document.entities.entities.size() == stroke_count_before + 4,
		"долгое ЛКМ заполняет каждую клетку пути")
	assert(editor.history.undo_depth() == stroke_depth_before + 1,
		"непрерывная постановка является одним действием undo")
	editor._undo()
	# Picking follows the whole authored footprint, not only its anchor cell.
	fill_ctrl._archetype_id = &"core:cooking_campfire"
	fill_ctrl._place(Vector2i(24, 24))
	var wide_id: StringName = editor.document.entities.entities[-1].id
	assert(fill_ctrl.occupied_cells(editor.document.entities.entities[-1]).position == Vector2i(24, 24),
		"even footprint keeps the clicked cell as its authored base")
	assert(fill_ctrl._entity_at(Vector2i(25, 25)) == wide_id,
		"2×2 object is selectable from every claimed cell")
	editor._undo()

	# Клетки: объект занимает целое число клеток, занятую клетку второй раз не
	# занять, а смещение подстраивает модель внутри своих клеток.
	var depth_before_cells: int = editor.history.undo_depth()
	var busy_cell: Vector2i = editor.document.entities.entities[0].cell(editor.document.terrain)
	editor._brush.hovered_cell = busy_cell
	var count_before: int = editor.document.entities.entities.size()
	fill_ctrl._place(busy_cell)
	assert(editor.document.entities.entities.size() == count_before, "занятые клетки повторно не занимаются")
	fill_ctrl._select(editor.document.entities.entities[0].id, false)
	var cells_before: Rect2i = fill_ctrl.occupied_cells(editor.document.entities.entities[0])
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_OFFSET, [0.25, 0.0, -0.5]),
		"смещение записывается через общий инспектор")
	assert(editor.document.entities.entities[0].offset.is_equal_approx(Vector3(0.25, 0.0, -0.5)),
		"смещение доехало до записи")
	assert(fill_ctrl.occupied_cells(editor.document.entities.entities[0]) == cells_before,
		"смещение не переселяет запись в соседнюю клетку")
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_OFFSET, [4.0, 0.0, 0.0]),
		"смещение больше клетки принимается, но обрезается")
	assert(editor.document.entities.entities[0].offset.x <= EditorFillConventions.MAX_OFFSET_CELLS,
		"смещение ограничено одной клеткой")
	assert(editor._active.reset_inspector_value(FillModeController.INSPECTOR_OFFSET),
		"смещение сбрасывается")
	assert(editor.document.entities.entities[0].offset.is_zero_approx(), "сброс вернул объект на свои клетки")
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_CELL_X, busy_cell.x + 2),
		"поле Клетка X независимо переносит объект")
	assert(editor.document.entities.entities[0].cell(editor.document.terrain).x == busy_cell.x + 2,
		"X не сбрасывается в ноль и не меняет Z")
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_CELL_Z, busy_cell.y + 2),
		"поле Клетка Z независимо переносит объект")
	assert(editor.document.entities.entities[0].cell(editor.document.terrain) == busy_cell + Vector2i(2, 2),
		"Z подписан и применяется как координата карты")
	# Клетка правится числом и переносит объект целиком.
	assert(editor._active.apply_inspector_value(FillModeController.INSPECTOR_CELL, [busy_cell.x + 3, busy_cell.y]),
		"клетка правится числом")
	assert(editor.document.entities.entities[0].cell(editor.document.terrain) == busy_cell + Vector2i(3, 0),
		"запись переехала в заданную клетку")
	editor._undo()
	# Замена: id сохраняется, поэтому ссылки на объект не рвутся.
	var kept_id: StringName = editor.document.entities.entities[0].id
	fill_ctrl._select(kept_id, false)
	fill_ctrl._archetype_id = &"core:campfire"
	var options: Array = editor._active.tool_options()
	assert(options.any(func(option) -> bool:
		return option.id == FillModeController.OPTION_REPLACE),
		"действие замены появляется в опциях палитры")
	# Возвращаем стек к тому, что было: дальше тест считает шаги отмены.
	while editor.history.undo_depth() > depth_before_cells:
		editor._undo()
	print("  cells + offset + replace action ok")
	# Raising its cell is one terrain action. The record keeps its authored local
	# offset; the view projects it onto the new surface rather than double-counting
	# the terrain height.
	editor._select_mode(&"terrain")
	editor._brush.hovered_cell = Vector2i(7, 7)
	editor._brush.has_hover = true
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(is_equal_approx(editor.document.entities.entities[0].position.y, 0.0), "terrain lift preserved the entity's local offset")
	var fill_mode: FillModeController = null
	for mode: MapEditorMode in editor._modes:
		if mode is FillModeController:
			fill_mode = mode as FillModeController
			break
	assert(fill_mode != null)
	var view := fill_mode._views.get(entity.id) as Node3D
	assert(view != null and is_equal_approx(view.position.y, 0.5), "entity view follows the raised terrain once")
	editor._undo()
	assert(is_equal_approx(editor.document.entities.entities[0].position.y, 0.0), "undo preserved the entity's local offset")
	view = fill_mode._views.get(entity.id) as Node3D
	assert(view != null and is_equal_approx(view.position.y, 0.0), "undo reprojected the entity onto the restored terrain")
	while editor.history.undo_depth() > 0:
		editor._undo()
	assert(editor.history.undo_depth() == 0, "fill left the next mode a clean stack")
	print("  fill placement + shared undo ok")


## The claim that makes surface a separate mode rather than a terrain brush: a
## material stroke moves a navigation weight and rebuilds no geometry.
## Buildings are a tool of the Fill mode, not a mode of their own
## (`building_placement.md` §8), and the whole of one placement — the pad, the
## anchors, the record — has to be ONE entry on the shared stack (§11.1). Only
## the real scene proves that: the parts travel through three services and are
## folded together by the editor.
func _test_building_placement_and_shared_undo(editor: Node) -> void:
	editor._select_mode(&"fill")
	var fill: FillModeController = editor._active as FillModeController
	var blueprint_entry: StringName = &""
	for entry in fill.palette_entries():
		if not entry.is_header:
			blueprint_entry = entry.id
			break
	assert(blueprint_entry != &"", "палитра наполнения показывает группу чертежей")
	fill.select_palette_entry(blueprint_entry)
	assert(fill.selected_palette_entry() == blueprint_entry, "чертёж стал кистью")

	var terrain: TerrainGrid = editor.document.terrain
	# Uneven ground, so the merge has something to level and the pad is provably
	# the blueprint's and not the terrain's.
	editor._terrain_service.apply_operation(TerrainEditOperation.offset(
		[Vector2i(12, 12), Vector2i(13, 12)], 2, TerrainEditOperation.Mode.TERRACE))
	var undo_before: int = editor.history.undo_depth()

	editor._brush.hovered_cell = Vector2i(13, 13)
	editor._brush.has_hover = true
	fill.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	fill.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(editor.document.placements.placements.size() == 1,
		"клик кистью чертежа поставил здание")
	var record: MapPlacementRecord = editor.document.placements.placements[0]
	var footprint := BuildingPlacementService.footprint_of(record)
	assert(footprint.contains(Vector2i(13, 13)), "здание встало под курсором")
	for cell: Vector2i in footprint.cells():
		assert(terrain.height_of(cell) == record.level_value + footprint.relative_height(cell),
			"колонка %s выровнена по площадке" % cell)
		assert(terrain.is_anchor(cell), "клетка %s закреплена якорем" % cell)
	assert(editor.history.undo_depth() == undo_before + 1,
		"постановка — один шаг отмены, а не три; получено %d" % (editor.history.undo_depth() - undo_before))

	editor._undo()
	assert(editor.document.placements.placements.is_empty(), "отмена убрала запись")
	assert(terrain.height_of(Vector2i(12, 12)) == 2, "и вернула рельеф тем же шагом")
	assert(not terrain.is_anchor(Vector2i(12, 12)), "и отпустила якоря")
	editor._redo()
	assert(editor.document.placements.placements.size() == 1, "повтор вернул здание")

	# Снос не возвращает рельеф (§11.4), но и не оставляет землю закреплённой.
	editor._brush.hovered_cell = Vector2i(13, 13)
	fill.handle_input(_click(MOUSE_BUTTON_RIGHT, true, true))
	assert(editor.document.placements.placements.is_empty(), "Shift+ПКМ снёс здание")
	assert(terrain.height_of(Vector2i(12, 12)) == record.level_value,
		"снос оставляет площадку спланированной")
	assert(not terrain.is_anchor(Vector2i(12, 12)), "и снимает якорь")
	editor._undo()
	editor._undo()
	editor._undo()
	fill.select_palette_entry(&"")
	print("  building placement + shared undo ok")


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


## Snow is a terrain state, but the map editor must not author it below open
## water or on near-vertical ground. A frozen lake remains eligible because ice
## is a real walking surface.
func _test_snow_paint_respects_water_and_slope(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	var wet_cell := Vector2i(-6, 6)
	var dry_cell := Vector2i(12, 12)
	assert(editor.document.water.is_wet(terrain, wet_cell), "water test created an open-water cell")
	editor._select_mode(&"surface")
	var surface := editor._active as SurfaceModeController
	surface._tool = SurfaceModeController.TOOL_SNOW
	surface._snow_level = 3
	editor._brush.hovered_cell = wet_cell
	editor._brush.has_hover = true
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(terrain.snow_depth_at(wet_cell) == 0, "open water rejected snow")

	editor._brush.hovered_cell = dry_cell
	editor._brush.has_hover = true
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(terrain.snow_depth_at(dry_cell) == 3, "dry ground accepts snow")
	terrain.set_cell_state(
		dry_cell, terrain.height_of(dry_cell), SlopeCatalog.CLASS_VERY_STEEP,
		SlopeCatalog.DIR_E, 0, terrain.material_index_at(dry_cell),
		terrain.flags_of(dry_cell), terrain.detail_at(dry_cell),
	)
	surface._snow_level = 0
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(terrain.snow_depth_at(dry_cell) == 0, "snow can always be cleared")
	surface._snow_level = 2
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	surface.handle_input(_click(MOUSE_BUTTON_LEFT, false))
	assert(terrain.snow_depth_at(dry_cell) == 0, "very steep ground rejected snow")
	terrain.set_cell_state(
		dry_cell, terrain.height_of(dry_cell), SlopeCatalog.CLASS_FLAT,
		0, 0, terrain.material_index_at(dry_cell), terrain.flags_of(dry_cell), terrain.detail_at(dry_cell),
	)
	# The border-ocean case starts without an ordinary body. Drain the complete
	# body through the same inverse action exposed to authors.
	editor._select_mode(&"water")
	editor._water_brush.hovered_cell = wet_cell
	editor._water_brush.has_hover = true
	editor._water_brush.tool = WaterBrushController.TOOL_FLOOD
	editor._water_brush.apply_secondary()
	assert(not editor.document.water.is_wet(terrain, wet_cell), "snow case drained its whole test body")
	print("  snow surface rules ok")


## Water mode end to end: choose water, dig a hollow, create and fill in one click,
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
	editor._active.select_palette_entry(&"liquid_water")
	assert(water.body_count() == 0, "choosing a liquid does not create an empty body")

	var undo_before: int = editor.history.undo_depth()
	var topology_before: int = editor._nav_grid.topology_revision()
	editor._water_brush.hovered_cell = cell
	editor._water_brush.has_hover = true
	editor._water_brush.tool = WaterBrushController.TOOL_FLOOD
	# The scene test has no real viewport pointer over this authored cell; drive
	# the production brush after selecting the mode exactly as the controller does.
	editor._context.set_edit_label("наполнение водоёма")
	editor._water_brush.apply()

	assert(water.body_count() == 1, "the first stroke created the body")
	assert(editor._water_brush.body_id != WaterBody.NO_BODY, "and selected it")
	var body_id: int = editor._water_brush.body_id
	assert(water.is_wet(terrain, cell), "the stroke filled the hollow")
	assert(water.depth_steps_at(terrain, cell) == 1, "one step deep initially")
	editor._water_brush.adjust_level(3)
	assert(water.depth_steps_at(terrain, cell) == 4, "four steps deep")
	assert(editor.history.undo_depth() >= undo_before + 1, "the stroke is on the SHARED stack")
	assert(editor._nav_grid.topology_revision() != topology_before, "routing heard about it")
	assert(not editor._nav_grid.is_walkable(cell), "and refuses to walk through it")

	# The neighbouring cells were dug by the same brush one step down, so the same
	# level leaves them as a ford: crossable, three times the price.
	editor._undo()
	editor._undo()
	assert(not water.is_wet(terrain, cell), "undo drained it")
	assert(editor._nav_grid.is_walkable(cell), "and gave routing the ground back")
	editor._redo()
	editor._redo()
	assert(water.is_wet(terrain, cell), "redo filled it again")

	# The inverse of Flood is intentionally whole-body drainage, never a patch
	# erase. It is one shared-history command and returns navigation immediately.
	editor._water_brush.hovered_cell = cell
	editor._water_brush.has_hover = true
	editor._context.set_edit_label("удаление водоёма")
	editor._water_brush.apply_secondary()
	assert(not water.has_body(body_id), "reverse flood removed the whole body")
	assert(editor._nav_grid.is_walkable(cell), "draining republished navigation")
	editor._undo()
	assert(water.has_body(body_id) and water.is_wet(terrain, cell), "undo restored the flooded body")

	# Test flow brush (Течение)
	editor._water_brush.tool = WaterBrushController.TOOL_FLOW
	editor._water_brush.flow_direction = SlopeCatalog.DIR_E
	editor._water_brush.flow_strength = 2
	editor._water_brush.hovered_cell = cell
	editor._water_brush.has_hover = true
	editor._water_brush.apply()
	var body_after_flow := water.body(body_id)
	assert(body_after_flow != null and body_after_flow.flow_strength_at(cell) == 2, "flow brush applied flow strength")
	assert(body_after_flow.flow_direction_at(cell) == SlopeCatalog.DIR_E, "flow brush applied flow direction")

	# Test retyping and level adjustments on selected body
	editor._water_brush.select_body(body_id)
	assert(editor.water_highlight.visible, "water highlight visible when body selected")
	editor._active.activate_option(WaterModeController.OPTION_RIVER)
	assert(water.body(body_id).type == WaterBody.Type.RIVER, "retyped body to river")
	# A surface raised above the surrounding plain correctly spreads all the way
	# to the map edge. Lower it back into its basin so the following snow case has
	# both open water and genuinely dry ground to exercise.
	editor._water_brush.adjust_level(-3)
	assert(water.has_body(body_id) and water.is_wet(terrain, cell), "lowered body remains in its basin")
	assert(not water.is_wet(terrain, Vector2i(12, 12)), "lowered body no longer covers the plain")

	print("  water fill + flow brush + highlight + shared undo ok")


func _test_ocean_boundary_floods_only_from_the_edge(editor: Node) -> void:
	var terrain: TerrainGrid = editor.document.terrain
	var water: WaterGrid = editor.document.water
	var edge := terrain.min_cell()
	var inland := Vector2i(20, 20)
	# Nothing outside leaves even an exposed low edge dry.
	editor.document.meta.border_kind = MapMeta.BORDER_NOTHING
	editor._apply_header_change("nothing")
	editor._terrain_service.apply_operation(TerrainEditOperation.offset([edge, inland], -1))
	assert(not water.is_wet(terrain, edge), "an empty border does not flood")
	assert(not water.is_wet(terrain, inland), "an inland hollow stays dry")
	# Switching to ocean fills the edge-connected lowland, but never the separate
	# depression: an author remains responsible for filling that one in Water.
	editor.document.meta.border_kind = MapMeta.BORDER_OCEAN
	editor._apply_header_change("ocean")
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

	# Natural fill is authored like any other entity: place a grass source and a
	# firefly cluster in fill mode, then prove both survive the package round trip
	# as typed records (the contract the procedural-startup removal depends on).
	editor._select_mode(&"fill")
	editor._active.select_palette_entry(&"core:grass_source")
	editor._brush.hovered_cell = Vector2i(3, 4)
	editor._brush.has_hover = true
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	editor._active.select_palette_entry(&"core:fireflies")
	editor._brush.hovered_cell = Vector2i(9, -2)
	editor._active.handle_input(_click(MOUSE_BUTTON_LEFT, true))
	var placed_kinds: Array = []
	for record: MapEntityRecord in editor.document.entities.entities:
		placed_kinds.append(String(record.archetype_id))
	assert(placed_kinds.count("core:grass_source") == 1, "fill authored a grass source")
	assert(placed_kinds.count("core:fireflies") == 1, "fill authored a firefly cluster")
	var placed_count: int = editor.document.entities.entities.size()

	var service := MapDocumentService.new()
	var path := service.save_map_to(editor.document, TEST_PACKAGE)
	assert(not path.is_empty(), "saved: %s" % service.last_error)
	assert(not editor.document.dirty, "saving cleared the dirty flag")

	var reopened := service.load_package(TEST_PACKAGE)
	assert(reopened != null, "reopened")
	assert(reopened.meta.name == "Сохранённая", "name survived")
	assert(reopened.meta.board_cells == editor.document.meta.board_cells, "board survived")
	assert(reopened.entities.entities.size() == placed_count, "every authored natural entity survived the round trip")
	var reopened_kinds: Array = []
	for record: MapEntityRecord in reopened.entities.entities:
		reopened_kinds.append(String(record.archetype_id))
	assert(reopened_kinds.count("core:grass_source") == 1, "grass source round-tripped")
	assert(reopened_kinds.count("core:fireflies") == 1, "firefly cluster round-tripped")
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
	var service := MapDocumentService.new(false, TEST_PROJECT_ROOT, TEST_PROJECT_SOURCE)
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
	var nested_dir := TEST_PROJECT_MAPS + "/_test_nested/deep"
	var nested := nested_dir + "/keeps_place.gdmap"
	MapDocumentService._remove_directory(TEST_PROJECT_MAPS + "/_test_nested")
	DirAccess.make_dir_recursive_absolute(nested_dir)

	var service := MapDocumentService.new(false, TEST_PROJECT_ROOT, TEST_PROJECT_SOURCE)
	var document := MapDocument.create(&"keeps_place", "На месте", MapMeta.PRESET_ARENA)
	assert(not service.save_map_to(document, nested).is_empty(), "first write: %s" % service.last_error)

	# Reopening from that path is what the editor's Open does, and it is what binds
	# `current_path`.
	var previous_document: MapDocument = editor.document
	var previous_path: String = editor.current_path
	var previous_service = editor._service
	# Run as a player: the scene opened straight from Godot defaults to dev mode,
	# which writes the shipped pack and would rightly refuse this path.
	editor._service = MapDocumentService.new(false, TEST_PROJECT_ROOT, TEST_PROJECT_SOURCE)
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
	assert(not DirAccess.dir_exists_absolute(TEST_PROJECT_MAPS + "/keeps_place.gdmap"),
		"a save must not also create a copy under the source root")

	editor._service = previous_service
	editor.document = previous_document
	editor.current_path = previous_path
	editor._build_services()
	MapDocumentService._remove_directory(TEST_PROJECT_MAPS + "/_test_nested")
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
	editor._service = MapDocumentService.new(false, TEST_PROJECT_ROOT, TEST_PROJECT_SOURCE)

	editor._on_open_requested(shipped)
	assert(editor.document != null, "the shipped map opened")
	assert(editor.current_path.is_empty(),
		"a map from a source this mode cannot write must detach, got %s" % editor.current_path)
	assert(editor._binding_line().contains(TEST_PROJECT_MAPS),
		"and the panel says where a save would go instead: %s" % editor._binding_line())

	editor._service = previous_service
	editor.document = previous_document
	editor.current_path = previous_path
	editor._build_services()
	print("  read-only detach ok")


func _click(button: int, pressed: bool, shift := false, ctrl := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	return event


func _key(keycode: Key, ctrl := false, shift := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	return event


## Materials the surface palette files under "Экзопланеты". Derived from the
## catalog's `origin` (§8) for the same reason the palette itself is: a test that
## keeps its own list of the alien materials stops testing the grouping and starts
## testing its own copy of it.
static func _exoplanet_material_count() -> int:
	return (
		TerrainMaterialCatalog.count()
		- TerrainMaterialCatalog.indices_of_origin(TerrainMaterialCatalog.ORIGIN_EARTH).size()
	)
