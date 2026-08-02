class_name MapMeta
extends RefCounted

## Header of a map package: who it is, how big the board is, what is beyond it,
## and the conditions a session starts in (design_docs/engine/map_editor.md §4.1).
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

## What lies past the last column of the board (`map_editor.md` §6.1). This is a
## property of the map file, not of a tool or a session: it decides both what the
## horizon looks like and whether lowering a column at the rim floods.
##
## `BORDER_OCEAN` — the world continues as sea at `border_level`. Any lowland
## connected to the rim and lying below that level is water, and the editor keeps
## it that way after every terrain stroke.
## `BORDER_LAVA` — the world continues as lava at `border_level`. Any lowland
## connected to the rim and lying below that level is lava, and the editor keeps
## it that way after every terrain stroke. A lava border body cannot be deleted
## or retyped by the author — only raising the ground above the level drains it.
## `BORDER_NOTHING` — the board ends. Nothing is drawn beyond it and digging at
## the rim digs a dry pit.
const BORDER_OCEAN := &"ocean"
const BORDER_LAVA := &"lava"
const BORDER_NOTHING := &"nothing"
const BORDER_KINDS: Array[StringName] = [BORDER_OCEAN, BORDER_LAVA, BORDER_NOTHING]

## Game-specific start data is namespaced by its owning module in
## `start.module_settings`. Progression is not: it is host functionality, so
## `start.progression` (v7) constrains or disables a game's eras without the map
## naming the module that advances them.
##
## v8 breaks the tie between the party's size and the map's geometry
## (`map_start.md` §16): `spawn_groups[]` replaces one anchor per member,
## `start.starts[]` names the entrances that use them, and each module settings
## section says whether it sets a value, narrows a range or locks a choice.
## `MapFormatMigration` reads v7 and writes v8, so no authored map is lost.
const FORMAT_VERSION := 8

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

## What the map is for (§4.1). Purely a filter in the map list: unlike `kind`,
## which decides how the file is read, nothing in the game branches on this.
const MAP_KIND_MAP := &"map"
const MAP_KIND_SCENARIO := &"scenario"
const MAP_KIND_ARENA := &"arena"
const MAP_KINDS: Array[StringName] = [MAP_KIND_MAP, MAP_KIND_SCENARIO, MAP_KIND_ARENA]

var kind: StringName = KIND_MAP
var id: StringName = &""
var name := ""
var author := ""
## What the map is *for*, as opposed to `kind`, which is what the file *is*
## (`map_editor.md` §4.1). A filter in the map list, never a rule the game enforces.
var map_kind: StringName = MAP_KIND_MAP
## How many players the author designed for. One is not a special case, it is the
## default; the field exists so a co-op map can say so before co-op exists.
var players := 1
var biomes: Array[StringName] = []
var tags: Array[StringName] = []
## Changes on every save. A game save stores it alongside `map_ref` so a session
## can tell the player its map was edited since (§14.2) — it never blocks loading.
var revision := ""

var board_cells := DEFAULT_BOARD_CELLS
var cell_size := DEFAULT_CELL_SIZE

var border_kind: StringName = BORDER_OCEAN
## Sea level in whole Δh steps, like every other height in the system — a border
## that could sit between two terraces would flood by a fraction of a column and
## no part of the grid can express that. Ocean-connected lowland below it is
## water; the default is the terrain's zero.
var border_level := 0

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
	meta.map_kind = StringName(source.get("map_kind", meta.map_kind))
	if meta.map_kind not in MAP_KINDS:
		meta.map_kind = MAP_KIND_MAP
	meta.players = maxi(int(source.get("players", meta.players)), 1)
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
	if meta.border_kind not in BORDER_KINDS:
		meta.border_kind = BORDER_OCEAN
	meta.border_level = int(border.get("level", meta.border_level))

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
		"map_kind": String(map_kind),
		"players": players,
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


## Whether the map continues as sea past its rim. The one question every consumer
## of the border actually asks.
func has_border_ocean() -> bool:
	return border_kind == BORDER_OCEAN


## Whether the map continues as lava past its rim. Same rule as ocean, but the
## border body is lava and the horizon draws a lava plane instead of a sea.
func has_border_lava() -> bool:
	return border_kind == BORDER_LAVA


## Whether anything past the rim floods the board. Both ocean and lava fill
## edge-connected lowland; "nothing" does not.
func has_border_fill() -> bool:
	return border_kind == BORDER_OCEAN or border_kind == BORDER_LAVA


## Static version for callers that hold a kind string rather than a full meta.
static func has_border_fill_static(kind: StringName) -> bool:
	return kind == BORDER_OCEAN or kind == BORDER_LAVA


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
