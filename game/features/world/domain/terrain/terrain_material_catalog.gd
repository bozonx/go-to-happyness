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
## material never rewrites old chunks. As with `SlopeCatalog`, the cascade works
## with the index and never with the `StringName`.

const GRASS := &"grass"
const DIRT := &"dirt"
const STONE := &"stone"
const SAND := &"sand"
const SNOW := &"snow"

## `repose_class` is a slope class from `SlopeCatalog` (§4.2): the steepest slope
## the material holds without a retaining structure.
const MATERIALS: Array = [
	{"id": GRASS, "index": 0, "repose_class": SlopeCatalog.CLASS_STEEP},
	{"id": DIRT, "index": 1, "repose_class": SlopeCatalog.CLASS_STEEP},
	{"id": STONE, "index": 2, "repose_class": SlopeCatalog.CLASS_PRE_CLIFF},
	{"id": SAND, "index": 3, "repose_class": SlopeCatalog.CLASS_MODERATE},
	{"id": SNOW, "index": 4, "repose_class": SlopeCatalog.CLASS_MODERATE},
]

const DEFAULT_MATERIAL := GRASS
const DEFAULT_INDEX := 0

const IDS: Array[StringName] = [GRASS, DIRT, STONE, SAND, SNOW]
const INDEX_BY_ID := {GRASS: 0, DIRT: 1, STONE: 2, SAND: 3, SNOW: 4}
const REPOSE_CLASS_BY_INDEX := PackedInt32Array([
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_PRE_CLIFF,
	SlopeCatalog.CLASS_MODERATE,
	SlopeCatalog.CLASS_MODERATE,
])


static func has_material(material_id: StringName) -> bool:
	return INDEX_BY_ID.has(material_id)


static func is_valid_index(material_index: int) -> bool:
	return material_index >= 0 and material_index < IDS.size()


static func index_of(material_id: StringName) -> int:
	return int(INDEX_BY_ID.get(material_id, -1))


static func id_of_index(material_index: int) -> StringName:
	if not is_valid_index(material_index):
		return DEFAULT_MATERIAL
	return IDS[material_index]


## Steepest slope class this material holds without a retaining structure.
static func repose_class_of_index(material_index: int) -> int:
	if not is_valid_index(material_index):
		return REPOSE_CLASS_BY_INDEX[DEFAULT_INDEX]
	return REPOSE_CLASS_BY_INDEX[material_index]


static func repose_class_of(material_id: StringName) -> int:
	return repose_class_of_index(index_of(material_id))


## Steepest height gain per cell this material holds, as a fraction of a step.
## Sand slumps into terraces two cells wide (0.5), grass holds a full step per
## cell, rock holds four.
static func repose_steps_per_cell_of_index(material_index: int) -> float:
	return SlopeCatalog.steps_per_cell_of_class(repose_class_of_index(material_index))


static func repose_steps_per_cell_of(material_id: StringName) -> float:
	return repose_steps_per_cell_of_index(index_of(material_id))


static func ids() -> Array[StringName]:
	return IDS.duplicate()
