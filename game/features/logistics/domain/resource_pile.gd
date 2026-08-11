class_name ResourcePile
extends RefCounted

## Mutable runtime state for one ground pile of resources. Created when
## resources are dropped on the ground; lives until all contents are consumed
## or decayed.

var node: Object = null
var resources: Dictionary = {}
var reserved: Dictionary = {}
## Stable session identity. Authored containers use their MapEntityRecord id;
## dropped piles receive a generated id which is persisted by the save section.
var container_id: StringName = &""
var is_party_stash: bool = false


func _init(
	next_node: Object = null,
	next_resources: Dictionary = {},
	next_is_party_stash: bool = false,
	next_container_id: StringName = &"",
) -> void:
	node = next_node
	resources = next_resources
	is_party_stash = next_is_party_stash
	container_id = next_container_id
