extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)
	var worker: Citizen = simulation.citizens[1]
	var courier: Citizen = simulation.citizens[2]

	simulation.citizen_needs_service.schedule_toilet(worker.ai_id)
	simulation.citizen_needs_service.schedule_toilet(courier.ai_id)
	simulation.citizen_needs_service.tick(20.0 * 60.0 + 1.0)

	# Ordinary work is interruptible, so independently scheduled requests are
	# handled when they become due instead of accumulating until shift end.
	worker.state = Citizen.State.CONSTRUCTING
	worker.active_role = "construction"
	var work_snapshot := SettlementAIWorldFacade.new(simulation).capture(1)
	assert(bool(work_snapshot.citizen(worker.ai_id).facts.value(&"needs.can_start_toilet", false)), "Toilet need should be able to interrupt ordinary work")

	# A courier with reserved/collected cargo remains atomic. Interrupting this
	# state would return or duplicate construction resources.
	courier.state = Citizen.State.TO_CONSTRUCTION_SITE
	var delivery_snapshot := SettlementAIWorldFacade.new(simulation).capture(2)
	assert(not bool(delivery_snapshot.citizen(courier.ai_id).facts.value(&"needs.can_start_toilet", true)), "Toilet need must wait until an active delivery finishes")

	await SimHelper.cleanup_simulation(self, simulation)
	quit(0)
