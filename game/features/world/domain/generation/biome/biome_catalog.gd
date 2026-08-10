class_name BiomeCatalog
extends RefCounted

## What a biome IS (procedural_map_generation.md §11.2).
##
## A biome is a computed classification of a column — climate plus the shape of
## the ground under it — and it is the map's answer to "what belongs here". Today
## it decides the surface (`SurfacePainter`); layers 4 and 5 will read the same
## mask for vegetation, resources and fauna. It is deliberately NOT a runtime
## layer: nothing in the game asks a biome anything, the mask is baked into
## materials and objects at generation time (§11.2, "не новый слой истины в
## runtime").
##
## ## The split with `BiomeField`
##
## This file says what each biome is made of; `BiomeField` says where it occurs.
## The two halves are separate because they answer to different things — the
## palette is content, the classification is terrain and climate — and because
## three of the biomes here cannot be expressed as a climate box at all: alpine is
## a height rule, wetland is a drainage rule, and both would corrupt the envelope
## table if they were forced into it.
##
## ## The envelope table is a Whittaker diagram
##
## Every climate biome owns a rectangle in (temperature, moisture). The rectangles
## do not tile the plane and are not meant to: classification picks the NEAREST
## one, so a combination nobody wrote down — hot and half-wet, cold and soaking —
## still lands on the biome that is closest to it rather than on a default. That
## is what keeps the table readable as a diagram instead of as a decision tree.
##
## ## Palettes, and why they are weights
##
## The recipe never names a material. A biome names a handful with weights, and
## `SurfacePainter` resolves them through a low-frequency field, so the ground of
## a meadow is patches of grass, tall grass and bare earth rather than one flat
## colour or per-cell confetti (`terrain_materials.md` §4). The hard rules —
## a face is rock, a bed is silt, sand cannot stand on a step — override the
## palette and belong to the painter, not here.
##
## Only Earth biomes exist. `origin` is the same axis `TerrainMaterialCatalog`
## uses, and it is here so that lunar and martian biomes can be appended without
## the generator having to learn what a planet is.

const ORIGIN_EARTH := TerrainMaterialCatalog.ORIGIN_EARTH

const POLAR_DESERT := &"polar_desert"
const TUNDRA := &"tundra"
const ALPINE := &"alpine"
const BOREAL_FOREST := &"boreal_forest"
const TEMPERATE_FOREST := &"temperate_forest"
const TEMPERATE_GRASSLAND := &"temperate_grassland"
const SHRUBLAND := &"shrubland"
const SAVANNA := &"savanna"
const TROPICAL_FOREST := &"tropical_forest"
const WETLAND := &"wetland"
const DESERT := &"desert"

## °C the temperature axis is divided by when an envelope distance is measured, so
## that one degree does not outweigh the whole moisture axis. Roughly the span
## between a polar and a tropical climate.
const TEMPERATURE_SPAN := 40.0

## `climate` is the envelope in (°C, moisture 0…1); `null` marks a biome that is
## chosen by a rule in `BiomeField` and must never be picked by nearest-envelope.
## `ground` is the palette: material id → relative weight. `beach` is what the
## shore band is made of here, and `bed` is [shallow, deep, channel] — the three
## kinds of ground under water, which are a property of the climate too (a desert
## lagoon has a sand floor, a taiga lake a silt one).
##
## **This table is the only place a biome property is written**, exactly as in
## `TerrainMaterialCatalog`: the lookups below are derived from it at class load,
## so the indexed path and the readable record cannot drift apart.
const BIOMES: Array = [
	{
		"id": POLAR_DESERT, "index": 0, "origin": ORIGIN_EARTH, "priority": 100,
		"climate": {"temperature": [-60.0, -6.0], "moisture": [0.0, 1.0]},
		"ground": {
			TerrainMaterialCatalog.GRAVEL: 0.45,
			TerrainMaterialCatalog.STONE: 0.35,
			TerrainMaterialCatalog.DIRT: 0.20,
		},
		"beach": TerrainMaterialCatalog.GRAVEL,
		"bed": [TerrainMaterialCatalog.GRAVEL, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": TUNDRA, "index": 1, "origin": ORIGIN_EARTH, "priority": 90,
		"climate": {"temperature": [-6.0, 2.0], "moisture": [0.0, 1.0]},
		"ground": {
			TerrainMaterialCatalog.DIRT: 0.45,
			TerrainMaterialCatalog.GRASS: 0.25,
			TerrainMaterialCatalog.GRAVEL: 0.20,
			TerrainMaterialCatalog.MUD: 0.10,
		},
		"beach": TerrainMaterialCatalog.GRAVEL,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		# A rule biome (§11.2): high ground that is cold because it is high. Its
		# palette is bare rock, which is what makes a summit read as a summit
		# without the painter needing a "rock line" of its own.
		"id": ALPINE, "index": 2, "origin": ORIGIN_EARTH,
		"climate": null,
		"ground": {
			TerrainMaterialCatalog.STONE: 0.60,
			TerrainMaterialCatalog.GRAVEL: 0.35,
			TerrainMaterialCatalog.DIRT: 0.05,
		},
		"beach": TerrainMaterialCatalog.GRAVEL,
		"bed": [TerrainMaterialCatalog.GRAVEL, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": BOREAL_FOREST, "index": 3, "origin": ORIGIN_EARTH, "priority": 70,
		"climate": {"temperature": [1.0, 9.0], "moisture": [0.35, 1.0]},
		"ground": {
			TerrainMaterialCatalog.GRASS: 0.45,
			TerrainMaterialCatalog.DIRT: 0.30,
			TerrainMaterialCatalog.MUD: 0.15,
			TerrainMaterialCatalog.GRAVEL: 0.10,
		},
		"beach": TerrainMaterialCatalog.GRAVEL,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": TEMPERATE_FOREST, "index": 4, "origin": ORIGIN_EARTH, "priority": 60,
		"climate": {"temperature": [8.0, 20.0], "moisture": [0.42, 1.0]},
		"ground": {
			TerrainMaterialCatalog.GRASS: 0.55,
			TerrainMaterialCatalog.GRASS_TALL: 0.25,
			TerrainMaterialCatalog.DIRT: 0.20,
		},
		"beach": TerrainMaterialCatalog.SAND,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": TEMPERATE_GRASSLAND, "index": 5, "origin": ORIGIN_EARTH, "priority": 50,
		"climate": {"temperature": [1.0, 18.0], "moisture": [0.15, 0.42]},
		"ground": {
			TerrainMaterialCatalog.GRASS: 0.50,
			TerrainMaterialCatalog.GRASS_TALL: 0.30,
			TerrainMaterialCatalog.DIRT: 0.20,
		},
		"beach": TerrainMaterialCatalog.SAND,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": SHRUBLAND, "index": 6, "origin": ORIGIN_EARTH, "priority": 40,
		"climate": {"temperature": [14.0, 26.0], "moisture": [0.15, 0.40]},
		"ground": {
			TerrainMaterialCatalog.DIRT: 0.35,
			TerrainMaterialCatalog.GRASS: 0.30,
			TerrainMaterialCatalog.GRAVEL: 0.20,
			TerrainMaterialCatalog.CLAY: 0.15,
		},
		"beach": TerrainMaterialCatalog.SAND,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": SAVANNA, "index": 7, "origin": ORIGIN_EARTH, "priority": 30,
		"climate": {"temperature": [20.0, 34.0], "moisture": [0.22, 0.55]},
		"ground": {
			TerrainMaterialCatalog.GRASS: 0.45,
			TerrainMaterialCatalog.DIRT: 0.30,
			TerrainMaterialCatalog.CLAY: 0.25,
		},
		"beach": TerrainMaterialCatalog.SAND,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.GRAVEL],
	},
	{
		"id": TROPICAL_FOREST, "index": 8, "origin": ORIGIN_EARTH, "priority": 20,
		"climate": {"temperature": [21.0, 45.0], "moisture": [0.55, 1.0]},
		"ground": {
			TerrainMaterialCatalog.GRASS_TALL: 0.50,
			TerrainMaterialCatalog.GRASS: 0.30,
			TerrainMaterialCatalog.CLAY: 0.12,
			TerrainMaterialCatalog.MUD: 0.08,
		},
		"beach": TerrainMaterialCatalog.SAND,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.CLAY],
	},
	{
		# The other rule biome: flat, low, wet ground beside standing water. It is
		# drainage, not climate — the same latitude makes a marsh in the hollow and
		# a meadow on the shoulder above it.
		"id": WETLAND, "index": 9, "origin": ORIGIN_EARTH,
		"climate": null,
		"ground": {
			TerrainMaterialCatalog.MUD: 0.50,
			TerrainMaterialCatalog.GRASS_TALL: 0.30,
			TerrainMaterialCatalog.CLAY: 0.20,
		},
		"beach": TerrainMaterialCatalog.MUD,
		"bed": [TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.MUD],
	},
	{
		"id": DESERT, "index": 10, "origin": ORIGIN_EARTH, "priority": 10,
		"climate": {"temperature": [-2.0, 45.0], "moisture": [0.0, 0.15]},
		"ground": {
			TerrainMaterialCatalog.SAND: 0.72,
			TerrainMaterialCatalog.GRAVEL: 0.18,
			TerrainMaterialCatalog.STONE: 0.10,
		},
		"beach": TerrainMaterialCatalog.SAND,
		"bed": [TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.SAND, TerrainMaterialCatalog.GRAVEL],
	},
]

const DEFAULT_INDEX := 5

## Derived at class load from `BIOMES`, for the same reason the material catalog
## derives its lookups: the fast path and the readable record must be one source.
static var IDS: Array[StringName] = []
static var INDEX_BY_ID: Dictionary = {}
static var BIOME_COUNT := 0
## Indices whose climate envelope is a real rectangle, in table order — the only
## candidates `classify_climate` may return.
static var CLIMATE_INDICES := PackedInt32Array()


static func _static_init() -> void:
	for entry: Dictionary in BIOMES:
		var id: StringName = entry["id"]
		IDS.append(id)
		INDEX_BY_ID[id] = int(entry["index"])
		if entry["climate"] != null:
			CLIMATE_INDICES.append(int(entry["index"]))
	BIOME_COUNT = IDS.size()


static func count() -> int:
	return IDS.size()


static func is_valid_index(biome_index: int) -> bool:
	return biome_index >= 0 and biome_index < IDS.size()


static func index_of(biome_id: StringName) -> int:
	return int(INDEX_BY_ID.get(biome_id, -1))


static func id_of_index(biome_index: int) -> StringName:
	if not is_valid_index(biome_index):
		return IDS[DEFAULT_INDEX]
	return IDS[biome_index]


static func entry_of_index(biome_index: int) -> Dictionary:
	if not is_valid_index(biome_index):
		return BIOMES[DEFAULT_INDEX]
	return BIOMES[biome_index]


## The biome whose climate envelope is closest to this (temperature, moisture).
## Zero distance means the point is inside the rectangle; everything else lands on
## the nearest edge, which is why the table may leave gaps between biomes without
## leaving cells unclassified.
static func classify_climate(temperature: float, moisture: float) -> int:
	var best := DEFAULT_INDEX
	var best_distance := INF
	var best_priority := -1
	for biome_index: int in CLIMATE_INDICES:
		var envelope: Dictionary = BIOMES[biome_index]["climate"]
		var temperature_range: Array = envelope["temperature"]
		var moisture_range: Array = envelope["moisture"]
		var temperature_gap := _gap(temperature, float(temperature_range[0]), float(temperature_range[1]))
		var moisture_gap := _gap(moisture, float(moisture_range[0]), float(moisture_range[1]))
		var distance := (
			(temperature_gap / TEMPERATURE_SPAN) * (temperature_gap / TEMPERATURE_SPAN)
			+ moisture_gap * moisture_gap
		)
		var priority := int(BIOMES[biome_index].get("priority", 0))
		if distance < best_distance - 0.000001 or (
			absf(distance - best_distance) <= 0.000001 and priority > best_priority
		):
			best_distance = distance
			best_priority = priority
			best = biome_index
	return best


## The surface palette of a biome as parallel arrays of material id and cumulative
## weight in 0…1. Cumulative on purpose: the painter resolves a palette with one
## noise sample per column and a linear scan, and normalising on every one of
## 16 384 columns would be the slowest part of the stage.
static func palette_of_index(biome_index: int) -> Array:
	var ground: Dictionary = entry_of_index(biome_index)["ground"]
	var ids: Array[StringName] = []
	var thresholds := PackedFloat32Array()
	var total := 0.0
	for id: StringName in ground:
		total += float(ground[id])
	var running := 0.0
	for id: StringName in ground:
		running += float(ground[id])
		ids.append(id)
		thresholds.append(running / maxf(total, 0.0001))
	return [ids, thresholds]


static func beach_material_of_index(biome_index: int) -> StringName:
	return entry_of_index(biome_index)["beach"]


## Bed material under water: `depth_steps` decides shallow from deep, and a river
## channel asks for the third entry regardless of its depth.
static func bed_material_of_index(biome_index: int, depth_steps: int, channel: bool, shallow_limit: int) -> StringName:
	var bed: Array = entry_of_index(biome_index)["bed"]
	if channel:
		return bed[2]
	return bed[0] if depth_steps <= shallow_limit else bed[1]


static func _gap(value: float, low: float, high: float) -> float:
	if value < low:
		return low - value
	if value > high:
		return value - high
	return 0.0
