extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests survival at zero wellbeing: a skipped night may remove one resident
## but must not cascade-remove additional residents per hour at zero.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	simulation.settlement.wellbeing = 1
	simulation.settlement_survival_service.last_survival_hour = -1
	simulation.clock.set_time(21 * 60)
	var citizen_count_before_zero_wellbeing_skip: int = simulation.citizens.size()
	simulation._skip_night()
	assert(simulation.citizens.size() == citizen_count_before_zero_wellbeing_skip - 1)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.visible)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
