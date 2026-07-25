extends SceneTree

## End-to-end test of the editor's decor mode against the real scene: mode
## switching, snapping, the click path, selection, dragging, property bindings,
## undo and save/load.
##
## It drives BuildingEditor + DecorModeController the way the UI does, which is
## what the previous unit-only coverage missed — decor mode could not place a
## single object while every catalog assertion still passed.

const EditorScene = preload("res://game/features/buildings/presentation/editor/building_editor.tscn")
const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")


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

	# PLACE is context-sensitive: clicking existing decor selects it instead of
	# inserting another object at the same spot. Small decor may still share a
	# grid cell when their footprints do not intersect.
	editor.cursor_hit_pos = Vector3(2.2, 0.0, 2.2)
	decor.on_left_pressed()
	assert(editor.blueprint.objects.size() == 2, "placement mode must not stack decor under the cursor")
	assert(decor.selected_object_id == editor.blueprint.objects[0].id,
		"placement mode selects the object under the cursor")
	print("  occupied placement selects instead of stacking")

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
	decor._set_property("visual_flame_visible", false)
	var node = decor._nodes[decor.selected_object_id]
	assert(node.get_node("Fire").visible == false, "visual_flame_visible=false hides the flame")
	decor._set_property("light_color", "44aaff")
	assert(node.get_node("Light").light_color.is_equal_approx(Color("44aaff")), "colour binding applied")
	print("  property bindings ok")

	# Duplicate, delete, undo, redo.
	decor.duplicate_selection()
	assert(editor.blueprint.objects.size() == 3, "duplicated")
	decor.delete_selection()
	assert(editor.blueprint.objects.size() == 2, "deleted")
	decor.undo()
	assert(editor.blueprint.objects.size() == 3, "undo restored the delete")
	decor.redo()
	assert(editor.blueprint.objects.size() == 2, "redo re-applied the delete")
	decor.undo()
	assert(editor.blueprint.objects.size() == 3, "undo restored the delete again")
	decor.undo()
	assert(editor.blueprint.objects.size() == 2, "undo restored the duplicate")
	print("  undo/redo ok")

	# Collision overlay: toggling on builds overlays, toggling off clears them.
	decor._on_collision_overlay_toggled(true)
	assert(decor._collision_overlays.size() > 0, "collision overlays built for blocking objects")
	decor._on_collision_overlay_toggled(false)
	assert(decor._collision_overlays.is_empty(), "collision overlays cleared on toggle off")
	print("  collision overlay ok")

	# Zone filter: create a zone, assign an object, filter by it, then delete zone.
	# Re-select first object since undo/redo may have cleared the selection.
	decor.select_object(editor.blueprint.objects[0].id)
	assert(decor.find_record(decor.selected_object_id) != null, "object re-selected before zone test")
	var zone := PlaceZoneRecordScript.new()
	zone.zone_id = &"test_zone_1"
	zone.zone_name = "Тестовая зона"
	zone.cells = [Vector3i(2, 0, 2)]
	editor.blueprint.place_zones.append(zone)
	decor._refresh_zone_filter_options()
	# Assign selected object to the zone.
	decor.find_record(decor.selected_object_id).owner_zone_id = &"test_zone_1"
	decor._refresh_inspector()
	assert(decor.find_record(decor.selected_object_id).owner_zone_id == &"test_zone_1", "object assigned to zone")
	# Filter object list by zone — should show only 1 object.
	decor._zone_filter_option.select(1)
	decor._on_zone_filter_selected(1)
	assert(decor._object_list.item_count == 1, "zone filter shows only objects in zone")
	# Reset filter.
	decor._zone_filter_option.select(0)
	decor._on_zone_filter_selected(0)
	assert(decor._object_list.item_count == 2, "all zones filter shows all objects")
	# Delete the zone — on_zone_deleted should clear owner_zone_id.
	decor.on_zone_deleted(&"test_zone_1")
	assert(decor.find_record(decor.selected_object_id).owner_zone_id == &"", "zone deletion clears owner_zone_id")
	print("  zone filter + deletion ok")

	# Replace object: compatible appearance properties must be preserved.
	# campfire and cooking_campfire both share visual_flame_visible (bool) and
	# light_energy (float). Setting non-default values on the campfire, then
	# replacing with cooking_campfire, must carry them over.
	decor.select_object(editor.blueprint.objects[0].id)
	decor._set_property("visual_flame_visible", false)
	decor._set_property("light_energy", 3.5)
	decor.current_asset_id = &"cooking_campfire"
	decor._replace_selected_object()
	assert(editor.blueprint.objects[0].asset_id == &"cooking_campfire",
		"object replaced with cooking_campfire")
	assert(editor.blueprint.objects[0].appearance.get("visual_flame_visible", null) == false,
		"visual_flame_visible must be carried over during replace")
	assert(editor.blueprint.objects[0].appearance.get("light_energy", null) == 3.5,
		"light_energy must be carried over during replace")
	print("  replace preserves appearance ok")

	# Zone bounds: an object at cell centre (x=1.5) must map to cell 1 via floor,
	# not cell 2 via round. Create a zone at cell (1,0,1) and assign the object.
	var zone2 := PlaceZoneRecordScript.new()
	zone2.zone_id = &"test_zone_bounds"
	zone2.zone_name = "Зона проверки границ"
	zone2.cells = [Vector3i(1, 0, 1)]
	editor.blueprint.place_zones.append(zone2)
	var bounds_obj: DecorObjectRecordScript = editor.blueprint.objects[0]
	bounds_obj.pos = Vector3(1.5, 0.0, 1.5)
	bounds_obj.owner_zone_id = &"test_zone_bounds"
	decor.select_object(bounds_obj.id)
	decor._refresh_inspector()
	# _update_zone_highlight is called during _refresh_inspector.
	# With floor, position 1.5 -> cell 1, which is in the zone — no warning.
	assert(not decor._zone_out_of_bounds_label.visible,
		"Object at cell-centre 1.5 must not trigger false out-of-zone warning (floor, not round)")
	print("  zone bounds floor ok")

	# Clean up: remove the zone and revert the object.
	decor.on_zone_deleted(&"test_zone_bounds")
	editor.blueprint.place_zones.erase(zone2)

	# The whole thing must serialize.
	var json: String = editor.blueprint.to_json()
	assert(not json.is_empty(), "blueprint serializes")
	var reloaded = load("res://game/features/buildings/domain/editor/building_blueprint.gd").from_json(json)
	assert(editor.blueprint.validation_errors().is_empty(),
		"a decor-only blueprint must validate: %s" % [editor.blueprint.validation_errors()])
	assert(reloaded != null, "serialized blueprint is valid")
	assert(reloaded.objects.size() == 2, "objects survive save/load")
	assert(reloaded.objects[0].appearance["visual_flame_visible"] == false, "authored property survives")
	print("  save/load ok")

	# Leaving decor mode cleans up.
	editor._select_mode(editor.EditMode.FRAME)
	assert(not decor.is_active(), "decor deactivated")
	assert(editor._metadata_panel.visible, "metadata panel back")
	print("--- test_decor_mode_editor.gd PASSED ---")
	quit(0)
