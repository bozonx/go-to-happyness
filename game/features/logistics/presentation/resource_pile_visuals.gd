class_name ResourcePileVisuals
extends RefCounted

## Presentation-only helper for resource pile visuals: scene instantiation,
## mesh visibility, and label formatting. No domain or state logic.

const ResourcePileScene = preload("res://game/features/logistics/presentation/resource_pile.tscn")


func create_visual(position: Vector3, resources: Dictionary, is_backpack_pile: bool) -> Node3D:
	var pile: Node3D = ResourcePileScene.instantiate()
	pile.position = position

	var label := pile.get_node("PileLabel") as Label3D
	label.text = _format_label_text(resources)
	label.position.y = 0.8 if is_backpack_pile else 1.7

	var backpack_mesh := pile.get_node("BackpackMesh") as MeshInstance3D
	var base_mesh_node := pile.get_node("BaseMesh") as MeshInstance3D
	var log1 := pile.get_node("Log1") as MeshInstance3D
	var log2 := pile.get_node("Log2") as MeshInstance3D
	var grass_pile := pile.get_node("GrassPile") as MeshInstance3D
	var stone_pile := pile.get_node("StonePile") as MeshInstance3D

	if is_backpack_pile:
		backpack_mesh.visible = true
		base_mesh_node.visible = false
	else:
		var has_wood := resources.has("branches") or resources.has("wood") or resources.has("logs")
		log1.visible = has_wood
		log2.visible = has_wood
		grass_pile.visible = resources.has("grass")
		stone_pile.visible = resources.has("stone") or resources.has("soil") or resources.has("clay") or resources.has("bricks")

	return pile


func refresh_label(pile_node: Node3D, resources: Dictionary) -> void:
	if not is_instance_valid(pile_node):
		return
	var label := pile_node.get_node_or_null("PileLabel") as Label3D
	if label == null:
		return
	label.text = _format_label_text(resources)


func _format_label_text(resources: Dictionary) -> String:
	var labels: Array[String] = []
	for resource_type in resources:
		var amount := int(resources[resource_type])
		if amount > 0:
			labels.append("%s x%d" % [str(resource_type).to_upper(), amount])
	labels.sort()
	return "\n".join(labels)
