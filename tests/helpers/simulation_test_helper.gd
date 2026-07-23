class_name SimulationTestHelper
extends RefCounted

## Shared helpers for SceneTree-based feature/smoke tests.
## Extracted from duplicated code across tests/features/ and tests/repro/.

const SettlementGameScene := preload("res://game/bootstrap/settlement_game.tscn")


static func create_simulation() -> Node:
	return SettlementGameScene.instantiate()


static func setup_simulation(tree: SceneTree) -> Node:
	var simulation := SettlementGameScene.instantiate()
	tree.root.add_child(simulation)
	await tree.process_frame
	await tree.physics_frame
	for _frame in range(10):
		await tree.physics_frame
	if not is_instance_valid(simulation.entrance_stone):
		var entrance := Node3D.new()
		entrance.position = simulation._cell_center(Vector2i(-22, 1))
		simulation.add_child(entrance)
		simulation.entrance_stone = entrance
	return simulation


static func cleanup_simulation(tree: SceneTree, simulation: Node) -> void:
	if is_instance_valid(simulation):
		tree.root.remove_child(simulation)
		simulation.free()


static func appoint_test_official(simulation: Node, citizen: Citizen) -> void:
	simulation.settlement.complete_research("official")
	if not is_instance_valid(simulation.campfire_node):
		var centre := Node3D.new()
		centre.set_meta("service_position", citizen.global_position)
		simulation.add_child(centre)
		simulation.campfire_node = centre
	citizen.global_position = simulation._employment_center_position()
	simulation._appoint_official(citizen, simulation.campfire_node)
