class_name HouseLightRecord
extends RefCounted

## Runtime state for one house light: the OmniLight3D, the house it belongs to,
## and the random minute (0–24*60) when the light turns off at night.

var light: OmniLight3D = null
var house: Node3D = null
var off_minute: int = 0


func _init(
	next_light: OmniLight3D = null,
	next_house: Node3D = null,
	next_off_minute: int = 0,
) -> void:
	light = next_light
	house = next_house
	off_minute = next_off_minute
