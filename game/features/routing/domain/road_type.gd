class_name RoadType
extends RefCounted

## Stable definitions for constructed coverage. The network stores the type,
## while NavGrid receives only its resolved traversal weight.

const DIRT: StringName = &"dirt"
const CLAY: StringName = &"clay"
const WOOD: StringName = &"wood"
const STONE: StringName = &"stone"
const ASPHALT: StringName = &"asphalt"
const ASPHALT_CONCRETE: StringName = &"asphalt_concrete"

static func traversal_weight(type: StringName) -> float:
	match type:
		DIRT:
			return 1.0
		CLAY:
			return 0.9
		WOOD:
			return 0.85
		STONE:
			return 0.8
		ASPHALT:
			return 0.7
		ASPHALT_CONCRETE:
			return 0.6
		_:
			return INF


static func is_known(type: StringName) -> bool:
	return is_finite(traversal_weight(type))
