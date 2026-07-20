class_name ResourcePileService
extends RefCounted

const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const ResourcePileScene = preload("res://game/features/logistics/presentation/resource_pile.tscn")

var parent_node: Node3D
var resource_piles: Array[Dictionary]
var settlement: RefCounted
var weather_state: RefCounted

func _init(parent: Node3D = null, piles: Array[Dictionary] = [], settlement_ref: RefCounted = null, weather_ref: RefCounted = null) -> void:
	parent_node = parent
	resource_piles = piles
	settlement = settlement_ref
	weather_state = weather_ref

func setup(parent: Node3D, piles: Array[Dictionary], settlement_ref: RefCounted, weather_ref: RefCounted) -> void:
	parent_node = parent
	resource_piles = piles
	settlement = settlement_ref
	weather_state = weather_ref

func create_resource_pile(position: Vector3, resources: Dictionary, is_backpack_pile := false) -> Node3D:
	if resources.is_empty():
		return null
	var normalized: Dictionary = {}
	for resource_type in resources:
		var amount := int(resources[resource_type])
		if amount > 0:
			normalized[str(resource_type)] = amount
	if normalized.is_empty():
		return null

	var pile: Node3D = ResourcePileScene.instantiate()
	pile.position = position

	var label := pile.get_node("PileLabel") as Label3D
	var labels: Array[String] = []
	for resource_type in normalized:
		labels.append("%s x%d" % [str(resource_type).to_upper(), int(normalized[resource_type])])
	labels.sort()
	label.text = "\n".join(labels)
	label.position.y = 1.7

	var backpack_mesh := pile.get_node("BackpackMesh") as MeshInstance3D
	var base_mesh_node := pile.get_node("BaseMesh") as MeshInstance3D
	var log1 := pile.get_node("Log1") as MeshInstance3D
	var log2 := pile.get_node("Log2") as MeshInstance3D
	var grass_pile := pile.get_node("GrassPile") as MeshInstance3D
	var stone_pile := pile.get_node("StonePile") as MeshInstance3D

	if is_backpack_pile:
		backpack_mesh.visible = true
		base_mesh_node.visible = false
		label.position.y = 0.8
	else:
		var has_wood := normalized.has("branches") or normalized.has("wood") or normalized.has("logs")
		log1.visible = has_wood
		log2.visible = has_wood
		grass_pile.visible = normalized.has("grass")
		stone_pile.visible = normalized.has("stone") or normalized.has("soil") or normalized.has("clay") or normalized.has("bricks")

	if parent_node != null:
		parent_node.add_child(pile)
	resource_piles.append({"node": pile, "resources": normalized, "reserved": {}, "is_backpack": is_backpack_pile})
	return pile

func remove_backpack_pile(backpack_node: Node3D) -> Node3D:
	if not is_instance_valid(backpack_node):
		return null
	for index in range(resource_piles.size()):
		if resource_piles[index].get("node") == backpack_node:
			resource_piles.remove_at(index)
			break
	backpack_node.queue_free()
	return null

func sync_backpack_pile(backpack_node: Node3D) -> Node3D:
	if not is_instance_valid(backpack_node):
		return backpack_node
	if settlement != null and settlement.warehouse_ever_built:
		return backpack_node
	for index in range(resource_piles.size()):
		var pile: Dictionary = resource_piles[index]
		if pile.get("node") != backpack_node:
			continue
		var synced: Dictionary = {}
		if settlement != null and settlement.backpack != null:
			for resource_type in settlement.backpack:
				var amount := int(settlement.backpack[resource_type])
				if amount > 0:
					synced[str(resource_type)] = amount
		if synced.is_empty():
			resource_piles.remove_at(index)
			backpack_node.queue_free()
			return null
		else:
			pile["resources"] = synced
			resource_piles[index] = pile
			refresh_resource_pile_label(pile)
		break
	return backpack_node

func convert_backpack_pile_to_regular(backpack_node: Node3D) -> Node3D:
	if not is_instance_valid(backpack_node):
		return null
	for index in range(resource_piles.size()):
		var pile: Dictionary = resource_piles[index]
		if pile.get("node") == backpack_node:
			var synced: Dictionary = {}
			if settlement != null and settlement.backpack != null:
				for resource_type in settlement.backpack:
					var amount := int(settlement.backpack[resource_type])
					if amount > 0:
						synced[resource_type] = amount
			if not synced.is_empty():
				pile["resources"] = synced
			pile["is_backpack"] = false
			resource_piles[index] = pile
			refresh_resource_pile_label(pile)
			break
	return null

func drop_overflow_as_piles(overflow: Dictionary, base_position: Vector3) -> void:
	if overflow.is_empty():
		return
	var pile_resources := {}
	var pile_index := 0
	const PILE_SPREAD := 1.2
	for resource_type in overflow:
		pile_resources[resource_type] = int(overflow[resource_type])
		if pile_resources.size() >= 3:
			var offset := Vector3((pile_index % 3) * PILE_SPREAD - PILE_SPREAD, 0.0, (pile_index / 3) * PILE_SPREAD - PILE_SPREAD)
			create_resource_pile(base_position + offset, pile_resources)
			pile_resources = {}
			pile_index += 1
	if not pile_resources.is_empty():
		var offset := Vector3((pile_index % 3) * PILE_SPREAD - PILE_SPREAD, 0.0, (pile_index / 3) * PILE_SPREAD - PILE_SPREAD)
		create_resource_pile(base_position + offset, pile_resources)

func refresh_resource_pile_label(pile: Dictionary) -> void:
	var pile_node := pile.get("node") as Node3D
	if not is_instance_valid(pile_node):
		return
	var label := pile_node.get_node_or_null("PileLabel") as Label3D
	if label == null:
		return
	var labels: Array[String] = []
	for piled_resource in pile.resources:
		var amount := int(pile.resources[piled_resource])
		if amount > 0:
			labels.append("%s x%d" % [str(piled_resource).to_upper(), amount])
	labels.sort()
	label.text = "\n".join(labels)

func drop_resource_pile(position: Vector3, resource_type: String, amount: int) -> void:
	if resource_type.is_empty() or amount <= 0:
		return
	for index in resource_piles.size():
		var pile: Dictionary = resource_piles[index]
		var pile_node := pile.get("node") as Node3D
		if not is_instance_valid(pile_node) or pile.resources.size() != 1 or not pile.resources.has(resource_type) or pile_node.global_position.distance_squared_to(position) > 2.25:
			continue
		pile.resources[resource_type] = int(pile.resources.get(resource_type, 0)) + amount
		resource_piles[index] = pile
		var label := pile_node.get_node_or_null("PileLabel") as Label3D
		if label != null:
			var labels: Array[String] = []
			for piled_resource in pile.resources:
				labels.append("%s x%d" % [str(piled_resource).to_upper(), int(pile.resources[piled_resource])])
			labels.sort()
			label.text = "\n".join(labels)
		return
	create_resource_pile(position, {resource_type: amount})

func decay_resource_piles() -> void:
	var is_raining := false
	if weather_state != null and "is_raining" in weather_state:
		is_raining = bool(weather_state.is_raining)
	for index in range(resource_piles.size() - 1, -1, -1):
		var pile: Dictionary = resource_piles[index]
		if pile.get("is_backpack", false):
			continue
		for resource_type in pile.resources.keys():
			var remaining := int(pile.resources[resource_type])
			var daily_rate := TentEraSurvivalRulesScript.pile_decay_rate(str(resource_type), is_raining)
			if remaining > 0 and daily_rate > 0.0:
				pile.resources[resource_type] = maxi(0, remaining - maxi(1, ceili(remaining * daily_rate)))
		var empty := true
		for amount in pile.resources.values():
			if int(amount) > 0:
				empty = false
		if empty:
			if is_instance_valid(pile.node):
				pile.node.queue_free()
			resource_piles.remove_at(index)
		else:
			resource_piles[index] = pile
			refresh_resource_pile_label(pile)
