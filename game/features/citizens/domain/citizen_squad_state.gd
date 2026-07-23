class_name CitizenSquadState
extends RefCounted

## Deterministic squad state for a citizen or group of citizens.
## Stores squad membership, leader identity, and squad management rules.

var squad_id: StringName = &""
var squad_leader_id: int = -1
var is_hero_squad: bool = false


func is_in_squad() -> bool:
	return not squad_id.is_empty() and squad_leader_id > 0


func is_leader(my_ai_id: int) -> bool:
	return is_in_squad() and squad_leader_id == my_ai_id
