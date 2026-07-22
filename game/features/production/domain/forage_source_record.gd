class_name ForageSourceRecord
extends RefCounted

## Runtime state for one wild edible forage plant. One harvest each,
## respawns via forage_respawn_at schedule.

var node: Node3D = null


func _init(next_node: Node3D = null) -> void:
	node = next_node
