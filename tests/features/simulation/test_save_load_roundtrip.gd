extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")

## End-to-end save/load: mutate a live settlement, persist it through the real
## module-section path (SettlementGame.save_session_state -> SaveData envelope),
## then restore into a *fresh* game instance and assert the state came back. This
## exercises restore_from_save_data with the forest overlay, which the SaveData
## unit test cannot reach.

const SAVE_PATH := "user://saves/test_roundtrip.json"

func _init() -> void:
	# --- Instance A: mutate and save ---
	var sim_a := await SimHelper.setup_simulation(self)

	var felled_cell: Vector2i = sim_a.cell_from_position(sim_a.tree_positions[0])
	sim_a.fell_tree_at(sim_a.tree_positions[0])
	assert(sim_a.world_resource_state.tree_at(felled_cell).felled, "tree should be felled in A")

	var depleted_cell: Vector2i = sim_a.cell_from_position(sim_a.tree_positions[1])
	var depleted_tree: Variant = sim_a.world_resource_state.tree_at(depleted_cell)
	depleted_tree.initial_branches = 8
	depleted_tree.remaining_branches = 3
	depleted_tree.hand_branches = 2
	var grass_cell: Vector2i = sim_a.grass_sources.keys()[0]
	var grass_before: GrassSourceRecord = sim_a.grass_sources[grass_cell]
	grass_before.remaining = maxi(1, grass_before.initial - 1)
	var forage_cell: Vector2i = sim_a.forage_sources.keys()[0]
	var rabbit_cell: Vector2i = sim_a.rabbit_sources.keys()[0]
	var rabbit_before: RabbitSourceRecord = sim_a.rabbit_sources[rabbit_cell]
	rabbit_before.direction = Vector3(0.4, 0.0, -0.8)
	var rabbit_position := rabbit_before.node.global_position
	# Wild food no longer respawns, so harvesting a forage source in A must leave
	# it permanently gone — the save carries that absence, not a respawn timer.
	sim_a.forage_sources[forage_cell].node.queue_free()
	sim_a.forage_sources.erase(forage_cell)

	sim_a.settlement.money = 4321
	var citizen_count: int = sim_a.citizens.size()

	# Capture through the same hook the host coordinator calls, then wrap it in the
	# generic envelope and persist. This is the only settlement write path now.
	var contribution: Dictionary = sim_a.save_session_state()
	var envelope := SaveDataScript.new()
	envelope.game_header = {"pack": "core", "id": "settlement", "revision": ""}
	envelope.engine_state = {"clock": {}}
	envelope.module_states[contribution.get("module", "gth.settlement")] = contribution.get("state", {})
	assert(envelope.save_to_file(SAVE_PATH), "save_to_file should succeed")
	SimHelper.cleanup_simulation(self, sim_a)

	# --- Instance B: fresh world, then load ---
	var sim_b := await SimHelper.setup_simulation(self)

	# Sanity: a pristine forest has this cell standing before we load.
	assert(not sim_b.world_resource_state.tree_at(felled_cell).felled, "fresh tree must start standing")
	assert(sim_b.settlement.money != 4321, "fresh money should differ from saved value")

	var loaded := SaveDataScript.new()
	assert(loaded.load_from_file(SAVE_PATH), "load_from_file should succeed")
	assert(sim_b.restore_from_save_data(loaded), "restore_from_save_data should succeed")

	# Settlement + population restored.
	assert(sim_b.settlement.money == 4321, "money not restored")
	assert(sim_b.citizens.size() == citizen_count, "citizen count not restored")

	# Forest overlay restored onto the regenerated forest.
	assert(sim_b.world_resource_state.tree_at(felled_cell).felled, "felled tree not restored")
	var restored_tree: Variant = sim_b.world_resource_state.tree_at(depleted_cell)
	assert(restored_tree.remaining_branches == 3, "branch depletion not restored")
	assert(restored_tree.hand_branches == 2, "hand branches not restored")
	assert(sim_b.grass_sources.has(grass_cell), "grass source missing after restore")
	assert(sim_b.grass_sources[grass_cell].remaining == grass_before.remaining, "grass depletion not restored")
	# The harvested forage source stays gone after save/load: wild food does not
	# respawn, so the absence harvested in A is the state restored in B.
	assert(not sim_b.forage_sources.has(forage_cell), "harvested forage must not come back")
	assert(sim_b.rabbit_sources.has(rabbit_cell), "rabbit source missing after restore")
	assert(sim_b.rabbit_sources[rabbit_cell].node.global_position.distance_to(rabbit_position) < 0.01, "rabbit position not restored")
	var landscape_objects := sim_b.get_node("WorldTerritory/LandscapeObjects")
	assert(sim_b.resource_piles.any(func(pile): return bool(pile.node.get_meta("landscape_owned", false)) and pile.node.get_parent() == landscape_objects), "starter world loot must return to the terrain hierarchy")

	SimHelper.cleanup_simulation(self, sim_b)
	print("  => Save/Load Round-Trip Test PASSED!")
	quit(0)
