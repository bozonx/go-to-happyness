extends SceneTree

## End-to-end test of the editor's zones mode against the real scene
## (design_docs/engine/active_zones.md §11).
##
## It drives BuildingEditor + ZonesModeController the way the UI does. Unit tests
## over the records cannot catch a panel whose node paths no longer resolve or a
## tool that arms the wrong role — which is exactly how a rebuilt mode breaks.

const EditorScene = preload("res://game/features/buildings/presentation/editor/building_editor.tscn")


func _initialize() -> void:
	# The scene tree is not up during `_init`, so defer until it is.
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_zones_mode_editor.gd ---")
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	var zones = editor.zones_mode
	assert(zones != null, "controller exists")

	editor._select_mode(editor.EditMode.ZONES)
	assert(zones.is_active(), "zones palette visible")
	assert(editor.get_node("%ZonesInspectorPanel").visible, "inspector visible")
	assert(not editor.get_node("%PalettePanel").visible, "frame palette yields to the zones palette")
	print("  mode switch ok")

	# Tool, then role, then function — the order the model itself is in.
	assert(editor.get_node("%ToolAreaBtn").button_pressed, "area tool armed by default")
	var role_option: OptionButton = editor.get_node("%ZoneRoleOption")
	assert(role_option.item_count == 2, "area tool offers room + overlay, got %d" % role_option.item_count)
	assert(role_option.get_item_metadata(0) == ZoneAreaRecord.ROLE_ROOM)
	zones.handle_key(_key(KEY_W))
	assert(editor.get_node("%ToolPointBtn").button_pressed, "W arms the point tool")
	assert(role_option.item_count == ZoneAnchorRecord.BUILDING_ROLES.size(),
		"point tool offers point roles, got %d" % role_option.item_count)
	zones.handle_key(_key(KEY_Q))
	print("  contextual role list ok")

	# Draw a room with the rectangle drag, the way the UI does.
	editor.cursor_valid = true
	editor.cursor_cell = Vector3i(1, 0, 1)
	zones.handle_mouse_button(_click(true))
	editor.cursor_cell = Vector3i(3, 0, 2)
	zones.handle_mouse_button(_click(false))
	await process_frame
	assert(editor.blueprint.areas.size() == 1, "one area created")
	var room: ZoneAreaRecord = editor.blueprint.areas[0]
	assert(room.is_room())
	assert(room.function == &"", "new areas start without a function")
	assert(room.cell_count() == 6, "3x2 cells, got %d" % room.cell_count())
	print("  rectangle drag ok, cells=", room.cell_count())

	# The function list comes from a pack and is set in the inspector, not the toolbar.
	zones._selected_area_id = room.id
	zones._refresh_inspector()
	var function_option: OptionButton = editor.get_node("%ZoneInspectorFunctionOption")
	assert(function_option.item_count > 1, "core pack functions are offered")
	var kitchen_index := -1
	for i in function_option.item_count:
		if function_option.get_item_metadata(i) == &"core:kitchen":
			kitchen_index = i
	assert(kitchen_index > 0, "the core kitchen is in the list")
	function_option.select(kitchen_index)
	zones._on_inspector_function_selected(kitchen_index)
	assert(room.function == &"core:kitchen", "the function was applied to the selected area")
	assert(room.properties.get("profession") == "cook", "pack defaults filled in")
	print("  inspector function selection ok")

	# A door and a slot. The slot must adopt the room under it automatically.
	zones.handle_key(_key(KEY_W))
	zones._anchor_role = ZoneAnchorRecord.ROLE_DOOR
	editor.cursor_cell = Vector3i(2, 0, 0)
	zones.handle_mouse_button(_click(true))
	zones._anchor_role = ZoneAnchorRecord.ROLE_SLOT
	editor.cursor_cell = Vector3i(2, 0, 1)
	zones.handle_mouse_button(_click(true))
	await process_frame
	assert(editor.blueprint.anchors.size() == 2, "door + slot placed")
	var slot: ZoneAnchorRecord = editor.blueprint.anchors[1]
	assert(slot.is_slot())
	assert(slot.owner_id == room.id, "the slot adopted the room it stands in")
	assert(editor.blueprint.anchors[0].owner_id == &"", "a door stays building-wide")
	slot.arc = 120.0
	zones._selected_anchor_id = slot.id
	zones._selected_area_id = &""
	zones._refresh_inspector()
	assert(editor.get_node("%ZoneAnchorProps").get_child_count() >= 3,
		"slot inspector exposes facing, arc and ownership")
	editor.cursor_cell = Vector3i(3, 0, 1)
	zones._move_selected_anchor_to_cursor()
	assert(slot.cell() == Vector2i(3, 1), "selected point moves to the cursor")
	editor.cursor_cell = Vector3i(2, 0, 1)
	zones._move_selected_anchor_to_cursor()
	print("  anchor placement + ownership ok")

	# A queue point wires itself to the nearest slot.
	zones._anchor_role = ZoneAnchorRecord.ROLE_QUEUE
	editor.cursor_cell = Vector3i(2, 0, 2)
	zones.handle_mouse_button(_click(true))
	await process_frame
	var queue: ZoneAnchorRecord = editor.blueprint.anchors[2]
	assert(queue.is_queue() and queue.target_id == slot.id, "queue points at the slot")
	print("  queue wiring ok")

	# Entrances derive from the door; the format carries no entrance fields.
	assert(editor.blueprint.entrance_offset() == Vector2i(-2, -4),
		"entrance derives from the door: %s" % editor.blueprint.entrance_offset())

	# The tree lists the room with its anchors, and selection round-trips.
	var tree: Tree = editor.get_node("%ZoneTree")
	var root_item := tree.get_root()
	assert(root_item != null and root_item.get_child_count() >= 1, "tree has the area")
	var area_item := root_item.get_child(0)
	assert(area_item.get_child_count() == 2, "slot + queue under the room, got %d" % area_item.get_child_count())
	print("  zone tree ok")

	# Deleting a slot must take its queue with it — no dangling reference.
	zones._selected_anchor_id = slot.id
	zones._selected_area_id = &""
	zones.handle_key(_key(KEY_DELETE))
	await process_frame
	assert(editor.blueprint.anchors.size() == 1, "slot and its queue are gone, %d left" % editor.blueprint.anchors.size())
	assert(editor.blueprint.anchors[0].is_door())
	assert(editor.blueprint.routes.is_empty(), "no routes left after cascade delete")
	print("  cascade delete ok")

	# Deleting the room releases what it owned instead of orphaning it.
	zones._selected_area_id = room.id
	zones._delete_selection()
	await process_frame
	assert(editor.blueprint.areas.is_empty(), "room deleted")
	assert(editor.blueprint.anchors.size() == 1, "the building-wide door survived")

	# An overlay denies an audience and corrects an engine calculation.
	zones._arm_tool(zones.TOOL_AREA)
	zones._area_role = ZoneAreaRecord.ROLE_OVERLAY
	editor.cursor_cell = Vector3i(1, 0, 1)
	zones.handle_mouse_button(_click(true))
	editor.cursor_cell = Vector3i(1, 0, 1)
	zones.handle_mouse_button(_click(false))
	await process_frame
	var overlay: ZoneAreaRecord = editor.blueprint.areas[0]
	assert(overlay.is_overlay())
	assert(not overlay.permits(ZoneAccess.AUDIENCE_VISITOR), "the overlay starts by denying visitors")
	assert(overlay.permits(ZoneAccess.AUDIENCE_STAFF), "staff still pass")
	overlay.effects = {ZoneEffects.KEY_COST: 2.5, ZoneEffects.KEY_CONCEAL: 0.7}
	zones._selected_area_id = overlay.id
	zones._refresh_inspector()
	assert(editor.get_node("%ZoneOverlayEffectsContainer").get_child_count() == ZoneEffects.KEYS.size())
	print("  overlay permissions + effects ok")

	# The whole thing survives a round trip through the file format.
	var reloaded = BuildingBlueprint.from_json(editor.blueprint.to_json())
	assert(reloaded != null, "blueprint serializes: %s" % [editor.blueprint.validation_errors()])
	assert(reloaded.areas.size() == 1 and reloaded.areas[0].is_overlay())
	assert(reloaded.areas[0].effects[ZoneEffects.KEY_COST] == 2.5)
	assert(reloaded.anchors.size() == 1 and reloaded.anchors[0].is_door())
	print("  save/load ok")

	editor.queue_free()
	print("--- test_zones_mode_editor.gd PASSED ---")
	quit(0)


func _click(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
