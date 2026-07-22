class_name FactoryService
extends RefCounted

## Handles factory production cycles, currently brick factory output.

const BRICK_FACTORY_TYPE := "brick_factory"
const BRICK_FACTORY_SKILL_THRESHOLD := 1.0
const BRICK_FACTORY_DOUBLE_CHANCE := 0.10
const BRICK_FACTORY_BASE_OUTPUT := 1
const BRICK_FACTORY_SKILLED_OUTPUT := 2
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _building_registry: BuildingRegistry
var _on_message: Callable = Callable()
var _random: RandomNumberGenerator


func configure(
	settlement: SettlementState,
	building_registry: BuildingRegistry,
	on_message: Callable,
	random: RandomNumberGenerator
) -> void:
	_settlement = settlement
	_building_registry = building_registry
	_on_message = on_message
	_random = random


func on_factory_cycle(worker: Citizen, factory: Node3D) -> void:
	if not is_instance_valid(factory):
		return
	var type: String = _building_registry.building_type_for_node(factory)
	if type == BRICK_FACTORY_TYPE:
		_produce_bricks(worker)


func _produce_bricks(worker: Citizen) -> void:
	if _settlement.amount(ResourceIds.CLAY) < 1:
		return
	_settlement.add(ResourceIds.CLAY, -1)
	var produced := BRICK_FACTORY_BASE_OUTPUT
	if float(worker.skills.get("factory_worker", 0.0)) >= BRICK_FACTORY_SKILL_THRESHOLD and _random.randf() < BRICK_FACTORY_DOUBLE_CHANCE:
		produced = BRICK_FACTORY_SKILLED_OUTPUT
		_emit_message("Industrialist: Brick factory produced 2 bricks from 1 clay!")
	else:
		_emit_message("Brick factory produced 1 brick.")
	_settlement.add(ResourceIds.BRICKS, produced)


func _emit_message(text: String) -> void:
	if _on_message.is_valid():
		_on_message.call(text)
