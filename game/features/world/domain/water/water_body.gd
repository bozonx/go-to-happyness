class_name WaterBody
extends RefCounted

## One authored body of water or lava (design_docs/engine/grid_terrain_system.md §9.2).
##
## **The body owns the type, the bottom never does.** The first edition of the
## design derived the kind of water from the bottom material (`riverbed`,
## `lakebed`, `seabed`) and that breaks on the ordinary cases: one river runs over
## gravel, sand and silt without changing colour; a drained channel keeps its type
## and loses its water; and a current is a property of a whole channel, not of
## single cells.
##
## So a cell stores nothing but a reference (`body_id`), a surface level and a
## state byte, and everything that makes water *this* water lives here.
##
## **A type earns its place in the enum only by changing a mechanic** — salinity,
## current or damage. A purely visual difference is not a new type. This is the entry
## rule `terrain_materials.md` §1 puts on the material catalog, applied here for
## the same reason: every type costs a row in five tables forever.
##
## Ice is NOT here: freezing is a state of the cells (`WaterGrid`), because a lake
## can be frozen at its edges and open in the middle, and because the thaw must
## be able to move without rewriting the body. What the body carries is whether
## it freezes at all.

## `body_id` 0 means "dry" in `WaterGrid`, so ids start at 1 and the registry
## holds at most 255 bodies — one byte per cell is the whole point of the layout.
const NO_BODY := 0
const MIN_ID := 1
const MAX_ID := 255

enum Type { SEA, RIVER, LAKE, LAVA }

const TYPE_IDS: Array[StringName] = [&"sea", &"river", &"lake", &"lava"]

## FRESH water is drinkable; SALT is not. That is the only mechanic salinity has,
## and it is why SEA is a type of its own rather than a blue LAKE.
enum Salinity { FRESH, SALT }

## Flow is packed per cell as `dir | strength << 3`: eight compass slots and a
## strength of 0–3, the same encoding the slope descriptor uses for direction so
## the two never need remapping.
const FLOW_DIR_MASK := 0x07
const FLOW_STRENGTH_SHIFT := 3
const FLOW_STRENGTH_MASK := 0x03
const MAX_FLOW_STRENGTH := 3

## A river running this fast does not freeze (§9.6) — the authored rule that gives
## a map both crossable and uncrossable winter water.
const FLOW_STRENGTH_NEVER_FREEZES := 2
## ...and this fast cannot be forded at all (§9.7): the current sweeps a walker off
## their feet whatever the depth.
const FLOW_STRENGTH_BLOCKS_FORD := 3

var id := NO_BODY
var type: Type = Type.LAKE
var name := ""
## Authored surface level in Δh steps. Every cell of one body has this same level;
## a terrain edit may change its footprint or split it, never tilt the surface.
var surface_height := 0
var colour := Color(0.16, 0.35, 0.48, 1.0)
var salinity: Salinity = Salinity.FRESH
var freezes := true
## cell -> packed direction and strength. Sparse on purpose (§9.3): rivers cover
## percentages of a board, and a per-cell array of vectors for them is 9216
## entries to store a few hundred.
var flow: Dictionary = {}


## A body with the defaults of its type. Everything below can be overridden by the
## author; the defaults exist so that picking "river" in the editor already gives
## a river and not a nameless puddle.
static func of_type(body_id: int, body_type: Type) -> WaterBody:
	var body := WaterBody.new()
	body.id = clampi(body_id, MIN_ID, MAX_ID)
	body.type = body_type
	body.name = "%s %d" % [type_id_of(body_type), body.id]
	match body_type:
		Type.SEA:
			body.colour = Color(0.09, 0.26, 0.38, 1.0)
			body.salinity = Salinity.SALT
			# Only a polar map freezes its sea; the author turns this on there.
			body.freezes = false
		Type.RIVER:
			body.colour = Color(0.16, 0.34, 0.42, 1.0)
		Type.LAKE:
			body.colour = Color(0.13, 0.32, 0.45, 1.0)
		Type.LAVA:
			body.colour = Color(0.85, 0.26, 0.06, 1.0)
			body.freezes = false
	return body


static func type_id_of(body_type: Type) -> StringName:
	var index := int(body_type)
	return TYPE_IDS[index] if index >= 0 and index < TYPE_IDS.size() else TYPE_IDS[Type.LAKE]


static func type_of_id(type_id: StringName) -> Type:
	var index := TYPE_IDS.find(type_id)
	return (index if index >= 0 else int(Type.LAKE)) as Type


func type_id() -> StringName:
	return type_id_of(type)


## Lava is not water with a different colour: it is impassable at any depth, it
## burns, and it never freezes (§9.4). Cooled lava is a variant of `stone` — what
## is left when the melt is gone — and therefore a terrain material, not a body.
func is_lava() -> bool:
	return type == Type.LAVA


func is_drinkable() -> bool:
	return not is_lava() and salinity == Salinity.FRESH


# --- Flow ---------------------------------------------------------------------

func set_flow(cell: Vector2i, direction: int, strength: int) -> void:
	var clamped_strength := clampi(strength, 0, MAX_FLOW_STRENGTH)
	if clamped_strength <= 0:
		flow.erase(cell)
		return
	flow[cell] = (direction & FLOW_DIR_MASK) | (clamped_strength << FLOW_STRENGTH_SHIFT)


func clear_flow(cell: Vector2i) -> void:
	flow.erase(cell)


func flow_direction_at(cell: Vector2i) -> int:
	return int(flow.get(cell, 0)) & FLOW_DIR_MASK


func flow_strength_at(cell: Vector2i) -> int:
	return (int(flow.get(cell, 0)) >> FLOW_STRENGTH_SHIFT) & FLOW_STRENGTH_MASK


## Whether this cell can freeze at all. A body that never freezes says no
## everywhere; a fast reach of a river says no just there (§9.6).
func can_freeze_at(cell: Vector2i) -> bool:
	if not freezes or is_lava():
		return false
	return flow_strength_at(cell) < FLOW_STRENGTH_NEVER_FREEZES


# --- Serialisation ------------------------------------------------------------

## JSON shape written into `map.json` beside the grid (§9.2). The cell layer goes
## to `water.bin`; the registry is small, authored and worth reading by eye.
func to_dict() -> Dictionary:
	var flow_entries: Array = []
	for cell: Vector2i in _sorted_cells(flow.keys()):
		flow_entries.append({
			"x": cell.x, "z": cell.y,
			"dir": flow_direction_at(cell), "strength": flow_strength_at(cell),
		})
	return {
		"id": id,
		"type": String(type_id()),
		"name": name,
		"surface_height": surface_height,
		"colour": colour.to_html(false),
		"salinity": "salt" if salinity == Salinity.SALT else "fresh",
		"freezes": freezes,
		"flow": flow_entries,
	}


static func from_dict(source: Dictionary) -> WaterBody:
	var body := of_type(int(source.get("id", MIN_ID)), type_of_id(StringName(source.get("type", "lake"))))
	body.name = String(source.get("name", body.name))
	body.surface_height = int(source.get("surface_height", 0))
	if source.has("colour"):
		body.colour = Color(String(source["colour"]))
	body.salinity = Salinity.SALT if String(source.get("salinity", "fresh")) == "salt" else Salinity.FRESH
	body.freezes = bool(source.get("freezes", body.freezes))
	for entry: Variant in source.get("flow", []):
		if entry is Dictionary:
			var record := entry as Dictionary
			body.set_flow(
				Vector2i(int(record.get("x", 0)), int(record.get("z", 0))),
				int(record.get("dir", 0)), int(record.get("strength", 0)),
			)
	return body


func duplicate_body() -> WaterBody:
	return from_dict(to_dict())


## Deterministic order for anything written to disk (§4.4): a map saved twice
## without an edit between must produce the same bytes.
static func _sorted_cells(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result
