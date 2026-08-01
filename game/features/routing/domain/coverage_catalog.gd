class_name CoverageCatalog
extends RefCounted

## Built coverage, as records rather than branches of code
## (design_docs/engine/navigation_and_roads.md, «Каталог покрытий вместо веток
## кода»; map_editor.md §5.2.2).
##
## A surface an author or a settlement lays over the ground — a park path, a
## pavement, a stone road, an alien deck — is one entry here. Nothing about it is
## expressed as GDScript: the previous shape of this knowledge, `RoadType`, was a
## static `match` over weights, eras and profile lists, which meant a pack with no
## code could not add a surface at all.
##
## It lives in `routing/domain` and not beside the map layer because this is the
## traversal contract: `RoadNetworkService` publishes these weights into `NavGrid`
## and must read them without depending on the world feature. What the surface
## LOOKS like is not here for the same reason — `CoverageLibrary` in
## `world/presentation/terrain` owns that, exactly as `TerrainMaterialLibrary`
## owns the look of a material the domain catalog only names.
##
## **The index is the saved form.** `surface.bin` stores one byte per cell, and
## that byte is the position in this list. Entries are therefore APPEND-ONLY after
## the first release; renumbering one would move every road on every saved map.
## Index 0 is "no coverage" and is not an entry.

const NONE_INDEX := 0
const NONE_ID: StringName = &""

## Ids are `<namespace>:<name>` so a pack-supplied surface can never collide with
## a shipped one.
const DIRT: StringName = &"core:dirt"
const CLAY: StringName = &"core:clay"
const WOOD: StringName = &"core:wood"
const STONE: StringName = &"core:stone"
const ASPHALT: StringName = &"core:asphalt"
## The organic one: it is created by traffic rather than built, but it is the same
## kind of thing — a surface over the ground with its own weight — and an author
## needs to be able to paint an already-worn village (map_editor.md §5.2.2).
const TRAIL: StringName = &"core:trail"

## Flags of an entry. `ORGANIC` marks coverage that traffic maintains and neglect
## removes; `NO_WEAR` and `NO_REGROWTH` are the two properties an alien or
## engineered deck needs in order not to behave like packed earth.
const FLAG_ORGANIC := 1 << 0
const FLAG_NO_WEAR := 1 << 1
const FLAG_NO_REGROWTH := 1 << 2

## Era gate for building it in a settlement. Matches `SettlementState.Era`
## numerically without coupling this deterministic record to settlement state —
## the same compromise `RoadType.minimum_era` already made.
const ERA_TENT := 0
const ERA_EARTH := 1
const ERA_CLAY := 2
const ERA_WOOD := 3
const ERA_STONE := 4
const ERA_BRICK := 5

## Field keys of one record. A record is a Dictionary and not a class so that a
## pack manifest can supply one verbatim once content loading reaches here.
const FIELD_ID := "id"
const FIELD_TITLE := "title"
const FIELD_WEIGHT := "weight"
const FIELD_PROFILES := "profiles"
const FIELD_MIN_ERA := "min_era"
const FIELD_FLAGS := "flags"

## Legacy profile names kept from `RoadType` until vehicles get real profile
## records of their own (`navigation_and_roads.md`, «Дороги и транспорт»).
const CART: StringName = &"cart"
const BICYCLE: StringName = &"bicycle"
const MOTOR: StringName = &"motor"

## The shipped entries, in index order. Weights come from the coverage table of
## `navigation_and_roads.md`; grass is 2.0, so 1.0 is a road at full walking
## speed. Profile lists are written out per entry rather than composed from
## shared constants: a constant expression cannot concatenate arrays, and a lazily
## built list would make the saved index depend on when the class first loaded.
const ENTRIES: Array[Dictionary] = [
	{
		FIELD_ID: TRAIL, FIELD_TITLE: "тропинка", FIELD_WEIGHT: 1.4,
		FIELD_PROFILES: [TravelerProfile.PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT],
		FIELD_MIN_ERA: ERA_TENT, FIELD_FLAGS: FLAG_ORGANIC,
	},
	{
		FIELD_ID: DIRT, FIELD_TITLE: "грунтовая", FIELD_WEIGHT: 1.0,
		FIELD_PROFILES: [
			TravelerProfile.PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT,
			CART, BICYCLE, TravelerProfile.WHEELED_ROBOT,
		],
		FIELD_MIN_ERA: ERA_EARTH, FIELD_FLAGS: 0,
	},
	{
		FIELD_ID: CLAY, FIELD_TITLE: "глинобитная", FIELD_WEIGHT: 0.9,
		FIELD_PROFILES: [
			TravelerProfile.PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT,
			BICYCLE, TravelerProfile.WHEELED_ROBOT,
		],
		FIELD_MIN_ERA: ERA_CLAY, FIELD_FLAGS: 0,
	},
	{
		FIELD_ID: WOOD, FIELD_TITLE: "деревянная", FIELD_WEIGHT: 0.85,
		FIELD_PROFILES: [
			TravelerProfile.PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT,
			BICYCLE, MOTOR, TravelerProfile.WHEELED_ROBOT,
		],
		FIELD_MIN_ERA: ERA_WOOD, FIELD_FLAGS: FLAG_NO_REGROWTH,
	},
	{
		FIELD_ID: STONE, FIELD_TITLE: "каменная", FIELD_WEIGHT: 0.8,
		FIELD_PROFILES: [
			TravelerProfile.PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT,
			CART, BICYCLE, MOTOR,
			TravelerProfile.WHEELED_ROBOT, TravelerProfile.LIGHT_VEHICLE, TravelerProfile.HEAVY_VEHICLE,
		],
		FIELD_MIN_ERA: ERA_STONE, FIELD_FLAGS: FLAG_NO_WEAR | FLAG_NO_REGROWTH,
	},
	{
		FIELD_ID: ASPHALT, FIELD_TITLE: "асфальтовая", FIELD_WEIGHT: 0.7,
		FIELD_PROFILES: [
			TravelerProfile.PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT,
			CART, BICYCLE, MOTOR,
			TravelerProfile.WHEELED_ROBOT, TravelerProfile.LIGHT_VEHICLE, TravelerProfile.HEAVY_VEHICLE,
		],
		FIELD_MIN_ERA: ERA_BRICK, FIELD_FLAGS: FLAG_NO_REGROWTH,
	},
]

## Compatibility aliases for save files written while coverage was `RoadType`
## (`dirt`, `stone`, …). New content never writes an unqualified id.
const LEGACY_IDS: Dictionary = {
	&"dirt": DIRT,
	&"clay": CLAY,
	&"wood": WOOD,
	&"stone": STONE,
	&"asphalt": ASPHALT,
	&"trail": TRAIL,
}

## Registered pack entries, appended after the shipped ones. Kept as a separate
## list so a reload of installed content cannot renumber `ENTRIES`.
static var _extra: Array[Dictionary] = []
static var _index_by_id: Dictionary = {}


static func count() -> int:
	return ENTRIES.size() + _extra.size() + 1


## The record at a saved index, or an empty Dictionary for "no coverage" and for
## an index this build does not have — a map that used a pack surface still opens,
## it just draws and prices those cells as bare ground.
static func entry_of_index(index: int) -> Dictionary:
	if index <= NONE_INDEX:
		return {}
	var position := index - 1
	if position < ENTRIES.size():
		return ENTRIES[position]
	position -= ENTRIES.size()
	return _extra[position] if position < _extra.size() else {}


static func is_known_index(index: int) -> bool:
	return not entry_of_index(index).is_empty()


static func id_of_index(index: int) -> StringName:
	var entry := entry_of_index(index)
	return entry.get(FIELD_ID, NONE_ID) if not entry.is_empty() else NONE_ID


static func title_of_index(index: int) -> String:
	var entry := entry_of_index(index)
	return String(entry.get(FIELD_TITLE, "нет покрытия")) if not entry.is_empty() else "нет покрытия"


static func index_of_id(id: StringName) -> int:
	if id == NONE_ID:
		return NONE_INDEX
	var resolved: StringName = LEGACY_IDS.get(id, id)
	_ensure_lookup()
	return int(_index_by_id.get(resolved, NONE_INDEX))


static func is_known_id(id: StringName) -> bool:
	return index_of_id(id) != NONE_INDEX


## Traversal weight published into `NavGrid`. "No coverage" has none: the cell is
## priced by its terrain material, which is a different layer and not this one's
## business (`nav_grid._surface_weight`).
static func weight_of_index(index: int) -> float:
	var entry := entry_of_index(index)
	return float(entry.get(FIELD_WEIGHT, 0.0)) if not entry.is_empty() else 0.0


static func weight_of_id(id: StringName) -> float:
	return weight_of_index(index_of_id(id))


## Whether a traveller may use the surface at all. A profile that is not listed is
## refused rather than slowed: pedestrian-only coverage is not a narrow road for a
## lorry, and letting a vehicle price it would put it there.
static func supports_profile_index(index: int, profile: StringName) -> bool:
	var entry := entry_of_index(index)
	if entry.is_empty():
		return false
	var profiles: Array = entry.get(FIELD_PROFILES, [])
	return profiles.has(profile)


static func supports_profile(id: StringName, profile: StringName) -> bool:
	return supports_profile_index(index_of_id(id), profile)


static func minimum_era_of_index(index: int) -> int:
	var entry := entry_of_index(index)
	return int(entry.get(FIELD_MIN_ERA, ERA_TENT)) if not entry.is_empty() else ERA_TENT


static func minimum_era(id: StringName) -> int:
	var index := index_of_id(id)
	return minimum_era_of_index(index) if index != NONE_INDEX else 999


static func flags_of_index(index: int) -> int:
	var entry := entry_of_index(index)
	return int(entry.get(FIELD_FLAGS, 0)) if not entry.is_empty() else 0


## Organic coverage is maintained by traffic and lost to neglect. It is the only
## kind an author paints knowing the simulation may take it away again.
static func is_organic_index(index: int) -> bool:
	return (flags_of_index(index) & FLAG_ORGANIC) != 0


static func supports_wear_index(index: int) -> bool:
	return not entry_of_index(index).is_empty() and (flags_of_index(index) & FLAG_NO_WEAR) == 0


## Indices in catalog order, "no coverage" excluded. The palette and the tests
## iterate this rather than a hardcoded range.
static func indices() -> Array[int]:
	var result: Array[int] = []
	for position in ENTRIES.size() + _extra.size():
		result.append(position + 1)
	return result


## Registers a pack-supplied surface. Appends, never inserts: the index is the
## saved form, and a pack that loaded in a different order on the next launch
## would otherwise repaint the map.
static func register(entry: Dictionary) -> int:
	var id := StringName(str(entry.get(FIELD_ID, "")))
	if id == NONE_ID or is_known_id(id):
		return NONE_INDEX
	var record := entry.duplicate(true)
	record[FIELD_ID] = id
	_extra.append(record)
	_index_by_id.clear()
	return ENTRIES.size() + _extra.size()


## Test and content-reload seam. Shipped entries are not touched.
static func clear_registered() -> void:
	_extra.clear()
	_index_by_id.clear()


static func _ensure_lookup() -> void:
	if not _index_by_id.is_empty():
		return
	for position in ENTRIES.size():
		_index_by_id[ENTRIES[position][FIELD_ID]] = position + 1
	for position in _extra.size():
		_index_by_id[_extra[position][FIELD_ID]] = ENTRIES.size() + position + 1
