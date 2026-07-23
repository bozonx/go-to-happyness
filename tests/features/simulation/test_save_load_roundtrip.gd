extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")
const SaveGameServiceScript = preload("res://game/features/save_load/application/save_game_service.gd")

## End-to-end save/load: mutate a live settlement, persist it, then restore into
## a *fresh* game instance and assert the state came back. This exercises the
## real SaveGameService.save_game -> restore_from_save_data path (including the
## forest overlay), which the SaveData unit test cannot reach.

const SAVE_PATH := "user://saves/test_roundtrip.json"

func _init() -> void:
	# --- Instance A: mutate and save ---
	var sim_a := await SimHelper.setup_simulation(self)

	var felled_cell: Vector2i = sim_a._cell_from_position(sim_a.tree_positions[0])
	sim_a._fell_tree_at(sim_a.tree_positions[0])
	assert(bool(sim_a.tree_nodes[felled_cell].get_meta("felled", false)), "tree should be felled in A")

	var depleted_cell: Vector2i = sim_a._cell_from_position(sim_a.tree_positions[1])
	var depleted_tree: Node3D = sim_a.tree_nodes[depleted_cell]
	depleted_tree.set_meta("initial_branches", 8)
	depleted_tree.set_meta("remaining_branches", 3)
	depleted_tree.set_meta("hand_branches", 2)

	sim_a.settlement.money = 4321
	var citizen_count: int = sim_a.citizens.size()

	assert(SaveGameServiceScript.save_game(sim_a, SAVE_PATH), "save_game should succeed")
	SimHelper.cleanup_simulation(self, sim_a)

	# --- Instance B: fresh world, then load ---
	var sim_b := await SimHelper.setup_simulation(self)

	# Sanity: a pristine forest has this cell standing before we load.
	assert(not bool(sim_b.tree_nodes[felled_cell].get_meta("felled", false)), "fresh tree must start standing")
	assert(sim_b.settlement.money != 4321, "fresh money should differ from saved value")

	assert(SaveGameServiceScript.load_game(sim_b, SAVE_PATH), "load_game should succeed")

	# Settlement + population restored.
	assert(sim_b.settlement.money == 4321, "money not restored")
	assert(sim_b.citizens.size() == citizen_count, "citizen count not restored")

	# Forest overlay restored onto the regenerated forest.
	assert(bool(sim_b.tree_nodes[felled_cell].get_meta("felled", false)), "felled tree not restored")
	var restored_tree: Node3D = sim_b.tree_nodes[depleted_cell]
	assert(int(restored_tree.get_meta("remaining_branches", -1)) == 3, "branch depletion not restored")
	assert(int(restored_tree.get_meta("hand_branches", -1)) == 2, "hand branches not restored")
	var landscape_objects := sim_b.get_node("Terrain3dWorld/LandscapeObjects")
	assert(sim_b.resource_piles.any(func(pile): return bool(pile.node.get_meta("landscape_owned", false)) and pile.node.get_parent() == landscape_objects), "starter world loot must return to the terrain hierarchy")

	SimHelper.cleanup_simulation(self, sim_b)
	print("  => Save/Load Round-Trip Test PASSED!")
	quit(0)
