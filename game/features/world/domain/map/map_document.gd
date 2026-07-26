class_name MapDocument
extends RefCounted

## One map, whole, in memory (design_docs/core/map_editor.md §15).
##
## Pure data: no nodes, no files, no rendering. `MapDocumentService` reads and
## writes it, the editor mutates it, `GameLaunchManager` starts a session from it.
##
## The layers phases 2–5 will fill — placements, objects, regions, markers,
## routes, flags, rules, victory, defeat — are already carried here as raw
## JSON-safe arrays. That is deliberate and it is the point of this class existing
## in phase 1: a map authored later and opened in an earlier build must come back
## out of the editor with its rules intact. An editor that silently dropped the
## sections it does not understand would corrupt every map it touched, and the
## author would not find out until the map stopped working.

## Sections the format defines but this phase does not interpret. They round-trip
## byte-for-byte through the editor.
const PASSTHROUGH_SECTIONS: Array[String] = [
	"placements", "objects", "regions", "markers", "routes",
	"flags", "rules", "victory", "defeat",
]

## `flags` is the odd one out (§10): named booleans and counters, so an object,
## while everything else is an ordered list. Writing it as `[]` would produce a
## file that does not match the format the rules engine will read.
const OBJECT_SECTIONS: Array[String] = ["flags"]

var meta: MapMeta = MapMeta.new()
## The board itself. Always configured to `meta.board_cells`, flat until a
## `terrain.bin` is decoded into it.
var terrain: TerrainGrid = TerrainGrid.new()

## Raw contents of the sections listed above, plus any key a future version adds
## that this build has never heard of.
var sections: Dictionary = {}

## True once anything has been edited since the last save. The editor's title bar
## and its "discard changes?" prompt read this, and nothing else may write it.
var dirty := false


static func create(id: StringName, name: String, board_cells := MapMeta.DEFAULT_BOARD_CELLS) -> MapDocument:
	var document := MapDocument.new()
	document.meta.id = id
	document.meta.name = name
	document.meta.board_cells = board_cells
	document.configure_terrain()
	return document


## Sizes the grid to the header. Called after the meta is read and before the
## terrain layer is decoded, because the layer only fits a board it matches.
func configure_terrain() -> void:
	terrain.configure(meta.cell_size, meta.board_cells)


func board_cells() -> int:
	return meta.board_cells


func mark_dirty() -> void:
	dirty = true


# --- map.json ----------------------------------------------------------------

static func from_json(source: Dictionary) -> MapDocument:
	var document := MapDocument.new()
	document.meta = MapMeta.from_dict(source)
	document.configure_terrain()
	for key: String in source:
		if _is_meta_key(key):
			continue
		document.sections[key] = _duplicated(source[key])
	return document


func to_json() -> Dictionary:
	var result := meta.to_dict()
	result["format_version"] = MapMeta.FORMAT_VERSION
	# Declared sections are always written, even when empty, so a map file reads
	# the same whether or not its author ever opened those modes.
	for key: String in PASSTHROUGH_SECTIONS:
		var empty: Variant = {} if OBJECT_SECTIONS.has(key) else []
		result[key] = _duplicated(sections.get(key, empty))
	# ...and anything a newer build left behind survives untouched.
	for key: String in sections:
		if not result.has(key):
			result[key] = _duplicated(sections[key])
	return result


## Section contents for a phase that does understand them. Always an Array; a
## section stored as something else by a broken file reads as empty rather than
## crashing the loader.
func section(key: String) -> Array:
	var value: Variant = sections.get(key, [])
	return value if value is Array else []


func set_section(key: String, value: Array) -> void:
	sections[key] = _duplicated(value)
	mark_dirty()


static func _is_meta_key(key: String) -> bool:
	return key in [
		"format_version", "kind", "id", "name", "author", "biomes", "tags", "revision",
		"board", "border", "start", "required_content",
	]


static func _duplicated(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value
