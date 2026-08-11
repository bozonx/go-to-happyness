class_name ResourcePileService
extends RefCounted

const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")

var parent_node: Node3D
var resource_piles: Array[ResourcePileScript]
var settlement: RefCounted
## Reads the environment rather than holding a weather object: piles get wet from
## whatever is falling, and the answer to "is it falling" has one owner
## (`world_environment.md` §2).
var environment_getter: Callable
var _visuals: RefCounted = null
var _next_container_serial := 1

func set_visuals(visuals_ref: RefCounted) -> void:
	_visuals = visuals_ref


func _get_visuals() -> RefCounted:
	if _visuals == null:
		var script_cls: Script = load("res://game/features/logistics/presentation/resource_pile_visuals.gd") as Script
		_visuals = script_cls.new()
	return _visuals

func _init(parent: Node3D = null, piles: Array[ResourcePileScript] = [], settlement_ref: RefCounted = null, environment: Callable = Callable()) -> void:
	setup(parent, piles, settlement_ref, environment)

func setup(parent: Node3D, piles: Array[ResourcePileScript], settlement_ref: RefCounted, environment: Callable = Callable()) -> void:
	parent_node = parent
	resource_piles = piles
	settlement = settlement_ref
	environment_getter = environment

func create_resource_pile(
	position: Vector3,
	resources: Dictionary,
	is_party_stash := false,
	container_id: StringName = &"",
) -> Node3D:
	if resources.is_empty():
		return null
	var normalized: Dictionary = {}
	for resource_type in resources:
		var amount := int(resources[resource_type])
		if amount > 0:
			normalized[str(resource_type)] = amount
	if normalized.is_empty():
		return null

	var pile: Node3D = _get_visuals().create_visual(position, normalized, is_party_stash)
	var resolved_id := container_id
	if resolved_id.is_empty():
		resolved_id = _next_generated_container_id()

	if parent_node != null:
		parent_node.add_child(pile)
	resource_piles.append(ResourcePileScript.new(pile, normalized, is_party_stash, resolved_id))
	return pile


func _next_generated_container_id() -> StringName:
	while true:
		var candidate := StringName("pile_%d" % _next_container_serial)
		_next_container_serial += 1
		var occupied := false
		for pile: ResourcePileScript in resource_piles:
			if pile.container_id == candidate:
				occupied = true
				break
		if not occupied:
			return candidate
	return &""


func take_resource(pile: ResourcePile, resource_type: String, max_amount: int) -> int:
	if pile == null or max_amount <= 0 or resource_type.is_empty() or not is_instance_valid(pile.node):
		return 0
	var available := int(pile.resources.get(resource_type, 0))
	var taken := mini(max_amount, available)
	if taken <= 0:
		return 0
	pile.resources[resource_type] = available - taken
	if int(pile.resources[resource_type]) <= 0:
		pile.resources.erase(resource_type)
	var labels: Array[String] = []
	for piled_resource in pile.resources:
		labels.append("%s x%d" % [str(piled_resource).to_upper(), int(pile.resources[piled_resource])])
	labels.sort()
	var label := pile.node.get_node_or_null("PileLabel") as Label3D
	if label != null:
		label.text = "\n".join(labels)
	if pile.resources.is_empty():
		if pile.is_party_stash and settlement != null and settlement.has_method("unbind_starter_stash_inventory"):
			settlement.unbind_starter_stash_inventory(pile.container_id)
		resource_piles.erase(pile)
		pile.node.queue_free()
	return taken

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

func refresh_resource_pile_label(pile: ResourcePileScript) -> void:
	_get_visuals().refresh_label(pile.node, pile.resources)

func drop_resource_pile(position: Vector3, resource_type: String, amount: int) -> void:
	if resource_type.is_empty() or amount <= 0:
		return
	for index in resource_piles.size():
		var pile: ResourcePileScript = resource_piles[index]
		var pile_node := pile.node
		if not is_instance_valid(pile_node) or pile.resources.size() != 1 or not pile.resources.has(resource_type) or pile_node.global_position.distance_squared_to(position) > 2.25:
			continue
		pile.resources[resource_type] = int(pile.resources.get(resource_type, 0)) + amount
		_get_visuals().refresh_label(pile_node, pile.resources)
		return
	create_resource_pile(position, {resource_type: amount})

func decay_resource_piles() -> void:
	var is_raining := false
	if environment_getter.is_valid():
		var snapshot: EnvironmentSnapshot = environment_getter.call()
		is_raining = snapshot != null and snapshot.is_precipitating()
	for index in range(resource_piles.size() - 1, -1, -1):
		var pile: ResourcePileScript = resource_piles[index]
		if pile.is_party_stash:
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
			refresh_resource_pile_label(pile)
