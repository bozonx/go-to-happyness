class_name TerrainMaterialCatalog
extends RefCounted

## Terrain surface materials (design_docs/engine/terrain_materials.md §2).
##
## A material is not decoration. The entry rule is hard and it is the reason this
## catalog stays small: something becomes a material only when it changes at least
## one of four things — the angle of repose (§4.2 of the parent document), the
## navigation weight, the soil digging yields, or the auto-rock material of the
## vertical face under it. Everything that only looks different is a `variant`
## (`TerrainMaterialVariants`), a decor multimesh, a road, a surface state
## (wear/snow, `TerrainDetailCodec`) or a resource node.
##
## `index` is the stable byte written into the grid's packed arrays and into
## saves. Saves store the string id list in the header (parent §12), so appending
## a material never rewrites old chunks. **Indices are never renumbered after
## release** (§2.6); the one exception was taken here, before phase 4: index 4,
## freed by retiring `snow` (which is a surface state, not a material), now holds
## `gravel`, and 0–3 kept their old meaning.
##
## Visual look-up — colours, textures, array layers — is presentation's business
## and is deliberately absent: the domain hands out numbers and rules only.

const GRASS := &"grass"
const DIRT := &"dirt"
const STONE := &"stone"
const SAND := &"sand"
const GRAVEL := &"gravel"
const MUD := &"mud"
const GRASS_TALL := &"grass_tall"
const SCORCHED := &"scorched"
const ICE := &"ice"
const LUNAR_REGOLITH := &"lunar_regolith"
const LUNAR_ROCK := &"lunar_rock"
const MARS_REGOLITH := &"mars_regolith"
const MARS_ROCK := &"mars_rock"

## Soil types digging yields in survival (parent §8). Plain identifiers: the
## economy that consumes them does not exist yet, and inventing a resource enum
## here would be the second source of truth for it.
const SOIL := &"soil"
const SOIL_STONE := &"stone"
const SOIL_SAND := &"sand"
const SOIL_GRAVEL := &"gravel"
const SOIL_MUD := &"mud"
const SOIL_ASH := &"ash"
const SOIL_ICE := &"ice"
const SOIL_REGOLITH := &"regolith"

## Auto-rock face kinds (§3). A vertical face is never drawn with the top
## material — grass on a sheer wall reads as a rendering bug — so every material
## names what its face is made of instead. Six kinds cover thirteen materials
## because a face is about the rock under the surface, not about the surface.
const CLIFF_ROOTED_SOIL := &"cliff_rooted_soil"
const CLIFF_WET_CLAY := &"cliff_wet_clay"
const CLIFF_SAND_SCREE := &"cliff_sand_scree"
const CLIFF_GRAVEL_SCREE := &"cliff_gravel_scree"
const CLIFF_LAYERED_ROCK := &"cliff_layered_rock"
const CLIFF_ICE_WALL := &"cliff_ice_wall"
const CLIFF_DUST_SLOPE := &"cliff_dust_slope"

const CLIFF_IDS: Array[StringName] = [
	CLIFF_ROOTED_SOIL,
	CLIFF_WET_CLAY,
	CLIFF_SAND_SCREE,
	CLIFF_GRAVEL_SCREE,
	CLIFF_LAYERED_ROCK,
	CLIFF_ICE_WALL,
	CLIFF_DUST_SLOPE,
]

## §2. `repose_class` is a slope class from `SlopeCatalog`: the steepest slope the
## material holds without a retaining structure. `nav_weight` multiplies the base
## traversal cost. `soil` is what digging yields. `cliff` is the face kind under
## it (§3). `wear_weights` overrides `nav_weight` per wear level for the materials
## that declare their weight wear-dependent — for everything else wear is visual
## only (§6.1). `wear_recovery_days` is how many simulated days without a visit
## drop one wear level; 0 means never (rock does not grow back).
const MATERIALS: Array = [
	{
		"id": GRASS, "index": 0, "repose_class": SlopeCatalog.CLASS_STEEP,
		"nav_weight": 1.0, "soil": SOIL, "cliff": CLIFF_ROOTED_SOIL,
		"wear_weights": null, "wear_recovery_days": 4,
	},
	{
		"id": DIRT, "index": 1, "repose_class": SlopeCatalog.CLASS_STEEP,
		"nav_weight": 1.0, "soil": SOIL, "cliff": CLIFF_ROOTED_SOIL,
		"wear_weights": null, "wear_recovery_days": 8,
	},
	{
		"id": STONE, "index": 2, "repose_class": SlopeCatalog.CLASS_PRE_CLIFF,
		"nav_weight": 1.2, "soil": SOIL_STONE, "cliff": CLIFF_LAYERED_ROCK,
		"wear_weights": null, "wear_recovery_days": 0,
	},
	{
		"id": SAND, "index": 3, "repose_class": SlopeCatalog.CLASS_MODERATE,
		"nav_weight": 1.3, "soil": SOIL_SAND, "cliff": CLIFF_SAND_SCREE,
		"wear_weights": null, "wear_recovery_days": 2,
	},
	{
		"id": GRAVEL, "index": 4, "repose_class": SlopeCatalog.CLASS_STEEP,
		"nav_weight": 1.15, "soil": SOIL_GRAVEL, "cliff": CLIFF_GRAVEL_SCREE,
		"wear_weights": null, "wear_recovery_days": 0,
	},
	{
		"id": MUD, "index": 5, "repose_class": SlopeCatalog.CLASS_MODERATE,
		"nav_weight": 2.0, "soil": SOIL_MUD, "cliff": CLIFF_WET_CLAY,
		"wear_weights": null, "wear_recovery_days": 2,
	},
	{
		"id": GRASS_TALL, "index": 6, "repose_class": SlopeCatalog.CLASS_STEEP,
		"nav_weight": 2.0, "soil": SOIL, "cliff": CLIFF_ROOTED_SOIL,
		# §6.1: untouched 2.0, trodden 1.5, a path 1.0. The only material whose
		# weight is wear-dependent today, and the reason `wear` is a nav input at
		# all rather than a texture flag.
		"wear_weights": [2.0, 1.5, 1.0], "wear_recovery_days": 6,
	},
	{
		"id": SCORCHED, "index": 7, "repose_class": SlopeCatalog.CLASS_STEEP,
		"nav_weight": 1.1, "soil": SOIL_ASH, "cliff": CLIFF_ROOTED_SOIL,
		"wear_weights": null, "wear_recovery_days": 4,
	},
	{
		"id": ICE, "index": 8, "repose_class": SlopeCatalog.CLASS_CLIFF,
		# Never below 1.0 (§6.5): a cheaper-than-a-road natural surface would drag
		# every route across the glacier. "Fast on ice" belongs to the movement
		# controller, not to search cost.
		"nav_weight": 1.0, "soil": SOIL_ICE, "cliff": CLIFF_ICE_WALL,
		"wear_weights": null, "wear_recovery_days": 0,
	},
	{
		"id": LUNAR_REGOLITH, "index": 9, "repose_class": SlopeCatalog.CLASS_STEEP,
		"nav_weight": 1.0, "soil": SOIL_REGOLITH, "cliff": CLIFF_DUST_SLOPE,
		"wear_weights": null, "wear_recovery_days": 0,
	},
	{
		"id": LUNAR_ROCK, "index": 10, "repose_class": SlopeCatalog.CLASS_PRE_CLIFF,
		"nav_weight": 1.2, "soil": SOIL_STONE, "cliff": CLIFF_LAYERED_ROCK,
		"wear_weights": null, "wear_recovery_days": 0,
	},
	{
		"id": MARS_REGOLITH, "index": 11, "repose_class": SlopeCatalog.CLASS_MODERATE,
		"nav_weight": 1.1, "soil": SOIL_REGOLITH, "cliff": CLIFF_DUST_SLOPE,
		"wear_weights": null, "wear_recovery_days": 0,
	},
	{
		"id": MARS_ROCK, "index": 12, "repose_class": SlopeCatalog.CLASS_PRE_CLIFF,
		"nav_weight": 1.2, "soil": SOIL_STONE, "cliff": CLIFF_LAYERED_ROCK,
		"wear_weights": null, "wear_recovery_days": 0,
	},
]

const DEFAULT_MATERIAL := GRASS
const DEFAULT_INDEX := 0

## Traversal cost multiplier per snow depth (§6.2). Snow is a state, not a
## material, so it multiplies whatever surface is under it.
const SNOW_WEIGHT_BY_DEPTH: Array[float] = [1.0, 1.4, 1.8, 2.2]

## Parallel lookups by index. The cascade, the mesher and the publisher walk every
## cell of a chunk; none of them may pay for a dictionary scan per query.
const IDS: Array[StringName] = [
	GRASS, DIRT, STONE, SAND, GRAVEL, MUD, GRASS_TALL, SCORCHED, ICE,
	LUNAR_REGOLITH, LUNAR_ROCK, MARS_REGOLITH, MARS_ROCK,
]
const INDEX_BY_ID := {
	GRASS: 0, DIRT: 1, STONE: 2, SAND: 3, GRAVEL: 4, MUD: 5, GRASS_TALL: 6,
	SCORCHED: 7, ICE: 8, LUNAR_REGOLITH: 9, LUNAR_ROCK: 10, MARS_REGOLITH: 11,
	MARS_ROCK: 12,
}
const REPOSE_CLASS_BY_INDEX: Array[int] = [
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_PRE_CLIFF,
	SlopeCatalog.CLASS_MODERATE,
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_MODERATE,
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_CLIFF,
	SlopeCatalog.CLASS_STEEP,
	SlopeCatalog.CLASS_PRE_CLIFF,
	SlopeCatalog.CLASS_MODERATE,
	SlopeCatalog.CLASS_PRE_CLIFF,
]
const NAV_WEIGHT_BY_INDEX: Array[float] = [
	1.0, 1.0, 1.2, 1.3, 1.15, 2.0, 2.0, 1.1, 1.0, 1.0, 1.2, 1.1, 1.2,
]
const CLIFF_INDEX_BY_INDEX: Array[int] = [0, 0, 4, 2, 3, 1, 0, 0, 5, 6, 4, 6, 4]

const MATERIAL_COUNT := 13


static func count() -> int:
	return IDS.size()


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


static func entry_of_index(material_index: int) -> Dictionary:
	if not is_valid_index(material_index):
		return MATERIALS[DEFAULT_INDEX]
	return MATERIALS[material_index]


# --- Repose (parent §4.2) -----------------------------------------------------

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


## True when this surface can hold a direct orthogonal height difference without
## settling. Terrain sculpting resolves an excess through the cascade; a surface
## repaint deliberately does not move ground, so the editor must refuse a paint
## that would leave this column mechanically impossible.
static func holds_height_difference(material_index: int, height_difference_steps: int) -> bool:
	var repose := repose_steps_per_cell_of_index(material_index)
	return is_inf(repose) or abs(height_difference_steps) <= repose + 0.0001


# --- Navigation weight (§2) ---------------------------------------------------

## Base traversal cost multiplier of the bare surface, ignoring wear and snow.
static func nav_weight_of_index(material_index: int) -> float:
	if not is_valid_index(material_index):
		return NAV_WEIGHT_BY_INDEX[DEFAULT_INDEX]
	return NAV_WEIGHT_BY_INDEX[material_index]


static func nav_weight_of(material_id: StringName) -> float:
	return nav_weight_of_index(index_of(material_id))


## True when this material's weight changes with wear (§6.1). For everything else
## wear is a visual and a decor density, and saying so explicitly is what stops
## every trodden cell in the world from becoming a navigation update.
static func wear_changes_weight(material_index: int) -> bool:
	return entry_of_index(material_index)["wear_weights"] != null


## Weight of the surface at a given wear level. Materials that did not declare
## wear-dependence answer with their flat weight.
static func nav_weight_at_wear(material_index: int, wear: int) -> float:
	var weights: Variant = entry_of_index(material_index)["wear_weights"]
	if weights == null:
		return nav_weight_of_index(material_index)
	var table: Array = weights
	return float(table[clampi(wear, 0, table.size() - 1)])


## Full surface weight of a column: material, its wear level, and the snow lying
## on it. Snow multiplies rather than replaces, because it is a state on top of
## whatever the ground is (§6.2).
static func surface_weight(material_index: int, wear: int, snow_depth: int) -> float:
	var depth := clampi(snow_depth, 0, SNOW_WEIGHT_BY_DEPTH.size() - 1)
	return nav_weight_at_wear(material_index, wear) * SNOW_WEIGHT_BY_DEPTH[depth]


## Simulated days without a visit that drop one wear level; 0 for surfaces that
## never recover (§6.1).
static func wear_recovery_days(material_index: int) -> int:
	return int(entry_of_index(material_index)["wear_recovery_days"])


static func recovers_from_wear(material_index: int) -> bool:
	return wear_recovery_days(material_index) > 0


## The editor exposes the wear brush only where traffic leaves a meaningful,
## recoverable surface trace. Rock, gravel, ice and extraterrestrial ground do
## not get a generic brown "path" painted over them.
static func supports_wear(material_index: int) -> bool:
	return recovers_from_wear(material_index)


# --- Digging and faces --------------------------------------------------------

## What one step of this column yields when dug in survival (parent §8).
static func soil_of_index(material_index: int) -> StringName:
	return entry_of_index(material_index)["soil"]


static func soil_of(material_id: StringName) -> StringName:
	return soil_of_index(index_of(material_id))


## The auto-rock face kind drawn on a class-7 side under this column (§3). This is
## the only thing the mesher asks the catalog for.
static func cliff_material_of_index(material_index: int) -> StringName:
	return entry_of_index(material_index)["cliff"]


static func cliff_material_of(material_id: StringName) -> StringName:
	return cliff_material_of_index(index_of(material_id))


## Index of the face kind in `CLIFF_IDS` — the number presentation turns into a
## texture layer.
static func cliff_index_of_index(material_index: int) -> int:
	if not is_valid_index(material_index):
		return CLIFF_INDEX_BY_INDEX[DEFAULT_INDEX]
	return CLIFF_INDEX_BY_INDEX[material_index]


static func cliff_count() -> int:
	return CLIFF_IDS.size()


static func ids() -> Array[StringName]:
	return IDS.duplicate()
