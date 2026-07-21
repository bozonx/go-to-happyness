class_name SchoolService
extends RefCounted

## Manages school state, developed professions status, and teacher presence checks.

var simulation: Node

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


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func is_teacher_present() -> bool:
	if simulation.school_positions.is_empty():
		return false
	var school_pos: Vector3 = simulation.school_positions[0]
	for citizen in simulation.citizens:
		if citizen.specialization == "teacher":
			if citizen.is_player_controlled:
				if citizen.global_position.distance_to(school_pos) <= 3.5:
					return true
			elif citizen.state == Citizen.State.SCHOOL_WORK:
				if citizen.global_position.distance_to(school_pos) <= 3.5:
					return true
	return false


func is_profession_developed(profession: String) -> bool:
	return bool(developed_professions.get(profession, false))


func develop_profession(profession: String) -> void:
	if developed_professions.has(profession):
		developed_professions[profession] = true
