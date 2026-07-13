class_name WorldSnapshot
extends RefCounted

## A coherent view of the simulation. Goals never query live scene state while
## scoring, so every citizen in a think cycle reasons from the same facts.

var sequence: int
var simulation_seconds: float
var game_minutes: float
var settlement: AIFactSet
var _citizens: Dictionary


func _init(
	next_sequence: int = 0,
	next_simulation_seconds: float = 0.0,
	next_game_minutes: float = 0.0,
	next_settlement: AIFactSet = null,
	next_citizens: Dictionary = {}
) -> void:
	sequence = next_sequence
	simulation_seconds = next_simulation_seconds
	game_minutes = next_game_minutes
	settlement = next_settlement if next_settlement != null else AIFactSet.new()
	_citizens = next_citizens.duplicate()


func citizen(citizen_id: int) -> CitizenSnapshot:
	return _citizens.get(citizen_id) as CitizenSnapshot


func has_citizen(citizen_id: int) -> bool:
	return _citizens.has(citizen_id)


func citizen_ids() -> Array[int]:
	var result: Array[int] = []
	for citizen_id: int in _citizens:
		result.append(citizen_id)
	return result


func citizen_count() -> int:
	return _citizens.size()
