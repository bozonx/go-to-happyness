class_name MapDocument
extends RefCounted

## One map, whole, in memory (design_docs/engine/map_editor.md §15).
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
	"placements",
	"flags", "rules", "victory", "defeat",
]

## `flags` is the odd one out (§10): named booleans and counters, so an object,
## while everything else is an ordered list. Writing it as `[]` would produce a
## file that does not match the format the rules engine will read.
const OBJECT_SECTIONS: Array[String] = ["flags"]

## The registry of water bodies (grid_terrain_system.md §9.2). Unlike the sections
## above this one IS interpreted: it is parsed into `water` on load and written
## back out of it on save, so the registry has exactly one owner. The cells
## themselves live in `water.bin`, not here.
const WATER_SECTION := "water"

var meta: MapMeta = MapMeta.new()
## The board itself. Always configured to `meta.board_cells`, flat until a
## `terrain.bin` is decoded into it.
var terrain: TerrainGrid = TerrainGrid.new()
## The water layer over the same board (§9.3): levels, body references and ice
## flags per cell, plus the registry of bodies those cells point at. Empty until
## an author paints — a map with no water carries no `water.bin` at all.
var water: WaterGrid = WaterGrid.new()

## The authored active-zone primitives. Unlike scenario rules they are understood
## by the editor and have one typed owner, `MapZoneLayer`.
var zones: MapZoneLayer = MapZoneLayer.new()

## Named authored entities; anonymous scatter remains a later binary layer.
var entities: MapEntityLayer = MapEntityLayer.new()

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


## Sizes both grids to the header. Called after the meta is read and before the
## binary layers are decoded, because a layer only fits a board it matches. Water
## is sized here even on a map that has none: an empty layer of the right size is
## what makes "the author painted no water" indistinguishable from "this build
## does not do water", which is what §16 promised when it reserved the field.
func configure_terrain() -> void:
	terrain.configure(meta.cell_size, meta.board_cells)
	water.configure(meta.cell_size, meta.board_cells)


func board_cells() -> int:
	return meta.board_cells


func mark_dirty() -> void:
	dirty = true


# --- map.json ----------------------------------------------------------------

static func from_json(source: Dictionary) -> MapDocument:
	var document := MapDocument.new()
	document.meta = MapMeta.from_dict(source)
	document.configure_terrain()
	# `natural_scatter` is an obsolete compact-grove key: this build no longer
	# expands it, so an old map that still carries it silently drops that grass
	# and forage. Everything natural lives as explicit `entities[]` records now.
	for key: String in source:
		if _is_meta_key(key) or key == WATER_SECTION or key in ["areas", "anchors", "routes", "entities", "natural_scatter"]:
			continue
		document.sections[key] = _duplicated(source[key])
	document.zones.from_json(source)
	document.entities.from_json(source.get("entities", []))
	document._read_water_registry(source.get(WATER_SECTION, []))
	return document


func to_json() -> Dictionary:
	var result := meta.to_dict()
	result["format_version"] = MapMeta.FORMAT_VERSION
	result[WATER_SECTION] = _water_registry_json()
	for key: String in zones.to_json():
		result[key] = zones.to_json()[key]
	result["entities"] = entities.to_json()
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


# --- Water registry ------------------------------------------------------------

## The bodies, in id order so a map saved twice without an edit produces the same
## bytes. Always written, empty list included, for the same reason the declared
## sections are: a map file should read the same whether or not its author ever
## opened the water mode.
func _water_registry_json() -> Array:
	var entries: Array = []
	for body: WaterBody in water.bodies():
		entries.append(body.to_dict())
	return entries


## A body the registry refuses — a duplicate or a 256th — is dropped rather than
## renumbered: the cells in `water.bin` reference bodies by id, and quietly moving
## one would attach a lake's cells to a river.
func _read_water_registry(source: Variant) -> void:
	water.clear_bodies()
	if not (source is Array):
		return
	for entry: Variant in source as Array:
		if not (entry is Dictionary):
			continue
		var body := WaterBody.from_dict(entry as Dictionary)
		if water.has_body(body.id):
			push_warning("[map] дубликат водоёма id=%d пропущен" % body.id)
			continue
		water.add_body(body)


func set_section(key: String, value: Array) -> void:
	sections[key] = _duplicated(value)
	mark_dirty()


static func _is_meta_key(key: String) -> bool:
	return key in [
		"format_version", "kind", "id", "name", "author", "map_kind", "players",
		"biomes", "tags", "revision", "board", "border", "start", "required_content",
	]


static func _duplicated(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value
