extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame

	var worker: Citizen = simulation.citizens[2]
	worker.set_player_controlled(false)
	simulation.day_cycle.current_day = 1
	simulation.clock.set_time(12 * 60)
	simulation._assign_daily_order(worker, "gather_branches")
	assert(simulation._activate_citizen_overtime(worker, "personal"))
	assert(worker.daily_order_workday_id == 1)
	assert(is_equal_approx(worker.daily_order_expires_at, simulation.daily_order_expiration_for_workday(2)))

	# The first end of shift preserves both the daily assignment and overtime.
	simulation._handle_day_cycle_event(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_ENDED, 16))
	assert(worker.has_daily_order())
	assert(worker.has_active_overtime(1))

	# A second scope may overlap and can be cancelled independently.
	assert(worker.activate_overtime(2, "settlement", 1))
	worker.deactivate_overtime("personal")
	assert(worker.has_overtime_source("settlement", 1))

	simulation.day_cycle.current_day = 2
	simulation.clock.set_time(8 * 60)
	simulation._handle_day_cycle_event(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_STARTED, 8))
	assert(worker.daily_order_workday_id == 2)
	assert(worker.has_active_overtime(2))

	# A selected shift length applies at the next start, never retroactively.
	simulation.settlement.workday_hours = 8
	simulation.day_cycle.current_day = 2
	simulation.clock.set_time(12 * 60)
	simulation._set_workday_hours(6)
	assert(simulation.settlement.workday_hours == 8)
	assert(simulation.settlement.pending_workday_hours == 6)
	simulation.day_cycle.current_day = 3
	simulation.clock.set_time(8 * 60)
	simulation._handle_day_cycle_event(SimulationDayEvent.new(SimulationDayEvent.Kind.WORKDAY_STARTED, 8))
	assert(simulation.settlement.workday_hours == 6)
	assert(simulation.settlement.pending_workday_hours == 0)

	root.remove_child(simulation)
	simulation.free()
	quit(0)
