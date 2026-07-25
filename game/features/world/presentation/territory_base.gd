class_name TerritoryBase
extends Node3D

@export var biome_definition: BiomeDefinition
@onready var landscape_objects: Node3D = get_node_or_null("LandscapeObjects") as Node3D


## Owns visual nodes that are naturally part of this territory: trees, ponds,
## wild plants, animals and their ambience. Gameplay services keep the matching
## runtime records; this method only establishes scene ownership.
func add_landscape_object(node: Node) -> void:
	if node == null:
		return
	if landscape_objects != null:
		if node.get_parent() != null:
			node.reparent(landscape_objects, true)
		else:
			landscape_objects.add_child(node)
	else:
		add_child(node)
