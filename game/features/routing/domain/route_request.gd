class_name RouteRequest
extends RefCounted

var from: Vector3
var destination: Vector3
var traveler_profile: StringName = &"pedestrian"
var allow_destination_cell := false
var profile_override: TravelerProfile = null


func get_profile() -> TravelerProfile:
	if profile_override != null:
		return profile_override
	return TravelerProfile.get_profile(traveler_profile)

