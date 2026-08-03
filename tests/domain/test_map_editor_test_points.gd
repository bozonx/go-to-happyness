class_name TestMapEditorTestPoints
extends RefCounted

## Domain tests for the editor's named launch places (`map_editor.md` §12).
##
## They are editor state and not map data, and every case here is about that
## distinction holding: the sidecar sits beside the package, an unreadable one
## reads as "no points" rather than as an error, and an empty list leaves no file
## behind.

const PACKAGE := "user://test_maps/test_points.gdmap"


static func run_all() -> void:
	_test_a_map_with_no_sidecar_has_no_points()
	_test_points_survive_a_round_trip()
	_test_a_name_set_and_emptied_round_trips()
	_test_an_emptied_list_removes_the_file()
	_test_a_damaged_or_future_sidecar_reads_as_empty()
	_test_the_list_is_capped_and_the_cap_moves_the_point()
	print("    [PASS] Map Editor Test Points Tests")


static func _fresh() -> EditorTestPoints:
	DirAccess.make_dir_recursive_absolute(PACKAGE)
	var sidecar := EditorTestPoints.sidecar_path(PACKAGE)
	if FileAccess.file_exists(sidecar):
		DirAccess.remove_absolute(sidecar)
	return EditorTestPoints.load_for(PACKAGE)


## The sidecar lives *beside* the package, not inside it: a package is saved by
## writing a temporary folder and swapping it in, and anything inside that is not
## a known layer gets cleaned up as a stray.
static func _test_a_map_with_no_sidecar_has_no_points() -> void:
	var state := _fresh()
	assert(state.points.is_empty())
	assert(state.selected == -1, "an untouched map runs from its own entrance")
	assert(EditorTestPoints.sidecar_path(PACKAGE) == PACKAGE + ".editor.json")
	assert(not EditorTestPoints.sidecar_path(PACKAGE).begins_with(PACKAGE + "/"),
		"the sidecar is beside the package, not in it")
	assert(EditorTestPoints.sidecar_path("").is_empty(), "an unsaved map has nowhere to write")


static func _test_points_survive_a_round_trip() -> void:
	var state := _fresh()
	state.add(Vector2i(-12, 30), 4, "у брода")
	state.add(Vector2i(8, 8), 0)
	state.selected = 0
	assert(state.save_to(PACKAGE))

	var reloaded := EditorTestPoints.load_for(PACKAGE)
	assert(reloaded.points.size() == 2)
	assert(reloaded.points[0].cell == Vector2i(-12, 30) and reloaded.points[0].level == 4)
	assert(reloaded.points[0].name == "у брода")
	# An unnamed point is still addressable — the number is its name.
	assert(reloaded.points[1].display_name(1) == "точка 2")
	assert(reloaded.selected == 0, "the editor comes back aimed where it was left")
	assert(reloaded.index_at_cell(Vector2i(8, 8)) == 1)
	assert(reloaded.index_at_cell(Vector2i(0, 0)) == -1)


## The name field is the one thing the inspector writes, and `display_name` is
## what every label and menu row reads. A point with a name shows it; a point
## without one falls back to its number; setting and clearing the name moves the
## point between the two, and both survive a save. This is the contract the
## `EditorTestPointDialog` relies on without owning any of it.
static func _test_a_name_set_and_emptied_round_trips() -> void:
	var state := _fresh()
	var point := state.add(Vector2i(2, 2), 0)
	assert(point.name == "" and point.display_name(0) == "точка 1",
		"a point placed without a name is 'точка N', not a blank")

	point.name = "у колодца"
	assert(point.display_name(0) == "у колодца", "a set name shows verbatim")
	state.save_to(PACKAGE)
	var reloaded := EditorTestPoints.load_for(PACKAGE)
	assert(reloaded.points[0].name == "у колодца")
	assert(reloaded.points[0].display_name(0) == "у колодца")

	# Clearing the name falls back to the number again — an author who typed a
	# name and then emptied the field expects the marker to read its number.
	reloaded.points[0].name = ""
	assert(reloaded.points[0].display_name(0) == "точка 1")


static func _test_an_emptied_list_removes_the_file() -> void:
	var state := _fresh()
	state.add(Vector2i(1, 1), 0)
	assert(state.save_to(PACKAGE))
	state.remove_at(0)
	assert(state.selected == -1, "removing the aimed point falls back to the map's entrance")
	assert(state.save_to(PACKAGE))
	assert(not FileAccess.file_exists(EditorTestPoints.sidecar_path(PACKAGE)),
		"an empty list leaves no file beside the package")


## An author cannot act on a complaint about a file they did not know existed, so
## a broken sidecar is silence, not an error.
static func _test_a_damaged_or_future_sidecar_reads_as_empty() -> void:
	_fresh()
	var path := EditorTestPoints.sidecar_path(PACKAGE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert(EditorTestPoints.load_for(path.get_base_dir() + "/test_points.gdmap").points.is_empty())

	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"format_version": EditorTestPoints.FORMAT_VERSION + 1,
		"test_points": [{"x": 1, "z": 1}],
	}))
	file.close()
	assert(EditorTestPoints.load_for(PACKAGE).points.is_empty(),
		"a sidecar from a newer build is ignored rather than half-read")
	DirAccess.remove_absolute(path)


## Nine, because the shortcuts are `Alt+1`…`Alt+9`. The tenth press means "here
## instead", not "nowhere" — a button that stops responding teaches nothing.
static func _test_the_list_is_capped_and_the_cap_moves_the_point() -> void:
	var state := _fresh()
	for index in EditorTestPoints.MAX_POINTS:
		state.add(Vector2i(index, 0), 0)
	assert(state.points.size() == EditorTestPoints.MAX_POINTS)
	assert(state.selected == EditorTestPoints.MAX_POINTS - 1)

	var moved := state.add(Vector2i(50, 50), 2)
	assert(state.points.size() == EditorTestPoints.MAX_POINTS, "the list did not grow")
	assert(moved.cell == Vector2i(50, 50), "the aimed point moved to the new cell")
	assert(state.selected_point().cell == Vector2i(50, 50))
