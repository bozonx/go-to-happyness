class_name ResourcePile
extends RefCounted

## Mutable runtime state for one ground pile of resources. Created when
## resources are dropped on the ground; lives until all contents are consumed
## or decayed.

var node: Object = null
var resources: Dictionary = {}
var reserved: Dictionary = {}
var is_backpack: bool = false


func _init(next_node: Object = null, next_resources: Dictionary = {}, next_is_backpack: bool = false) -> void:
	node = next_node
	resources = next_resources
	is_backpack = next_is_backpack
