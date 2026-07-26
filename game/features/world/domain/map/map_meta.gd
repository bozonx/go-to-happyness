class_name MapMeta
extends RefCounted

## Header of a map package: who it is, how big the board is, what is beyond it,
## and the conditions a session starts in (design_docs/core/map_editor.md §4.1).
##
## The board size is here and not in a code constant, which is the whole reason
## `SettlementGame.BOARD_CELLS` stops being one (§14.1). It is chosen once at
## creation and never changed: resizing reconfigures the `TerrainGrid`, moves
## every absolute coordinate and rebuilds navigation, so it is a migration of its
## own (§17.2), not a property edit.

const KIND_MAP := &"map"
## A prefab is the same file with relative coordinates and no board — a district
## or a base placed onto a map through the same Placement Merge as a building
## (§2). Phase 1 reads and writes the field but only authors `map`.
const KIND_PREFAB := &"prefab"

const BORDER_OCEAN := &"ocean"

const FORMAT_VERSION := 1

## Board presets (§6.2). All are multiples of `TerrainGrid.CHUNK_CELLS` so the
## board is whole chunks. The default is the largest one that still loads
## promptly — see the publication measurement in §6.2.
const PRESET_ARENA := 64
const PRESET_SMALL := 128
const PRESET_STANDARD := 256
const PRESET_LARGE := 512
const BOARD_PRESETS: Array[int] = [PRESET_ARENA, PRESET_SMALL, PRESET_STANDARD, PRESET_LARGE]
const DEFAULT_BOARD_CELLS := PRESET_SMALL
const DEFAULT_CELL_SIZE := 1.0

var kind: StringName = KIND_MAP
var id: StringName = &""
var name := ""
var author := ""
var biomes: Array[StringName] = []
var tags: Array[StringName] = []
## Changes on every save. A game save stores it alongside `map_ref` so a session
## can tell the player its map was edited since (§14.2) — it never blocks loading.
var revision := ""

var board_cells := DEFAULT_BOARD_CELLS
var cell_size := DEFAULT_CELL_SIZE

var border_kind: StringName = BORDER_OCEAN
var border_level := -1.5

var start: MapStart = MapStart.new()

## User blueprints and assets the map needs (§13). A missing entry is reported and
## the map still opens: refusing would make another author's map uneditable.
var required_content: Array[Dictionary] = []


static func from_dict(source: Dictionary) -> MapMeta:
	var meta := MapMeta.new()
	meta.kind = StringName(source.get("kind", meta.kind))
	meta.id = StringName(source.get("id", meta.id))
	meta.name = String(source.get("name", meta.name))
	meta.author = String(source.get("author", meta.author))
	for biome: Variant in source.get("biomes", []):
		meta.biomes.append(StringName(biome))
	for tag: Variant in source.get("tags", []):
		meta.tags.append(StringName(tag))
	meta.revision = String(source.get("revision", meta.revision))

	var board: Dictionary = source.get("board", {})
	meta.board_cells = maxi(int(board.get("cells", meta.board_cells)), 0)
	meta.cell_size = float(board.get("cell_size", meta.cell_size))

	var border: Dictionary = source.get("border", {})
	meta.border_kind = StringName(border.get("kind", meta.border_kind))
	meta.border_level = float(border.get("level", meta.border_level))

	meta.start = MapStart.from_dict(source.get("start", {}))
	for entry: Variant in source.get("required_content", []):
		if entry is Dictionary:
			meta.required_content.append((entry as Dictionary).duplicate(true))
	return meta


func to_dict() -> Dictionary:
	var result := {
		"kind": String(kind),
		"id": String(id),
		"name": name,
		"author": author,
		"biomes": biomes.map(func(value: StringName) -> String: return String(value)),
		"tags": tags.map(func(value: StringName) -> String: return String(value)),
		"revision": revision,
		"required_content": required_content.duplicate(true),
	}
	# A prefab has no board of its own and no session to start: its coordinates are
	# relative to an anchor and its ground merges into the host map (§4.1).
	if kind != KIND_PREFAB:
		result["board"] = {"cells": board_cells, "cell_size": cell_size}
		result["border"] = {"kind": String(border_kind), "level": border_level}
		result["start"] = start.to_dict()
	return result


func board_metres() -> float:
	return float(board_cells) * cell_size


## Whether a board size can be authored. Anything not a whole number of chunks
## would leave a partial chunk that the mesher and the save format both assume
## cannot exist.
static func is_valid_board_size(cells: int) -> bool:
	return cells > 0 and cells % TerrainGrid.CHUNK_CELLS == 0


static func preset_name(cells: int) -> String:
	match cells:
		PRESET_ARENA: return "Арена"
		PRESET_SMALL: return "Малая"
		PRESET_STANDARD: return "Стандартная"
		PRESET_LARGE: return "Большая"
	return "%d×%d" % [cells, cells]
