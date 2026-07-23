extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests arrival entrance, home assignment, interrupted arrivals,
## and tent auto-assign housing.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var resident: Citizen = simulation.citizens[1]

	# Arrival entrance and home assignment
	resident.go_to_arrival_entrance(simulation.entrance_stone.global_position)
	assert(resident.has_active_arrival_task())
	assert(not resident.is_available_for_schedule())
	var arrival_home := Node3D.new()
	simulation.add_child(arrival_home)
	resident.assign_home(arrival_home)
	resident.go_home()
	assert(resident.state == Citizen.State.TO_ARRIVAL_ENTRANCE)

	# Interrupted arrivals are re-queued
	var interrupted_order := {"house": arrival_home, "dispatched": true, "greeter_id": resident.get_instance_id()}
	simulation.pending_arrivals.append(interrupted_order)
	simulation.arrival_greeters[resident.get_instance_id()] = interrupted_order
	resident.idle()
	simulation._requeue_interrupted_arrivals()
	assert(not bool(simulation.pending_arrivals[0].get("dispatched", false)))
	simulation._cancel_arrivals_for_house(arrival_home)
	assert(simulation.pending_arrivals.is_empty())

	# No housing at start
	assert(simulation.tent == null)
	assert(simulation._total_housing_slots() == 0)

	# Tent auto-assign: when a tent is completed, unhoused citizens are
	# automatically assigned up to the tent's capacity.
	for citizen: Citizen in simulation.citizens:
		citizen.home = null
	var test_tent := Node3D.new()
	simulation.add_child(test_tent)
	test_tent.set_meta("is_tent", true)
	test_tent.set_meta("building_type", "tent")
	test_tent.set_meta("housing_capacity", 4)
	test_tent.set_meta("spawn_slots", 4)
	var unhoused_before_tent: int = simulation._unhoused_citizen_count()
	assert(unhoused_before_tent == simulation.citizens.size())
	simulation._house_initial_residents(test_tent)
	var assigned := 0
	for citizen in simulation.citizens:
		if citizen.home == test_tent:
			assigned += 1
	assert(assigned == mini(4, simulation.citizens.size()))
	assert(int(test_tent.get_meta("spawn_slots", 0)) == maxi(0, 4 - simulation.citizens.size()))

	# With 4 citizens and capacity 4, all slots are filled — order button disabled.
	simulation.selected_house = test_tent
	simulation._show_house_menu()
	if simulation.citizens.size() >= 4:
		assert(simulation.house_spawn_button.disabled)
		assert(simulation.house_spawn_button.text == "No free beds")
		# Simulate one resident leaving: free a slot and clear their home.
		var departed: Citizen = simulation.citizens[1] as Citizen
		departed.home = null
		test_tent.set_meta("spawn_slots", 1)
		# Now order button should be active.
		simulation._show_house_menu()
		assert(not simulation.house_spawn_button.disabled)
		# Order 1 resident — sets daily limit.
		var slots_before_order := int(test_tent.get_meta("spawn_slots", 0))
		simulation._spawn_house_citizen()
		assert(int(test_tent.get_meta("tent_order_day", -1)) == simulation.day_cycle.current_day)
		assert(int(test_tent.get_meta("spawn_slots", 0)) == slots_before_order - 1)
		# Second order same day is blocked.
		simulation._show_house_menu()
		assert(simulation.house_spawn_button.disabled)
		assert(simulation.house_spawn_button.text == "Already ordered today")
		var slots_after_order := int(test_tent.get_meta("spawn_slots", 0))
		simulation._spawn_house_citizen()
		assert(int(test_tent.get_meta("spawn_slots", 0)) == slots_after_order)
		# Next day: order allowed again (if slots remain).
		simulation.day_cycle.current_day += 1
		simulation._show_house_menu()
		if slots_after_order > 0:
			assert(not simulation.house_spawn_button.disabled)

	# Settle unhoused button should be hidden for tents.
	var settle_btn := simulation.house_menu.get_node_or_null("SettleUnhoused") as Button
	assert(not settle_btn.visible)

	# Cleanup
	simulation._cancel_arrivals_for_house(test_tent)
	for citizen in simulation.citizens:
		if citizen.home == test_tent:
			citizen.home = null
	test_tent.queue_free()
	simulation.selected_house = null

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
