class_name CitizenSnapshot
extends RefCounted

## Read-only-by-convention citizen data captured for one AI think cycle.

var id: int
var position: Vector3
var is_player_controlled: bool
var is_available: bool
var facts: AIFactSet


func _init(
	next_id: int = 0,
	next_position: Vector3 = Vector3.ZERO,
	next_player_controlled: bool = false,
	next_available: bool = true,
	next_facts: AIFactSet = null
) -> void:
	id = next_id
	position = next_position
	is_player_controlled = next_player_controlled
	is_available = next_available
	facts = next_facts if next_facts != null else AIFactSet.new()
