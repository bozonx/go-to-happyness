class_name RabbitSourceRecord
extends RefCounted

## Runtime state for one rabbit meadow animal that can be hunted.
##
## Where it walks is deliberately not here: `AmbientLifeService` owns every
## creature's heading. This record answers "is there still a rabbit at this cell",
## which is the only question hunting asks.

var node: Node3D = null


func _init(next_node: Node3D = null) -> void:
	node = next_node
