extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests skip-night, skip-to-workday, and outside worker departure/return cycle.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var staying_worker: Citizen = simulation.citizens[1]
	var staying_position: Vector3 = simulation.entrance_stone.global_position + Vector3(8.0, 0.0, 3.0)
	simulation.day_cycle.current_day = 2
	simulation.clock.set_time(2 * 60 + 30)
	simulation.settlement.wellbeing = 100
	staying_worker.global_position = staying_position
	simulation.last_citizen_positions[staying_worker.get_instance_id()] = staying_position

	# Skip-night buttons are only visible in overview mode, not first person.
	SimHelper.toggle_hero_view(simulation)
	assert(not simulation.is_first_person)
	SimHelper.update_skip_night_button(simulation)
	assert(simulation.skip_night_button.visible)
	var citizen_count_before_midnight_skip: int = simulation.citizens.size()
	SimHelper.skip_night(simulation)
	assert(simulation.day_cycle.current_day == 2)
	assert(simulation.clock.hour() == 6 and simulation.clock.minute() == 0)
	assert(not simulation.skip_night_button.visible)
	assert(simulation.start_workday_button.visible)
	SimHelper.skip_to_workday_start(simulation)
	assert(simulation.clock.hour() == 8 and simulation.clock.minute() == 0)
	assert(not simulation.start_workday_button.visible)
	assert(simulation.citizens.size() == citizen_count_before_midnight_skip)
	assert(staying_worker.visible)
	assert(staying_worker.global_position == staying_position)

	# Outside worker lifecycle: departure, skip-night preservation, return.
	var outside_worker: Citizen = simulation.citizens[3]
	simulation.day_cycle.current_day = 1
	simulation.settlement_survival_service.last_survival_hour = -1
	simulation.clock.set_time(21 * 60)
	staying_position = simulation.entrance_stone.global_position + Vector3(12.0, 0.0, 2.0)
	staying_worker.global_position = staying_position
	simulation.last_citizen_positions[staying_worker.get_instance_id()] = staying_position
	SimHelper.update_skip_night_button(simulation)
	assert(simulation.skip_night_button.visible)
	outside_worker.global_position = simulation.entrance_stone.global_position + Vector3(10.0, 0.0, 0.0)
	simulation.last_citizen_positions[outside_worker.get_instance_id()] = outside_worker.global_position
	simulation.selected_builder = outside_worker
	SimHelper.assign_daily_order(simulation, outside_worker, "courier")
	outside_worker.daily_order_workday_id = simulation.day_cycle.current_day
	outside_worker.activate_overtime(simulation.day_cycle.current_day, "test")
	simulation.courier_dispatcher.tasks.clear()
	outside_worker.idle()
	assert(outside_worker.daily_order_role == "courier")
	assert(not outside_worker.is_player_controlled)
	var money_before_outside_work: int = simulation.settlement.money
	simulation.clock.set_time(9 * 60)
	SimHelper.send_selected_resident_to_outside_work(simulation)
	var outside_task: CourierTask = null
	for task: CourierTask in simulation.courier_dispatcher.available_tasks():
		if task.kind == CourierTask.Kind.OUTSIDE_WORK:
			outside_task = task
			break
	assert(outside_task != null)
	assert(simulation.courier_dispatcher.start_task(outside_worker, outside_task.id))
	outside_worker.global_position = simulation.entrance_stone.global_position
	outside_worker._process_outside_work_departure(0.1)
	assert(simulation.outside_workers.has(outside_worker.get_stable_id()))
	var outside_reward: int = int(simulation.outside_workers[outside_worker.get_stable_id()].get("reward", 0))
	assert(outside_reward >= simulation.OUTSIDE_WORK_BASE_REWARD_MIN and outside_reward <= simulation.OUTSIDE_WORK_BASE_REWARD_MAX)
	assert(not outside_worker.visible)

	# Skip night while outside worker is away: worker stays away, no reward yet.
	outside_worker.overtime_mode = false
	outside_worker.overtime_until_workday_id = 0
	outside_worker.daily_order_workday_id = simulation.day_cycle.current_day + 1
	simulation.clock.set_time(21 * 60)
	SimHelper.skip_night(simulation)
	assert(simulation.clock.hour() == 6 and simulation.clock.minute() == 0)
	assert(not simulation.skip_night_button.visible)
	assert(staying_worker.global_position == staying_position)
	assert(simulation.outside_workers.has(outside_worker.get_stable_id()))
	assert(not outside_worker.visible)
	assert(outside_worker.daily_order_role == "courier")
	assert(outside_worker.daily_order_workday_id == 2)
	assert(simulation.settlement.money == money_before_outside_work)

	# Return outside workers and collect reward.
	simulation.clock.set_time(9 * 60)
	SimHelper.return_outside_workers(simulation)
	assert(not simulation.outside_workers.has(outside_worker.get_stable_id()))
	assert(outside_worker.visible)
	assert(simulation.settlement.money == money_before_outside_work + outside_reward)
	var outside_return_position := outside_worker.global_position
	SimHelper.guard_citizen_positions(simulation)
	assert(outside_worker.global_position == outside_return_position)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
