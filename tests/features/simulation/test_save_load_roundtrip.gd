extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")
const SaveDataScript = preload("res://game/features/save_load/domain/save_data.gd")

## End-to-end save/load: mutate a live settlement, persist it through the real
## module-section path (SaveGameService section -> versioned SaveData envelope),
## then restore into a *fresh* game instance and assert the state came back. This
## exercises the settlement section restore with the forest overlay, which the SaveData
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
	var grass_before: HarvestSourceRecord = sim_a.grass_sources[grass_cell]
	grass_before.remaining = maxi(1, grass_before.initial - 1)
	var forage_cell: Vector2i = sim_a.forage_sources.keys()[0]
	var rabbit_cell: Vector2i = sim_a.rabbit_sources.keys()[0]
	var rabbit_before: RabbitSourceRecord = sim_a.rabbit_sources[rabbit_cell]
	# Курс кролика намеренно не сохраняется: он меняется каждую секунду, и от
	# записанного мгновения через миг после загрузки не осталось бы ничего.
	# Восстанавливается место — оно и проверяется.
	var rabbit_position := rabbit_before.node.global_position
	# Wild food no longer respawns, so harvesting a forage source in A must leave
	# it permanently gone — the save carries that absence, not a respawn timer.
	sim_a.forage_sources[forage_cell].node.queue_free()
	sim_a.forage_sources.erase(forage_cell)

	sim_a.settlement.money = 4321
	var citizen_count: int = sim_a.citizens.size()

	# Capture through the same service the settlement module calls, then wrap it in
	# the generic envelope and persist. This is the only settlement write path now.
	var module := SettlementGameModule.new()
	var envelope := SaveDataScript.new()
	envelope.game_header = {"pack": "core", "id": "settlement", "revision": ""}
	envelope.engine_state = {"seed": 0}
	var captured_section := SaveGameService.capture_settlement_section(sim_a)
	var captured_settlement: Dictionary = captured_section.get("settlement", {})
	assert(not captured_settlement.has("backpack") and not captured_settlement.has("resources"),
		"new saves must not duplicate physical inventory in settlement aggregates")
	envelope.set_module_section(module.module_id(), module.section_version(), captured_section)
	assert(envelope.save_to_file(SAVE_PATH), "save_to_file should succeed")
	await SimHelper.cleanup_simulation(self, sim_a)

	# --- Instance B: fresh world, then load ---
	var sim_b := await SimHelper.setup_simulation(self)

	# Sanity: a pristine forest has this cell standing before we load.
	assert(not sim_b.world_resource_state.tree_at(felled_cell).felled, "fresh tree must start standing")
	assert(sim_b.settlement.money != 4321, "fresh money should differ from saved value")

	# Существо, которое сейв не восстанавливает: оно не лежит ни в одном из четырёх
	# словарей источников, как олень, кабан или волк. Восстановление обязано его не
	# трогать. Раньше оно снимало с учёта ВСЮ службу, а регистрировало обратно
	# только кроликов, и зверь навсегда замирал там, где его застала загрузка.
	var bystander := Node3D.new()
	bystander.position = Vector3(3.0, 0.0, 3.0)
	sim_b.add_child(bystander)
	sim_b.ambient_life_service.register(bystander, WanderHabit.preset(WanderHabit.HABIT_GRAZING))
	var registered_before: int = sim_b.ambient_life_service.count()

	var loaded := SaveDataScript.new()
	assert(loaded.load_from_file(SAVE_PATH), "load_from_file should succeed")
	assert(SettlementSaveLoader.new().restore(sim_b, loaded.module_section(module.module_id())),
		"restoring the gth.settlement section should succeed")

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
	# Восстановленный кролик снова бродит: без постановки на учёт он выглядит
	# точно так же, как правильно загруженный, и молча стоит до конца партии.
	assert(sim_b.ambient_life_service.heading_of(sim_b.rabbit_sources[rabbit_cell].node) != Vector3.ZERO,
		"restored rabbit must be registered with the ambient life service")
	# Повадка приходит из архетипа, а не из константы в загрузчике.
	assert(sim_b.ambient_life_service.count() == registered_before,
		"restore must not unregister creatures it does not recreate")
	assert(sim_b.ambient_life_service.heading_of(bystander) != Vector3.ZERO,
		"a creature outside the four source dictionaries must survive the restore")
	var landscape_objects := sim_b.get_node("WorldTerritory/LandscapeObjects")
	assert(sim_b.resource_piles.any(func(pile): return bool(pile.node.get_meta("landscape_owned", false)) and pile.node.get_parent() == landscape_objects), "starter world loot must return to the terrain hierarchy")
	var restored_stash: ResourcePile = null
	for pile: ResourcePile in sim_b.resource_piles:
		if pile.is_backpack:
			restored_stash = pile
			break
	assert(restored_stash != null, "party stash must return after save/load")
	var restored_food := int(restored_stash.resources.get("food", 0))
	sim_b.settlement.add("food", 1)
	assert(int(restored_stash.resources.get("food", 0)) == restored_food + 1,
		"save restore must rebind settlement to the physical stash inventory")

	await SimHelper.cleanup_simulation(self, sim_b)
	print("  => Save/Load Round-Trip Test PASSED!")
	quit(0)
