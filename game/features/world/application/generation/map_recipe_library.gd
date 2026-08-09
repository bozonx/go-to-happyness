class_name MapRecipeLibrary
extends RefCounted

## Where `*.gdmapgen.json` recipes live and how they are listed
## (procedural_map_generation.md §3, §11.4).
##
## Two roots and no third. The engine ships its own set — the "posters" the
## laboratory uses as its regression suite — and the author writes theirs into
## `user://`, which is the same split every other kind of authored content in this
## project uses. A recipe is deliberately NOT pack content yet: a pack that could
## carry one would have to declare it in `pack.json` and version it, and nothing
## consumes a recipe at runtime — generation happens once, at authoring time, and
## what ships is the map it produced.

const BUILTIN_DIRECTORY := "res://tools/map_gen_lab/presets"
const USER_DIRECTORY := "user://map_gen_lab/recipes"
const SUFFIX := ".gdmapgen.json"


## Every recipe file, built-ins first, each as
## `{"id": String, "path": String, "builtin": bool}`. Missing directories are not
## an error: a fresh installation has no user recipes and that is the normal case.
static func list() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_collect(BUILTIN_DIRECTORY, true, entries)
	_collect(USER_DIRECTORY, false, entries)
	return entries


static func id_of_path(path: String) -> String:
	return path.get_file().replace(SUFFIX, "")


static func user_path_for(id: String) -> String:
	return "%s/%s%s" % [USER_DIRECTORY, id, SUFFIX]


## Loads a recipe and forces the board size the map already has. The size of a map
## is chosen once, at creation, and cannot change afterwards (`map_editor.md`
## §6.2) — so when an author generates into a 256-cell map with a recipe written
## for 96, it is the recipe that gives way, not the document.
static func load_for_board(path: String, board_cells: int) -> MapRecipe:
	var source := MapRecipe.from_json_path(path)
	if not source.errors.is_empty() and source.board_size != board_cells:
		return source
	var dictionary := source.to_dictionary()
	(dictionary["board"] as Dictionary)["size"] = board_cells
	return MapRecipe.from_dictionary(dictionary)


static func _collect(directory_path: String, builtin: bool, into: Array[Dictionary]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	var names := directory.get_files()
	names.sort()
	for name: String in names:
		if not name.ends_with(SUFFIX):
			continue
		var path := "%s/%s" % [directory_path, name]
		into.append({"id": id_of_path(path), "path": path, "builtin": builtin})
