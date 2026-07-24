class_name TravelerProfile
extends RefCounted

## Value-style mobility contract for a route request. Treat instances as immutable
## after construction and register a replacement rather than mutating one in use.
##
## A profile describes *how* an actor moves; it never selects a graph or owns
## movement.  Solvers select a graph from layer_mask, while coverage and future
## indoor/road adapters consult the physical constraints below.  Keep concrete
## IDs stable for saves, and use mobility_category only for content grouping.

const LAYER_TERRAIN := 1 << 0  # 1
const LAYER_ROAD    := 1 << 1  # 2
const LAYER_INDOOR  := 1 << 2  # 4
const LAYER_AIR     := 1 << 3  # 8

const CATEGORY_PEDESTRIAN: StringName = &"pedestrian"
const CATEGORY_SMALL_WHEELED: StringName = &"small_wheeled"
const CATEGORY_ROAD_VEHICLE: StringName = &"road_vehicle"
const CATEGORY_HEAVY_OFFROAD: StringName = &"heavy_offroad"
const CATEGORY_AIR: StringName = &"air"

const PEDESTRIAN: StringName = &"pedestrian"
const BIPEDAL_ROBOT: StringName = &"bipedal_robot"
const WHEELED_ROBOT: StringName = &"wheeled_robot"
const LIGHT_VEHICLE: StringName = &"light_vehicle"
const HEAVY_VEHICLE: StringName = &"heavy_vehicle"
const AIR_DRONE: StringName = &"air_drone"

var profile_id: StringName = &"pedestrian"
var mobility_category: StringName = CATEGORY_PEDESTRIAN
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
	p_layers: int = LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR,
	p_category: StringName = CATEGORY_PEDESTRIAN
) -> void:
	profile_id = p_id
	mobility_category = p_category
	max_slope = p_slope
	width_clearance = p_width
	height_clearance = p_height
	allows_stairs = p_stairs
	allows_offroad = p_offroad
	min_turn_radius = p_turn_radius
	layer_mask = p_layers


static func pedestrian() -> TravelerProfile:
	return TravelerProfile.new(PEDESTRIAN, 45.0, 0.6, 2.0, true, true, 0.0, LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR, CATEGORY_PEDESTRIAN)


static func bipedal_robot() -> TravelerProfile:
	return TravelerProfile.new(BIPEDAL_ROBOT, 40.0, 0.7, 2.0, true, true, 0.0, LAYER_TERRAIN | LAYER_ROAD | LAYER_INDOOR, CATEGORY_PEDESTRIAN)


static func wheeled_robot() -> TravelerProfile:
	return TravelerProfile.new(WHEELED_ROBOT, 15.0, 0.8, 1.2, false, false, 0.5, LAYER_ROAD | LAYER_INDOOR, CATEGORY_SMALL_WHEELED)


static func light_vehicle() -> TravelerProfile:
	return TravelerProfile.new(LIGHT_VEHICLE, 20.0, 1.2, 1.8, false, false, 2.0, LAYER_ROAD, CATEGORY_ROAD_VEHICLE)


static func heavy_vehicle() -> TravelerProfile:
	return TravelerProfile.new(HEAVY_VEHICLE, 25.0, 2.5, 3.0, false, false, 5.0, LAYER_ROAD | LAYER_TERRAIN, CATEGORY_HEAVY_OFFROAD)


static func air_drone() -> TravelerProfile:
	return TravelerProfile.new(AIR_DRONE, 90.0, 0.5, 0.5, false, true, 0.0, LAYER_AIR, CATEGORY_AIR)


static func get_profile(p_id: StringName) -> TravelerProfile:
	if _registry.is_empty():
		_init_defaults()
	if _registry.has(p_id):
		return _registry[p_id]
	# Unknown profiles fail closed: content must register its capabilities before
	# it can receive a route.  Treating an unknown vehicle as a pedestrian would
	# make future mobility restrictions silently unsafe.
	return TravelerProfile.new(p_id, 0.0, 0.0, 0.0, false, false, 0.0, 0, StringName())


static func register_profile(profile: TravelerProfile) -> void:
	if profile != null:
		_registry[profile.profile_id] = profile


static func is_registered(profile_id_to_check: StringName) -> bool:
	if _registry.is_empty():
		_init_defaults()
	return _registry.has(profile_id_to_check)


static func _init_defaults() -> void:
	register_profile(pedestrian())
	register_profile(bipedal_robot())
	register_profile(wheeled_robot())
	register_profile(light_vehicle())
	register_profile(heavy_vehicle())
	register_profile(air_drone())
	# Existing saves and current grid callers still use these IDs. They remain
	# concrete compatibility profiles until coverage moves to capability tags.
	register_profile(TravelerProfile.new(&"cart", 12.0, 0.9, 1.2, false, true, 0.4, LAYER_TERRAIN | LAYER_ROAD, CATEGORY_SMALL_WHEELED))
	register_profile(TravelerProfile.new(&"bicycle", 18.0, 0.7, 1.5, false, true, 0.8, LAYER_TERRAIN | LAYER_ROAD, CATEGORY_SMALL_WHEELED))
	register_profile(TravelerProfile.new(&"motor", 20.0, 1.0, 1.7, false, true, 1.5, LAYER_TERRAIN | LAYER_ROAD, CATEGORY_ROAD_VEHICLE))
