class_name TravelerProfile
extends RefCounted

## Represents mobility capabilities and constraints for an agent in the routing system.

const LAYER_TERRAIN := 1 << 0  # 1
const LAYER_ROAD    := 1 << 1  # 2
const LAYER_INDOOR  := 1 << 2  # 4
const LAYER_AIR     := 1 << 3  # 8

var profile_id: StringName = &"pedestrian"
var max_slope: float = 45.0
var width_clearance: float = 0.6
var height_clearance: float = 2.0
var allows_stairs: bool = true
var allows_offroad: bool = true
var min_turn_radius: float = 0.0
var layer_mask: int = LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR

static var _registry: Dictionary = {}


func _init(
	p_id: StringName = &"pedestrian",
	p_slope: float = 45.0,
	p_width: float = 0.6,
	p_height: float = 2.0,
	p_stairs: bool = true,
	p_offroad: bool = true,
	p_turn_radius: float = 0.0,
	p_layers: int = LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR
) -> void:
	profile_id = p_id
	max_slope = p_slope
	width_clearance = p_width
	height_clearance = p_height
	allows_stairs = p_stairs
	allows_offroad = p_offroad
	min_turn_radius = p_turn_radius
	layer_mask = p_layers


static func pedestrian() -> TravelerProfile:
	return TravelerProfile.new(&"pedestrian", 45.0, 0.6, 2.0, true, true, 0.0, LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR)


static func bipedal_robot() -> TravelerProfile:
	return TravelerProfile.new(&"bipedal_robot", 40.0, 0.7, 2.0, true, true, 0.0, LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR)


static func wheeled_robot() -> TravelerProfile:
	return TravelerProfile.new(&"wheeled_robot", 15.0, 0.8, 1.2, false, false, 0.5, LAYER_ROAD | LAYER_INDOOR)


static func light_vehicle() -> TravelerProfile:
	return TravelerProfile.new(&"light_vehicle", 20.0, 1.2, 1.8, false, false, 2.0, LAYER_ROAD)


static func heavy_vehicle() -> TravelerProfile:
	return TravelerProfile.new(&"heavy_vehicle", 25.0, 2.5, 3.0, false, false, 5.0, LAYER_ROAD | LAYER_TERRAIN)


static func air_drone() -> TravelerProfile:
	return TravelerProfile.new(&"air_drone", 90.0, 0.5, 0.5, false, true, 0.0, LAYER_AIR | LAYER_TERRAIN)


static func get_profile(p_id: StringName) -> TravelerProfile:
	if _registry.is_empty():
		_init_defaults()
	if _registry.has(p_id):
		return _registry[p_id]
	var fallback := TravelerProfile.new(p_id)
	_registry[p_id] = fallback
	return fallback


static func register_profile(profile: TravelerProfile) -> void:
	if profile != null:
		_registry[profile.profile_id] = profile


static func _init_defaults() -> void:
	register_profile(pedestrian())
	register_profile(bipedal_robot())
	register_profile(wheeled_robot())
	register_profile(light_vehicle())
	register_profile(heavy_vehicle())
	register_profile(air_drone())
