class_name SchoolService
extends RefCounted

## Manages school state, developed professions status, and teacher presence checks.

var _school_positions: Array[Vector3] = []
var _citizens: Array = []

var developed_professions: Dictionary = {
	"construction": false,
	"forestry": false,
	"farming": false,
	"excavation": false,
	"factory_worker": false,
	"engineer": false,
	"cook": false,
	"teacher": false,
	"seller": false
}


func configure(school_positions: Array[Vector3], citizens: Array) -> void:
	_school_positions = school_positions
	_citizens = citizens


func is_teacher_present() -> bool:
	if _school_positions.is_empty():
		return false
	var school_pos: Vector3 = _school_positions[0]
	for citizen in _citizens:
		if citizen.specialization == "teacher":
			if citizen.is_player_controlled:
				if citizen.global_position.distance_to(school_pos) <= 3.5:
					return true
			elif citizen.state == Citizen.State.SCHOOL_WORK:
				if citizen.global_position.distance_to(school_pos) <= 3.5:
					return true
	return false


func set_profession_developed(profession: String, developed: bool) -> void:
	if developed_professions.has(profession):
		developed_professions[profession] = developed
