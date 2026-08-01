class_name RoadType
extends RefCounted

## Compatibility aliases for the ids saved while coverage was a branch of code
## (`navigation_and_roads.md`, «Каталог покрытий вместо веток кода»).
##
## Everything this used to decide — weight, era gate, which profiles a surface
## admits — is now a record in `CoverageCatalog`, so a pack can add a surface
## without a line of GDScript. What is left here is a name for each shipped
## surface and thin forwarding, so callers that have not been moved over still
## read one source of truth.
##
## The constants point at the CANONICAL ids. The unqualified strings old saves
## carry (`dirt`, `stone`) are resolved by `CoverageCatalog.LEGACY_IDS`, which is
## where compatibility belongs — spelling them here as well would give a saved
## road two spellings that compare unequal.

const DIRT: StringName = CoverageCatalog.DIRT
const CLAY: StringName = CoverageCatalog.CLAY
const WOOD: StringName = CoverageCatalog.WOOD
const STONE: StringName = CoverageCatalog.STONE
const ASPHALT: StringName = CoverageCatalog.ASPHALT

const PEDESTRIAN: StringName = &"pedestrian"
const CART: StringName = CoverageCatalog.CART
const BICYCLE: StringName = CoverageCatalog.BICYCLE
const MOTOR: StringName = CoverageCatalog.MOTOR


static func traversal_weight(type: StringName) -> float:
	var index := CoverageCatalog.index_of_id(type)
	return CoverageCatalog.weight_of_index(index) if index != CoverageCatalog.NONE_INDEX else INF


static func is_known(type: StringName) -> bool:
	return CoverageCatalog.is_known_id(type)


static func minimum_era(type: StringName) -> int:
	return CoverageCatalog.minimum_era(type)


static func supports_profile(type: StringName, profile: StringName) -> bool:
	return CoverageCatalog.supports_profile(type, profile)
