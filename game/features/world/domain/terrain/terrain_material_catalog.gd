class_name TerrainMaterialCatalog
extends RefCounted

## Terrain surface materials (design_docs/core/grid_terrain_system.md §4.2, §7.1).
##
## A material is not decoration: it decides the angle of repose used by the
## cascade solver, and later the navigation weight and the soil yielded by
## digging. Visual look-up (colours, textures, splatmap channels) belongs to
## presentation and is deliberately absent here.
##
## `index` is the stable byte written into saves and into the grid's packed
## arrays. Saves store the string id list in the header (§12), so appending a
## material never rewrites old chunks.

const GRASS := &"grass"
const DIRT := &"dirt"
const STONE := &"stone"
const SAND := &"sand"
const SNOW := &"snow"

const MATERIALS: Array = [
	{"id": GRASS, "index": 0, "repose_class": 3},
	{"id": DIRT, "index": 1, "repose_class": 3},
	{"id": STONE, "index": 2, "repose_class": 5},
	{"id": SAND, "index": 3, "repose_class": 2},
	{"id": SNOW, "index": 4, "repose_class": 2},
]

const DEFAULT_MATERIAL := GRASS


static func has_material(material_id: StringName) -> bool:
	return index_of(material_id) >= 0


static func index_of(material_id: StringName) -> int:
	for entry: Dictionary in MATERIALS:
		if entry["id"] == material_id:
			return int(entry["index"])
	return -1


static func id_of_index(material_index: int) -> StringName:
	for entry: Dictionary in MATERIALS:
		if int(entry["index"]) == material_index:
			return entry["id"]
	return DEFAULT_MATERIAL


## Steepest slope class this material holds without a retaining structure.
static func repose_class_of(material_id: StringName) -> int:
	for entry: Dictionary in MATERIALS:
		if entry["id"] == material_id:
			return int(entry["repose_class"])
	return 3


## Steepest height gain per cell this material holds, as a fraction of a step.
## Sand slumps into terraces two cells wide (0.5), grass holds a full step per
## cell, rock holds four.
static func repose_steps_per_cell_of(material_id: StringName) -> float:
	return SlopeCatalog.steps_per_cell_of(SlopeCatalog.id_of_class(repose_class_of(material_id)))


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in MATERIALS:
		result.append(entry["id"])
	return result
