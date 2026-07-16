extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _frame in range(10):
		await physics_frame
	assert(simulation.citizens.size() == simulation.POPULATION)
	assert(simulation.settlement.money == SettlementState.TENT_STARTING_MONEY)
	assert(simulation.settlement.amount("food") == SettlementState.TENT_STARTING_FOOD)
	assert(simulation.settlement.amount("water") == SettlementState.TENT_STARTING_WATER)
	assert(simulation.settlement.branches == 0)
	assert(is_instance_valid(simulation.citizen_ai))
	assert(simulation.citizen_ai.brain_count() == simulation.citizens.size())
	assert(simulation.citizen_ai.goal_count() == 14)
	assert(simulation.citizen_needs_service != null)
	assert(simulation.citizen_ai.director.provider_count() == 10)
	assert(is_instance_valid(simulation.hero_citizen))
	assert(simulation.hero_citizen.is_hero)
	assert(simulation.hero_citizen.specialization == "unassigned")
	assert(simulation.hero_citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK)
	assert(simulation.is_first_person)
	assert(simulation.player_citizen == simulation.hero_citizen)
	assert(simulation._player_can_command_labor())
	simulation.selected_builder = simulation.hero_citizen
	simulation._refresh_build_menu()
	assert(simulation.daily_order_submenu_btn.visible)
	assert(not simulation.daily_order_submenu_btn.disabled)
	assert(simulation.job_submenu_btn.visible)
	assert(not simulation.job_submenu_btn.disabled)
	simulation._open_job_submenu()
	assert(simulation.build_menu_is_job_menu)
	simulation._open_daily_order_submenu()
	assert(simulation.build_menu_is_daily_order_menu)
	var construction_daily_button: Button = null
	for button in simulation.role_buttons:
		if str(button.get_meta("submenu", "")) == "daily" and str(button.get_meta("role", "")) == "construction":
			construction_daily_button = button
			break
	assert(construction_daily_button != null)
	assert(construction_daily_button.visible)
	assert(not construction_daily_button.disabled)
	var cleaning_daily_button: Button = null
	for button in simulation.role_buttons:
		if str(button.get_meta("submenu", "")) == "daily" and str(button.get_meta("role", "")) == "cleaning":
			cleaning_daily_button = button
			break
	assert(cleaning_daily_button != null)
	assert(cleaning_daily_button.visible)
	assert(not cleaning_daily_button.disabled)
	simulation._close_assignment_submenu()
	simulation._appoint_official(simulation.hero_citizen)
	var delegated_officer: Citizen = simulation.citizens[1]
	simulation._appoint_official(delegated_officer)
	assert(simulation._player_can_command_labor())
	simulation._appoint_official(simulation.hero_citizen)
	assert(simulation._player_can_command_labor())
	# A daily order releases first-person control but does not break the permanent job.
	simulation.selected_builder = simulation.hero_citizen
	simulation.hero_citizen.set_player_controlled(true)
	simulation._set_selected_work_role("gather_grass", true)
	assert(not simulation.hero_citizen.is_player_controlled)
	assert(simulation.hero_citizen.employment_state == Citizen.EmploymentState.EMPLOYED)
	assert(simulation.hero_citizen.permanent_role == "official")
	assert(simulation.hero_citizen.daily_order_role == "gather_grass")
	simulation._appoint_official(simulation.hero_citizen)
	assert(is_instance_valid(simulation.entrance_stone))
	var hero_count := 0
	for citizen in simulation.citizens:
		hero_count += 1 if citizen.is_hero else 0
	assert(hero_count == 1)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.is_inside_tree())
		assert(citizen.is_in_group("citizens"))
		assert(citizen.home == null)
		assert(is_finite(citizen.global_position.x) and is_finite(citizen.global_position.y) and is_finite(citizen.global_position.z))
		assert(citizen.global_position.y > -1.0)
		assert(citizen.get_children().any(func(child): return child is MeshInstance3D))
		assert(citizen.global_position.distance_to(simulation.entrance_stone.global_position) < 5.0)
		if not citizen.is_hero:
			assert(citizen.specialization == "unassigned")
			assert(citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK)
	var resident: Citizen = simulation.citizens[1]
	var original_pathfinder := resident.pathfinder
	var original_reachability_query := resident.route_reachability_query
	var path_calls := [0]
	var reachability_calls := [0]
	resident.pathfinder = func(_from: Vector3, target: Vector3, _allow: bool) -> RouteResult:
		path_calls[0] += 1
		return RouteResult.success([target], target)
	resident.route_reachability_query = func(_from: Vector3, _target: Vector3, _allow: bool) -> bool:
		reachability_calls[0] += 1
		return true
	resident.idle_wander_anchor = resident.global_position
	assert(resident._choose_idle_wander_target() != Vector3.INF)
	assert(reachability_calls[0] == Citizen.IDLE_WANDER_CANDIDATES and path_calls[0] == 0)
	resident.pathfinder = original_pathfinder
	resident.route_reachability_query = original_reachability_query
	var original_resident_position := resident.global_position
	var entrance: Vector3 = simulation.entrance_stone.global_position
	resident.global_position = entrance + Vector3(2.4, 0.0, 0.0)
	simulation.last_citizen_positions[resident.get_instance_id()] = entrance + Vector3(2.6, 0.0, 0.0)
	simulation._guard_citizen_positions()
	assert(resident.global_position.distance_to(entrance) < 2.5)
	resident.global_position = entrance
	simulation.last_citizen_positions[resident.get_instance_id()] = entrance + Vector3(10.0, 0.0, 0.0)
	simulation._guard_citizen_positions()
	assert(resident.global_position.distance_to(entrance) > 5.0)
	resident.global_position = original_resident_position
	simulation.last_citizen_positions[resident.get_instance_id()] = original_resident_position
	# The needs service schedules relief; the actor receives only a selected target
	# through the native actuator and preserves its interrupted work state.
	var work_target: Vector3 = simulation._resource_access_position(resident.global_position, simulation.tree_positions[0])
	assert(work_target != Vector3.INF)
	resident.gender = "male"
	resident.state = Citizen.State.TO_TREE
	resident.source_access_position = work_target
	simulation.citizen_needs_service.schedule_toilet(resident.ai_id)
	simulation.citizen_needs_service.tick(20.0 * 60.0 + 1.0)
	assert(simulation.citizen_needs_service.has_toilet_request(resident.ai_id))
	var relief_candidates: Array[Dictionary] = simulation.citizen_needs_service.relief_candidates_for(resident)
	assert(not relief_candidates.is_empty())
	var relief_target := relief_candidates[0] as Dictionary
	resident.go_to_relief(relief_target[&"position"] as Vector3, relief_target[&"kind"] as StringName)
	assert(resident.state == Citizen.State.TO_BUSH)
	assert(resident.toilet_relief_type == "tree")
	assert(resident.source_access_position == work_target)
	resident.global_position = relief_target[&"position"] as Vector3
	resident._process_to_bush(0.1)
	assert(resident.state == Citizen.State.USING_BUSH)
	resident.toilet_timer.start(0.0)
	resident._process_using_bush(0.1)
	assert(resident.state == Citizen.State.TO_TREE)
	assert(resident.source_access_position == work_target)
	assert(not simulation.citizen_needs_service.has_toilet_request(resident.ai_id))

	# A scheduled leisure break must only claim an idle citizen. In particular it
	# must not overwrite a route to an already assigned work target.
	resident.setup_specialization("cook")
	resident.state = Citizen.State.TO_TREE
	resident.source_access_position = work_target
	simulation.park_positions.clear()
	simulation.park_positions.append(resident.global_position + Vector3(1.0, 0.0, 0.0))
	simulation._start_park_rest(true)
	assert(resident.state == Citizen.State.TO_TREE)
	assert(resident.source_access_position == work_target)

	resident.go_to_arrival_entrance(simulation.entrance_stone.global_position)
	assert(resident.has_active_arrival_task())
	assert(not resident.is_available_for_schedule())
	var arrival_home := Node3D.new()
	simulation.add_child(arrival_home)
	resident.assign_home(arrival_home)
	resident.go_home()
	assert(resident.state == Citizen.State.TO_ARRIVAL_ENTRANCE)
	var interrupted_order := {"house": arrival_home, "dispatched": true, "greeter_id": resident.get_instance_id()}
	simulation.pending_arrivals.append(interrupted_order)
	simulation.arrival_greeters[resident.get_instance_id()] = interrupted_order
	resident.idle()
	simulation._requeue_interrupted_arrivals()
	assert(not bool(simulation.pending_arrivals[0].get("dispatched", false)))
	simulation._cancel_arrivals_for_house(arrival_home)
	assert(simulation.pending_arrivals.is_empty())
	assert(simulation.tent == null)
	assert(simulation._total_housing_slots() == 0)
	# Tent auto-assign: when a tent is completed, unhoused citizens are
	# automatically assigned up to the tent's capacity.
	var test_tent := Node3D.new()
	simulation.add_child(test_tent)
	test_tent.set_meta("is_tent", true)
	test_tent.set_meta("building_type", "tent")
	test_tent.set_meta("housing_capacity", 4)
	test_tent.set_meta("spawn_slots", 4)
	var unhoused_before_tent := simulation._unhoused_citizen_count()
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
		var departed := simulation.citizens[1]
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
	# Cleanup tent assignment so remaining tests are unaffected.
	simulation._cancel_arrivals_for_house(test_tent)
	for citizen in simulation.citizens:
		if citizen.home == test_tent:
			citizen.home = null
	test_tent.queue_free()
	simulation.selected_house = null
	var pond_cell: Vector2i = simulation._cell_from_position(simulation.pond_positions[0])
	assert(simulation._is_navigation_cell_blocked(pond_cell))
	var pond_route: RouteResult = simulation._find_path_around_houses(simulation.citizens[0].global_position, simulation.pond_positions[0], false)
	assert(not pond_route.reachable)
	assert(not simulation.citizens[0]._move_to(simulation.pond_positions[0], 0.1))
	var pond_access: Vector3 = simulation._pond_access_position(simulation.citizens[0].global_position, simulation.pond_positions[0])
	assert(pond_access != Vector3.INF)
	var pond_access_route: RouteResult = simulation._find_path_around_houses(simulation.citizens[0].global_position, pond_access, false)
	assert(pond_access_route.reachable)
	var cell := Vector2i(12, 12)
	var position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("campfire")
	simulation.building_registry.reserve(cell, position, blueprint.footprint)
	simulation._create_construction_site(cell, "campfire", position, 0, blueprint, blueprint.footprint)
	assert(simulation.construction_sites.size() == 1)
	assert(simulation._is_construction_site(simulation.construction_sites[0].node))
	var construction_site: ConstructionSite = simulation.construction_sites[0]
	var construction_resource := str(construction_site.required_materials.keys()[0])
	var supply_worker: Citizen = simulation.citizens[2]
	supply_worker.idle()
	var logistics_worker: Citizen = simulation.citizens[3]
	# The first warehouse must be supplyable from ground piles. This is the
	# bootstrap path where no warehouse position exists yet.
	assert(simulation.warehouse_positions.is_empty())
	simulation._create_resource_pile(logistics_worker.global_position, {construction_resource: 1})
	var source_pile: Dictionary = simulation.resource_piles.back()
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var pile_snapshot := SettlementAIWorldFacade.new(simulation).capture(999)
	var pile_orders := CourierDeliveryOrderProvider.new().collect_orders(pile_snapshot)
	var matching_pile_orders := pile_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery")
	assert(not matching_pile_orders.is_empty())
	var pile_order: CitizenOrder = matching_pile_orders.front()
	assert(simulation.courier_dispatcher.start_task(logistics_worker, pile_order.payload.value(&"courier.task_id")))
	assert(int(source_pile.resources.get(construction_resource, 0)) == 0)
	logistics_worker.global_position = source_pile.node.global_position
	logistics_worker._process_construction_pickup(0.1)
	logistics_worker.global_position = logistics_worker.construction_position
	logistics_worker._process_construction_delivery(0.1)
	assert(int(construction_site.delivered_materials.get(construction_resource, 0)) == 1)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 0)
	logistics_worker.clear_daily_order()

	# Ctrl+F grants settlement stock without creating a warehouse or a pile. That
	# stock is collected from the camp entrance until a warehouse is completed.
	simulation.settlement.add(construction_resource, 1)
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var debug_stock_snapshot := SettlementAIWorldFacade.new(simulation).capture(1000)
	var debug_stock_orders := CourierDeliveryOrderProvider.new().collect_orders(debug_stock_snapshot)
	var matching_debug_orders := debug_stock_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery")
	assert(not matching_debug_orders.is_empty())
	var debug_stock_order: CitizenOrder = matching_debug_orders.front()
	assert(simulation.courier_dispatcher.start_task(logistics_worker, debug_stock_order.payload.value(&"courier.task_id")))
	assert(simulation.settlement.amount(construction_resource) == 0)
	logistics_worker.global_position = simulation.entrance_stone.global_position
	logistics_worker._process_construction_pickup(0.1)
	logistics_worker.global_position = logistics_worker.construction_position
	logistics_worker._process_construction_delivery(0.1)
	assert(int(construction_site.delivered_materials.get(construction_resource, 0)) == 2)
	logistics_worker.clear_daily_order()

	simulation.settlement.add(construction_resource, 1)
	var material_before: int = simulation.settlement.amount(construction_resource)
	var added_test_warehouse := false
	if simulation.warehouse_positions.is_empty():
		simulation.warehouse_positions.append(supply_worker.global_position)
		simulation.settlement.add_warehouse("warehouse")
		added_test_warehouse = true
	assert(simulation._reserve_player_gather_storage("branches", simulation.HERO_GATHER_YIELD) == simulation.HERO_GATHER_YIELD)
	simulation._assign_daily_order(supply_worker, "construction")
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var construction_snapshot := SettlementAIWorldFacade.new(simulation).capture(1000)
	var workforce_orders := WorkforceOrderProvider.new().collect_orders(construction_snapshot)
	assert(workforce_orders.all(func(order: CitizenOrder): return order.citizen_id != supply_worker.ai_id))
	var courier_orders := CourierDeliveryOrderProvider.new().collect_orders(construction_snapshot)
	assert(courier_orders.any(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery"))
	logistics_worker.clear_daily_order()
	supply_worker.clear_daily_order()
	if added_test_warehouse:
		simulation.warehouse_positions.clear()
		simulation.settlement.warehouses.clear()
		simulation.settlement.warehouse_types.clear()
		simulation.settlement.warehouse_ever_built = false

	# Verify the dispatcher reservation/reconciliation path for construction supply.
	simulation._assign_daily_order(logistics_worker, "courier")
	simulation._update_couriers()
	var final_snapshot := SettlementAIWorldFacade.new(simulation).capture(1001)
	var final_orders := CourierDeliveryOrderProvider.new().collect_orders(final_snapshot)
	var final_order: Variant = final_orders.filter(func(order: CitizenOrder): return order.citizen_id == logistics_worker.ai_id and order.kind == &"courier_delivery").front()
	assert(final_order != null)
	assert(simulation.courier_dispatcher.start_task(logistics_worker, final_order.payload.value(&"courier.task_id")))
	assert(simulation.settlement.amount(construction_resource) == material_before - 1)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 1)
	logistics_worker.idle()
	simulation._reconcile_construction_reservations(construction_site)
	assert(simulation.settlement.amount(construction_resource) == material_before)
	assert(int(construction_site.reserved_materials.get(construction_resource, 0)) == 0)
	logistics_worker.clear_daily_order()
	assert(simulation.construction.cancel_site(simulation.construction_sites[0].node))
	assert(simulation.construction_sites.is_empty())
	assert(simulation.building_registry.record_at_cell(cell) == null)
	var field_officer: Citizen = simulation.citizens[1]
	simulation._appoint_official(field_officer)
	assert(simulation._employment_center_position() == Vector3.INF)
	assert(simulation._registration_official() == null)
	var civic_centre := Node3D.new()
	civic_centre.position = field_officer.global_position
	civic_centre.set_meta("service_position", field_officer.global_position)
	civic_centre.set_meta("accepting_workers", true)
	simulation.add_child(civic_centre)
	simulation.campfire_node = civic_centre
	simulation.game_minutes = 9.0 * 60.0
	# Building completion must hand the officer directly to the new centre.
	simulation._activate_employment_centre(civic_centre)
	assert(field_officer.state == Citizen.State.TO_OFFICIAL_WORK)
	field_officer.state = Citizen.State.OFFICIAL_WORK
	assert(simulation._registration_official() == field_officer)
	# A delegated officer enables automation, but the player can still issue
	# manual labor commands.
	simulation.selected_building = civic_centre
	simulation.game_minutes = 20.0 * 60.0
	field_officer.overtime_mode = false
	simulation._call_worker_overtime()
	assert(field_officer.overtime_mode)
	simulation.game_minutes = 9.0 * 60.0
	var first_in_queue: Citizen = simulation.citizens[2]
	var second_in_queue: Citizen = simulation.citizens[3]
	first_in_queue.global_position = civic_centre.global_position
	second_in_queue.global_position = civic_centre.global_position
	simulation.citizen_ai.process_mode = Node.PROCESS_MODE_DISABLED
	first_in_queue.begin_employment_processing(simulation._employment_center_position())
	second_in_queue.begin_employment_processing(simulation._employment_center_position())
	assert(simulation._can_start_registration(first_in_queue))
	assert(not simulation._can_start_registration(second_in_queue))
	first_in_queue.state = Citizen.State.EMPLOYMENT_PROCESSING
	assert(not simulation._can_start_registration(second_in_queue))
	field_officer.global_position += Vector3(10.0, 0.0, 0.0)
	assert(not simulation._can_start_registration(first_in_queue))
	simulation.citizen_ai.process_mode = Node.PROCESS_MODE_INHERIT
	var staying_worker: Citizen = simulation.citizens[1]
	var staying_position: Vector3 = simulation.entrance_stone.global_position + Vector3(8.0, 0.0, 3.0)
	simulation.day_cycle.current_day = 2
	simulation.clock.set_time(2 * 60 + 30)
	simulation.wellbeing = 100
	staying_worker.global_position = staying_position
	simulation.last_citizen_positions[staying_worker.get_instance_id()] = staying_position
	# Skip-night buttons are only visible in overview mode, not first person.
	simulation._toggle_hero_view()
	assert(not simulation.is_first_person)
	simulation._update_skip_night_button()
	assert(simulation.skip_night_button.visible)
	var citizen_count_before_midnight_skip: int = simulation.citizens.size()
	simulation._skip_night()
	assert(simulation.day_cycle.current_day == 2)
	assert(simulation.clock.hour() == 6 and simulation.clock.minute() == 0)
	assert(not simulation.skip_night_button.visible)
	assert(simulation.start_workday_button.visible)
	simulation._skip_to_workday_start()
	assert(simulation.clock.hour() == 8 and simulation.clock.minute() == 0)
	assert(not simulation.start_workday_button.visible)
	# Stay in overview mode for remaining skip-night button checks.
	assert(simulation.citizens.size() == citizen_count_before_midnight_skip)
	assert(staying_worker.visible)
	assert(staying_worker.global_position == staying_position)
	var outside_worker: Citizen = simulation.citizens[3]
	simulation.day_cycle.current_day = 1
	simulation.last_survival_hour = -1
	simulation.clock.set_time(21 * 60)
	staying_position = simulation.entrance_stone.global_position + Vector3(12.0, 0.0, 2.0)
	staying_worker.global_position = staying_position
	simulation.last_citizen_positions[staying_worker.get_instance_id()] = staying_position
	simulation._update_skip_night_button()
	assert(simulation.skip_night_button.visible)
	outside_worker.global_position = simulation.entrance_stone.global_position + Vector3(10.0, 0.0, 0.0)
	simulation.last_citizen_positions[outside_worker.get_instance_id()] = outside_worker.global_position
	simulation.selected_builder = outside_worker
	simulation._assign_daily_order(outside_worker, "courier")
	assert(outside_worker.daily_order_role == "courier")
	assert(not outside_worker.is_player_controlled)
	var money_before_outside_work: int = simulation.settlement.money
	simulation._send_selected_resident_to_outside_work()
	assert(simulation.outside_workers.has(outside_worker.get_instance_id()))
	var outside_reward: int = int(simulation.outside_workers[outside_worker.get_instance_id()].get("reward", 0))
	assert(outside_reward >= simulation.OUTSIDE_WORK_BASE_REWARD_MIN and outside_reward <= simulation.OUTSIDE_WORK_BASE_REWARD_MAX)
	assert(not outside_worker.visible)
	simulation._skip_night()
	assert(simulation.clock.hour() == 6 and simulation.clock.minute() == 0)
	assert(not simulation.skip_night_button.visible)
	assert(staying_worker.global_position == staying_position)
	assert(simulation.outside_workers.has(outside_worker.get_instance_id()))
	assert(not outside_worker.visible)
	assert(outside_worker.daily_order_role == "courier")
	assert(outside_worker.daily_order_workday_id == 2)
	assert(simulation.settlement.money == money_before_outside_work)
	simulation.clock.set_time(9 * 60)
	simulation._return_outside_workers()
	assert(simulation.outside_workers.has(outside_worker.get_instance_id()))
	simulation.clock.set_time(21 * 60)
	simulation._return_outside_workers()
	assert(not simulation.outside_workers.has(outside_worker.get_instance_id()))
	assert(outside_worker.visible)
	assert(simulation.settlement.money == money_before_outside_work + outside_reward)
	var outside_return_position := outside_worker.global_position
	simulation._guard_citizen_positions()
	assert(outside_worker.global_position == outside_return_position)
	# Return to first person for hero view toggle tests.
	simulation._toggle_hero_view()
	assert(simulation.is_first_person)
	# The game starts in hero view; R toggles between hero FPP and overview.
	assert(simulation.is_first_person)
	simulation._toggle_hero_view()
	assert(not simulation.is_first_person)
	simulation._toggle_hero_view()
	assert(simulation.is_first_person)
	assert(simulation.player_citizen == simulation.hero_citizen)
	simulation._select_citizen(simulation.citizens[1])
	simulation._take_control_of_selected_citizen()
	assert(simulation.player_citizen == simulation.citizens[1])
	simulation._toggle_hero_view()
	assert(simulation.player_citizen == simulation.hero_citizen)

	# B opens the global build menu in overview mode, not only in first-person.
	simulation._toggle_hero_view()
	assert(not simulation.is_first_person)
	var b_event := InputEventKey.new()
	b_event.keycode = KEY_B
	b_event.pressed = true
	simulation._unhandled_input(b_event)
	assert(simulation.build_menu.visible)
	assert(simulation.build_menu_is_global)
	var b_release := InputEventKey.new()
	b_release.keycode = KEY_B
	b_release.pressed = false
	simulation._unhandled_input(b_release)
	simulation._toggle_hero_view()
	assert(simulation.is_first_person)

	# T in first-person drops the controlled unit's pocket contents as a ground pile.
	simulation.pocket = {"wood": 3, "food": 2}
	var piles_before_drop: int = simulation.resource_piles.size()
	var t_event := InputEventKey.new()
	t_event.keycode = KEY_T
	t_event.pressed = true
	simulation._unhandled_input(t_event)
	assert(simulation.pocket.is_empty())
	assert(simulation.resource_piles.size() == piles_before_drop + 1)
	var dropped_pile: Dictionary = simulation.resource_piles[simulation.resource_piles.size() - 1]
	assert(int(dropped_pile.resources.get("wood", 0)) == 3)
	assert(int(dropped_pile.resources.get("food", 0)) == 2)
	var t_release := InputEventKey.new()
	t_release.keycode = KEY_T
	t_release.pressed = false
	simulation._unhandled_input(t_release)

	# A skipped night evaluates survival hour by hour. Reaching zero wellbeing may
	# make one resident leave, but the remaining night must not remove another
	# resident for every hour spent at zero.
	simulation.wellbeing = 1
	simulation.last_survival_hour = -1
	simulation.clock.set_time(21 * 60)
	var citizen_count_before_zero_wellbeing_skip: int = simulation.citizens.size()
	simulation._skip_night()
	assert(simulation.citizens.size() == citizen_count_before_zero_wellbeing_skip - 1)
	for citizen in simulation.citizens:
		assert(is_instance_valid(citizen))
		assert(citizen.visible)
	root.remove_child(simulation)
	simulation.free()
	scene = null
	quit(0)
