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

const PEDESTRIAN: StringName = &"pedestrian"
const CART: StringName = &"cart"
const BICYCLE: StringName = &"bicycle"
const MOTOR: StringName = &"motor"

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


## Era values intentionally match SettlementState.Era without coupling this
## deterministic routing record to settlement state.
static func minimum_era(type: StringName) -> int:
	match type:
		DIRT:
			return 1 # EARTH
		CLAY:
			return 2
		WOOD:
			return 3
		STONE:
			return 4
		ASPHALT, ASPHALT_CONCRETE:
			return 5 # BRICK / industrial precursor
		_:
			return 999


static func supports_profile(type: StringName, profile: StringName) -> bool:
	match type:
		DIRT:
			return profile in [PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT, CART, BICYCLE, TravelerProfile.WHEELED_ROBOT]
		CLAY:
			return profile in [PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT, BICYCLE, TravelerProfile.WHEELED_ROBOT]
		WOOD:
			return profile in [PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT, BICYCLE, MOTOR, TravelerProfile.WHEELED_ROBOT]
		STONE, ASPHALT, ASPHALT_CONCRETE:
			return profile in [
				PEDESTRIAN, TravelerProfile.BIPEDAL_ROBOT,
				CART, BICYCLE, MOTOR,
				TravelerProfile.WHEELED_ROBOT, TravelerProfile.LIGHT_VEHICLE, TravelerProfile.HEAVY_VEHICLE,
			]
		_:
			return false
