extends SceneTree

## End-to-end test of "походить по зданию" against the real editor scene.
##
## The building editor had no test run at all: an author could shape a doorway,
## a staircase and a second floor and never find out whether a person fits
## through any of them until the building reached a settlement. This drives the
## thing that answers that — colliders from the block geometry, a person-sized
## capsule, and the entrance as the place it starts.
##
## Against the real scene because the failure modes are all scene-shaped: a
## button whose node path no longer resolves, a UI layer that stays over the
## camera, an input path that keeps placing blocks while the author walks.

const EditorScene = preload("res://game/features/buildings/presentation/editor/building_editor.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_building_walkthrough.gd ---")
	var editor: BuildingEditor = EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	_test_an_empty_blueprint_refuses(editor)
	await _test_walking_a_room(editor)
	_test_test_points_aim_the_start(editor)

	editor.queue_free()
	print("--- test_building_walkthrough.gd PASSED ---")
	quit(0)


## Nothing to walk on is a message, not a body falling forever through an empty
## world while the toolbar is hidden.
func _test_an_empty_blueprint_refuses(editor: BuildingEditor) -> void:
	editor._start_walkthrough()
	assert(editor.walkthrough == null or not editor.walkthrough.is_active(),
		"an empty blueprint does not start a walk")
	assert(editor._editor_ui.visible, "and does not hide the editor either")
	print("  empty blueprint refused ok")


func _test_walking_a_room(editor: BuildingEditor) -> void:
	_build_room(editor)
	await process_frame

	editor._start_walkthrough()
	var walk := editor.walkthrough
	assert(walk != null and walk.is_active(), "the walk-through started")
	assert(not editor._editor_ui.visible, "the toolbar is out of the way")

	var collision := walk.get_node_or_null("WalkCollision")
	assert(collision != null, "colliders were built")
	# One body per visible mesh, plus the ground plane. Trimesh and not a box:
	# a staircase, a wedge and an arch are exactly what an author walks through,
	# and a hull turns all three into a wall.
	assert(collision.get_child_count() > 1, "the blocks became solid, got %d bodies"
		% collision.get_child_count())
	var body := walk.get_node_or_null("WalkBody") as CharacterBody3D
	assert(body != null, "a body was dropped in")
	var capsule := (body.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	assert(is_equal_approx(capsule.height, BuildingWalkthrough.BODY_HEIGHT),
		"the capsule is person-sized, which is what makes a doorway test mean anything")
	var camera := body.get_node_or_null("Camera3D") as Camera3D
	assert(camera != null and camera.current, "the view is from inside the body")

	# Every input belongs to the walk while it runs: a click meant to open a door
	# must not place a block on the wall behind the author's head.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert(walk.handle_input(click), "clicks are swallowed while walking")

	# Gravity is real: the body was dropped in above the floor and settles onto it.
	for _frame in 20:
		await physics_frame
	assert(body.global_position.y < BuildingWalkthrough.BODY_HEIGHT + 1.0,
		"the body fell onto the floor instead of hanging in the air, y=%.2f"
		% body.global_position.y)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	assert(walk.handle_input(escape), "Esc leaves, as it does everywhere else")
	assert(not walk.is_active(), "the walk ended")
	assert(editor._editor_ui.visible, "and the editor came back")
	await process_frame
	assert(walk.get_node_or_null("WalkCollision") == null,
		"colliders are thrown away rather than left to go stale under the next edit")
	assert(editor._camera_controller.camera.current,
		"the editor camera remains current after the walk camera is actually freed")
	assert(is_equal_approx(BuildingWalkthrough.JUMP_SPEED, HumanoidMobility.JUMP_VELOCITY),
		"the editor walk uses the same standard jump as gameplay")
	var jump_height := BuildingWalkthrough.JUMP_SPEED * BuildingWalkthrough.JUMP_SPEED \
		/ (2.0 * BuildingWalkthrough.GRAVITY)
	assert(jump_height > 1.0,
		"the standard jump clears one full authored block, got %.2f m" % jump_height)
	print("  walking a room ok")


## A test point is the author's override for "do not make me walk to the second
## floor again". It aims the start, draws a marker cone and survives a round trip
## through the sidecar.
func _test_test_points_aim_the_start(editor: BuildingEditor) -> void:
	editor.cursor_valid = true
	editor.cursor_cell = Vector3i(3, 0, 4)
	editor.active_layer = 2
	editor._add_test_point_here()
	assert(editor.test_points.points.size() == 1, "the point was placed")
	assert(editor.test_points.points[0].level == 2, "on the layer being edited, not on the ground")

	# The marker is drawn in every mode — the point of a place the author keeps
	# coming back to is being findable while they shape the thing around it. A
	# cone on the cell, with a readable label, standing on its layer.
	assert(editor._test_point_views != null, "a marker container exists")
	assert(editor._test_point_views.get_child_count() == 1, "one marker per point")
	var marker := editor._test_point_views.get_child(0) as MeshInstance3D
	assert(marker != null and marker.mesh is CylinderMesh, "the marker is a cone")
	assert(is_equal_approx(marker.position.x, 3.5) and is_equal_approx(marker.position.z, 4.5),
		"the cone sits on the marked cell, got %s" % marker.position)
	assert(is_equal_approx(marker.position.y, 2.6), "and floats above its layer by half the cone")
	var has_label := false
	for child in marker.get_children():
		if child is Label3D:
			has_label = true
	assert(has_label, "the marker carries a readable label")

	var start := editor._walk_start_position()
	assert(is_equal_approx(start.x, 3.5) and is_equal_approx(start.z, 4.5),
		"the walk starts on the marked cell, got %s" % start)
	assert(is_equal_approx(start.y, 2.0), "and on its layer")

	# Renaming through the inspector relabels the marker without moving the point.
	editor._test_point_dialog = null
	editor._edit_selected_test_point()
	assert(editor._test_point_dialog != null, "the inspector opened on the aimed point")
	editor._on_test_point_renamed(0, "крыша 2 этажа")
	assert(editor.test_points.points[0].name == "крыша 2 этажа", "the name was committed")
	# `persist_test_points` rebuilt the markers, so re-read the cone and its label.
	var relabelled_marker := editor._test_point_views.get_child(0) as MeshInstance3D
	var relabel: Label3D = null
	for child in relabelled_marker.get_children():
		if child is Label3D:
			relabel = child
	assert(relabel != null and relabel.text == "1. крыша 2 этажа",
		"the marker picked up the new name, got %s" % (relabel.text if relabel else "—"))

	# Aiming back at the building's own entrance is one keystroke away.
	editor._select_test_point(-1)
	assert(editor.test_points.selected == -1)
	assert(editor._walk_start_position() != start, "the entrance is a different place")

	# `Shift+F5` walks from the cell under the cursor without putting a point down —
	# the same "just this once" gesture the map editor has.
	editor.cursor_cell = Vector3i(1, 0, 1)
	editor.active_layer = 0
	var from_cursor := editor._cursor_walk_position()
	assert(is_equal_approx(from_cursor.x, 1.5) and is_equal_approx(from_cursor.z, 1.5)
		and is_equal_approx(from_cursor.y, 0.0),
		"a walk from here starts in the middle of the hovered cell, got %s" % from_cursor)

	# And a point can be removed (`Ctrl+F6`). Without it the ninth point was the end
	# of the list and `add` silently started moving the aimed one instead.
	editor._select_test_point(0)
	editor._remove_selected_test_point()
	assert(editor.test_points.points.is_empty(), "the point is gone")
	assert(editor._test_point_views.get_child_count() == 0, "and so is its marker")
	print("  building test points ok")


## A three-by-three floor with walls, which is the smallest thing worth walking
## in. Blocks go through the grid model exactly as a click would put them there.
func _build_room(editor: BuildingEditor) -> void:
	for x in range(0, 3):
		for z in range(0, 3):
			assert(editor.grid_model.place(Vector3i(x, 0, z), &"slab"), "floor slab placed")
	for x in range(0, 3):
		assert(editor.grid_model.place(Vector3i(x, 1, 0), &"cube"), "wall block placed")
	editor.frame_mode.rebuild_all_block_nodes()
