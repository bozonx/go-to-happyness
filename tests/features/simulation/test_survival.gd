extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests survival at zero wellbeing: a skipped night may remove one resident
## but must not cascade-remove additional residents per hour at zero.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	simulation.settlement.wellbeing = 1
	simulation.settlement_survival_service.last_survival_hour = -1
	simulation.world_session.environment.restore_legacy_clock(21 * 60, simulation.day_cycle.current_day)
	var citizen_count_before_zero_wellbeing_skip: int = simulation.citizens.size()
	SimHelper.skip_night(simulation)
	assert(simulation.citizens.size() == citizen_count_before_zero_wellbeing_skip - 1)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.visible)

	await SimHelper.cleanup_simulation(self, simulation)
	quit(0)
