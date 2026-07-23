extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	# 1. Verify Hero and initial squad setup
	assert(is_instance_valid(simulation.hero_citizen), "Hero must exist")
	assert(simulation.citizens.size() > 1, "Initial citizens must exist")
	var hero: Citizen = simulation.hero_citizen
	for citizen: Citizen in simulation.citizens:
		assert(citizen.squad_state.is_in_squad(), "Citizen must be in squad")
		assert(citizen.squad_state.squad_leader_id == hero.ai_id, "Squad leader must be hero")

	# 2. Verify instant flag placement within radius
	SimHelper.select_build_mode(simulation, "settlement_flag")
	assert(not simulation.build_mode.is_empty(), "Build mode should be settlement_flag")
	
	# Try placing too far (> 20 meters from hero)
	var far_pos := hero.global_position + Vector3(50.0, 0.0, 0.0)
	SimHelper.place_building(simulation, far_pos)
	assert(not simulation.village_territory_service.has_flag(), "Flag placement far away should be blocked")

	# Place near hero (5 meters from hero)
	var valid_pos := hero.global_position + Vector3(5.0, 0.0, 0.0)
	SimHelper.select_build_mode(simulation, "settlement_flag")
	SimHelper.place_building(simulation, valid_pos)
	assert(simulation.village_territory_service.has_flag(), "Flag should be instantly placed near hero")

	# 3. Verify squad binding to settlement
	for citizen: Citizen in simulation.citizens:
		assert(citizen.settlement_id == &"main_settlement", "Squad citizen should be bound to main_settlement upon flag placement")

	print("SUCCESS: test_squad_and_flag passed completely!")
	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
