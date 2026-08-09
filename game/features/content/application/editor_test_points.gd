class_name EditorTestPoints
extends RefCounted

## Named places an author launches a test run from (`map_editor.md` §12).
##
## Shared by both editors, and in `content` rather than in either of them because
## that is what it is about: a piece of authoring state belonging to a content
## package on disk, whether that package is a `.gdmap` or a `.gdbuilding.json`.
## A map's point is a board cell and a terrain level; a building's is a grid cell
## and a layer. Same record, same file, same three gestures — put one down, aim at
## it, run — which is the whole reason there is one class and not two.
##
## `Shift+F5` starts the session at the cell under the cursor, and that is the
## right gesture for a glance at a corner. It is the wrong one for the thing
## authors actually do: come back to the *same three* places over and over while
## the terrain around them changes. Doing that with the cursor means re-finding
## the ford by eye every time, and the `▶⌖` button in the top bar could not do it
## at all — the moment the mouse reached the button the hover was gone and the run
## refused with "наведите курсор на клетку карты".
##
## So a test point is a place the author puts down once and launches from by name.
##
## **It is not map data.** It says nothing about the world, nothing a player ever
## meets, and nothing another author opening this map needs. Keeping it in
## `map.json` would put it in the package everyone shares, bump the map's
## `revision` every time somebody moved a marker, and make "поставил тест-точку"
## an edit the author has to remember not to save. It lives in a sidecar file
## beside the package instead: `<name>.gdmap.editor.json`.
##
## Beside the package, deliberately, and not inside it — `MapDocumentService`
## saves a package by writing a temporary folder and swapping it in, and anything
## inside that is not a known layer is a stray it cleans up.

const SIDECAR_SUFFIX := ".editor.json"
const FORMAT_VERSION := 1
## Nine, because the shortcuts are `Alt+1`…`Alt+9`. A tenth place to launch from
## is a map that wants a second entrance, which is a thing the map format already
## says (`map_start.md` §3) and says better.
const MAX_POINTS := 9


## One place, named by the author or by its number.
class Point:
	extends RefCounted

	var name := ""
	var cell := Vector2i.ZERO
	## Which floor the point is on. In a building this is authoritative — it *is*
	## the layer the author was editing, and one layer is one metre. On a map it is
	## the terrain level at the moment of placement and nothing reads it back: both
	## the marker and the launch take the live height, because an author digs under
	## their own test point all the time. It is written and loaded so a map whose
	## terrain is untouched comes back looking the same, and so the two editors
	## share one record.
	var level := 0

	static func from_dict(source: Dictionary) -> Point:
		var point := Point.new()
		point.name = String(source.get("name", ""))
		point.cell = Vector2i(int(source.get("x", 0)), int(source.get("z", 0)))
		point.level = int(source.get("level", 0))
		return point

	func to_dict() -> Dictionary:
		return {"name": name, "x": cell.x, "z": cell.y, "level": level}

	func display_name(index: int) -> String:
		return name if not name.strip_edges().is_empty() else "точка %d" % (index + 1)


var points: Array[Point] = []
## Index the next `F5` uses, or -1 for the map's own entrance. Persisted so the
## editor comes back aimed where the author left it.
var selected := -1
## Set when the last save could not be written — a package under `res://` in an
## exported build, a read-only project folder. The points still work for the
## session; the editor says once that they will not survive it.
var last_error := ""


static func sidecar_path(package_path: String) -> String:
	return "" if package_path.is_empty() else package_path.trim_suffix("/") + SIDECAR_SUFFIX


## Never fails: a map with no sidecar, an unreadable one and one from a future
## version all read as "no test points", because an author cannot act on a
## complaint about a file they did not know existed.
static func load_for(package_path: String) -> EditorTestPoints:
	var state := EditorTestPoints.new()
	var path := sidecar_path(package_path)
	if path.is_empty() or not FileAccess.file_exists(path):
		return state
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return state
	var source := parsed as Dictionary
	if int(source.get("format_version", 0)) > FORMAT_VERSION:
		return state
	for entry: Variant in source.get("test_points", []):
		if entry is Dictionary and state.points.size() < MAX_POINTS:
			state.points.append(Point.from_dict(entry as Dictionary))
	state.selected = clampi(int(source.get("selected", -1)), -1, state.points.size() - 1)
	return state


## Writes the sidecar, or removes it when there is nothing left to remember —
## an empty file beside every map an author ever opened is litter.
func save_to(package_path: String) -> bool:
	last_error = ""
	var path := sidecar_path(package_path)
	if path.is_empty():
		return false
	if points.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return true
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "не удалось записать %s" % path
		return false
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"selected": selected,
		"test_points": points.map(func(point: Point) -> Dictionary: return point.to_dict()),
	}, "\t"))
	file.close()
	return true


## Removes the sidecar of a package the points no longer belong to — the file the
## author just renamed away from with Save As. Without it the old package keeps a
## sidecar naming cells of a map nobody will open again.
static func discard_for(package_path: String) -> void:
	var path := sidecar_path(package_path)
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Adds a point, or moves the selected one when the list is full: the author
## pressing "поставить здесь" for the tenth time means "here instead", not
## "nowhere".
func add(cell: Vector2i, level: int, name := "") -> Point:
	if points.size() >= MAX_POINTS:
		var existing := point_at_index(maxi(selected, 0))
		existing.cell = cell
		existing.level = level
		return existing
	var point := Point.new()
	point.cell = cell
	point.level = level
	point.name = name
	points.append(point)
	selected = points.size() - 1
	return point


func remove_at(index: int) -> void:
	if index < 0 or index >= points.size():
		return
	points.remove_at(index)
	selected = mini(selected, points.size() - 1)


func point_at_index(index: int) -> Point:
	return points[index] if index >= 0 and index < points.size() else null


func selected_point() -> Point:
	return point_at_index(selected)


## The index of the point on a cell, or -1. Used to make "поставить здесь" on a
## cell that already has one select it instead of stacking a second marker on it.
func index_at_cell(cell: Vector2i) -> int:
	for index in points.size():
		if points[index].cell == cell:
			return index
	return -1
