class_name TestAIWorkProviders
extends RefCounted

const TestAIHelpers = preload("res://tests/ai/test_ai_helpers.gd")


static func run_all() -> void:
	_test_forestry_provider_assigns_unique_stable_targets()
	_test_native_forestry_goal()
	_test_farming_provider_keeps_active_cycle()
	_test_native_farming_goal()
	_test_farming_actuator_completes_after_courier_pickup()
	_test_construction_provider_keeps_active_cycle()
	_test_native_construction_goal()
	_test_construction_actuator()
	_test_construction_work_step_times_out_on_stuck_action()
	_test_gathering_provider_assigns_unique_stable_sources()
	_test_gathering_provider_swaps_invalid_assignments_without_gap()
	_test_gathering_provider_protects_active_assignment()
	_test_gathering_provider_scales_across_many_targets_and_warehouses()
	_test_gathering_provider_refreshes_moving_source()
	_test_native_gathering_goal()
	_test_gathering_provider_prefers_access_position()
	_test_gather_food_does_not_fallback_to_other_resources()
	_test_excavation_provider_assigns_unique_stable_sites()
	_test_native_excavation_goal()
	_test_excavation_actuator_completes_after_courier_pickup()
	_test_service_provider_keeps_active_workplace()
	_test_native_service_goal()
	_test_service_actuator()
	_test_factory_provider_keeps_active_station()
	_test_native_factory_goal()
	_test_factory_actuator()
	_test_daily_player_order_provider_keeps_gathering_assignment()
	_test_daily_player_order_provider_publishes_construction_order()
	_test_daily_player_order_provider_publishes_cleaning_order()
	_test_native_cleaning_goal()
	_test_register_provider_keeps_order_while_registering()
	_test_register_provider_supports_tent_era_couriers()
	_test_register_provider_distributes_workplaces_by_capacity()
	_test_production_sleep_actuator()


static func _test_forestry_provider_assigns_unique_stable_targets() -> void:
	var provider: RefCounted = TestAIHelpers.ForestryOrderProviderScript.new()
	var first := TestAIHelpers.forestry_citizen(1, false)
	var second := TestAIHelpers.forestry_citizen(2, false)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	assert(orders[0].target_position != orders[1].target_position)
	var first_target: Vector3 = orders[0].target_position
	var second_target: Vector3 = orders[1].target_position
	var active_snapshot := WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.forestry_citizen(1, true),
		2: TestAIHelpers.forestry_citizen(2, true),
	})
	var active_orders: Array = provider.collect_orders(active_snapshot)
	assert(active_orders.size() == 2)
	assert(active_orders[0].target_position == first_target)
	assert(active_orders[1].target_position == second_target)
	var mixed_snapshot := WorldSnapshot.new(3, 2.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.forestry_citizen(1, false),
		2: TestAIHelpers.forestry_citizen(2, true),
	})
	var mixed_orders: Array = provider.collect_orders(mixed_snapshot)
	assert(mixed_orders.size() == 2)
	assert(mixed_orders[0].target_position != mixed_orders[1].target_position)


static func _test_native_forestry_goal() -> void:
	var goal: RefCounted = TestAIHelpers.ForestryGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.forestry_citizen(1, false)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.forestry_order(1, Vector3(3.0, 0.0, 0.0), &"tree:3:0")
	order.id = 17
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3(2.5, 0.0, 0.0))
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"forestry")
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 0)


static func _test_farming_provider_keeps_active_cycle() -> void:
	var provider: RefCounted = TestAIHelpers.FarmingOrderProviderScript.new()
	var ready := TestAIHelpers.farming_citizen(1, false, true)
	var inactive := TestAIHelpers.farming_citizen(2, false, false)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].citizen_id == 1 and orders[0].kind == &"farming")
	var active := TestAIHelpers.farming_citizen(1, true, false)
	var active_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].target_position == orders[0].target_position)


static func _test_native_farming_goal() -> void:
	var goal: RefCounted = TestAIHelpers.FarmingGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.farming_citizen(1, false, true)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.farming_order(1, Vector3(4.0, 0.0, 0.0))
	order.id = 18
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3(4.0, 0.0, 0.0))
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"farming")
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


static func _test_farming_actuator_completes_after_courier_pickup() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 18
	citizen.permanent_role = "farming"
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(citizen)
	assert(actuator.begin_action(&"farming", &"", AIFactSet.new({
		&"workplace.position": Vector3.ZERO,
		&"warehouse.position": Vector3(2.0, 0.0, 0.0),
	})))
	assert(citizen.state == Citizen.State.TO_TREE)
	citizen.state = Citizen.State.WAITING_COURIER
	citizen.register_pending_resource("food", 1)
	citizen.task_timer.start(0.0)
	citizen._process_courier_wait(0.1)
	assert(citizen.state == Citizen.State.WAITING_COURIER)
	assert(int(citizen.take_pending_resource().get("amount", 0)) == 1)
	assert(citizen.state == Citizen.State.IDLE)
	assert(citizen.active_role.is_empty())
	assert(actuator.action_status() == CitizenActuator.ActionStatus.SUCCEEDED)
	citizen.free()


static func _test_construction_provider_keeps_active_cycle() -> void:
	var provider: RefCounted = TestAIHelpers.ConstructionOrderProviderScript.new()
	var ready := TestAIHelpers.construction_citizen(1, false, true, &"construction", 41)
	var inactive := TestAIHelpers.construction_citizen(2, false, false, &"construction", 42)
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"construction" and orders[0].target_key == &"construction:41")
	var active := TestAIHelpers.construction_citizen(1, true, false, &"demolition", 43)
	var active_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].kind == &"demolition" and active_orders[0].target_key == &"demolition:43")


static func _test_native_construction_goal() -> void:
	var goal: RefCounted = TestAIHelpers.ConstructionGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.construction_citizen(1, false, true, &"construction", 41)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.construction_order(1, &"construction", 41)
	order.id = 19
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3(5.0, 0.0, 0.0))
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"construction")
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


static func _test_construction_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 19
	var target := Node3D.new()
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(citizen, func(_key: StringName) -> Node3D: return target)
	assert(actuator.begin_action(&"construction", &"construction:5"))
	assert(citizen.state == Citizen.State.CONSTRUCTING and citizen.active_role == "construction")
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	assert(actuator.begin_action(&"demolition", &"demolition:5"))
	assert(citizen.state == Citizen.State.CONSTRUCTING and citizen.active_role == "demolition")
	target.free()
	citizen.free()


static func _test_construction_work_step_times_out_on_stuck_action() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	actuator.next_action_status = CitizenActuator.ActionStatus.RUNNING
	var order := CitizenOrder.new(1, &"construction", &"test", 1.0, AIFactSet.new({
		&"work.construction.mode": &"construction",
	}))
	order.target_key = &"construction:5"
	order.target_position = Vector3(5.0, 0.0, 0.0)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: CitizenSnapshot.new(1)})
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, order)
	var step: RefCounted = TestAIHelpers.ConstructionWorkStepScript.new()
	step._enter(context)
	assert(step._tick(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(step._tick(context, TestAIHelpers.ConstructionWorkStepScript.MAX_STEP_SECONDS + 1.0) == BehaviorStep.Status.FAILURE)
	assert(actuator.cancel_action_count == 1)


static func _test_gathering_provider_assigns_unique_stable_sources() -> void:
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var first := TestAIHelpers.gathering_citizen(1, false)
	var second := TestAIHelpers.gathering_citizen(2, false)
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].target_position != orders[1].target_position)
	var active_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.gathering_citizen(1, true),
		2: TestAIHelpers.gathering_citizen(2, true),
	}))
	assert(active_orders.size() == 2)
	assert(active_orders[0].target_position == orders[0].target_position)
	assert(active_orders[1].target_position == orders[1].target_position)


static func _test_gathering_provider_swaps_invalid_assignments_without_gap() -> void:
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var initial: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.gathering_citizen(1, false),
		2: TestAIHelpers.gathering_citizen(2, false),
	}))
	assert(initial.size() == 2)
	var first_target := initial[0].payload.value(&"work.source_id") as StringName
	var second_target := initial[1].payload.value(&"work.source_id") as StringName
	var swapped: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.gathering_citizen_with_candidates(1, [TestAIHelpers.gathering_candidate(second_target)]),
		2: TestAIHelpers.gathering_citizen_with_candidates(2, [TestAIHelpers.gathering_candidate(first_target)]),
	}))
	assert(swapped.size() == 2)
	assert(swapped[0].payload.value(&"work.source_id") == second_target)
	assert(swapped[1].payload.value(&"work.source_id") == first_target)


static func _test_gathering_provider_protects_active_assignment() -> void:
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var initial: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.gathering_citizen(1, false),
		2: TestAIHelpers.gathering_citizen(2, false),
	}))
	assert(initial.size() == 2)
	var active_target := initial[1].payload.value(&"work.source_id") as StringName
	var blocked_worker := TestAIHelpers.gathering_citizen_with_candidates(1, [TestAIHelpers.gathering_candidate(active_target)])
	var active_facts := TestAIHelpers.gathering_citizen_with_candidates(2, []).facts.to_dictionary()
	active_facts[&"work.gathering.in_progress"] = true
	var active_worker := CitizenSnapshot.new(2, Vector3(2.0, 0.0, 0.0), false, true, AIFactSet.new(active_facts))
	var orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: blocked_worker,
		2: active_worker,
	}))
	assert(orders.size() == 1)
	assert(orders[0].citizen_id == 2)
	assert(orders[0].payload.value(&"work.source_id") == active_target)


static func _test_gathering_provider_scales_across_many_targets_and_warehouses() -> void:
	const WORKER_COUNT := 24
	const TARGET_COUNT := 48
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var candidates: Array[Dictionary] = []
	for target_index in TARGET_COUNT:
		var x := float(target_index + 1)
		candidates.append({
			&"id": StringName("branch:%d:0" % target_index),
			&"resource_type": "branches",
			&"position": Vector3(x, 0.0, 0.0),
			&"access": Vector3(x, 0.0, 0.0),
			&"route_cost": x,
		})
	var expected_targets: Dictionary = {}
	for publication in 12:
		var citizens: Dictionary = {}
		for citizen_id in range(1, WORKER_COUNT + 1):
			var warehouse := Vector3(80.0 if citizen_id % 2 == 0 else -80.0, 0.0, 0.0)
			citizens[citizen_id] = CitizenSnapshot.new(citizen_id, Vector3.ZERO, false, true, AIFactSet.new({
				&"work.gathering.worker": true,
				&"work.gathering.in_progress": false,
				&"work.gathering.can_start": true,
				&"work.gathering.role": &"gather_branches",
				&"work.gathering.warehouse_position": warehouse,
				&"work.gathering.candidates": candidates,
			}))
		var orders: Array = provider.collect_orders(WorldSnapshot.new(publication + 1, float(publication), 0.0, AIFactSet.new(), citizens))
		assert(orders.size() == WORKER_COUNT)
		var unique_targets: Dictionary = {}
		for order in orders:
			var target_id := order.payload.value(&"work.source_id") as StringName
			assert(not unique_targets.has(target_id))
			unique_targets[target_id] = true
			var expected_warehouse := Vector3(80.0 if order.citizen_id % 2 == 0 else -80.0, 0.0, 0.0)
			assert(order.payload.value(&"warehouse.position") == expected_warehouse)
			if publication == 0:
				expected_targets[order.citizen_id] = target_id
			else:
				assert(expected_targets[order.citizen_id] == target_id)


static func _test_gathering_provider_refreshes_moving_source() -> void:
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var initial := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": false,
		&"work.gathering.can_start": true,
		&"work.gathering.role": &"gather_food",
		&"work.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
		&"work.gathering.candidates": [{&"id": &"rabbit:2:0", &"resource_type": "food", &"position": Vector3(2.0, 0.0, 0.0), &"access": Vector3(2.0, 0.0, 0.0)}],
	}))
	var first_orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: initial}))
	assert(first_orders.size() == 1)
	assert(first_orders[0].target_position == Vector3(2.0, 0.0, 0.0))
	var moved := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": false,
		&"work.gathering.can_start": true,
		&"work.gathering.role": &"gather_food",
		&"work.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
		&"work.gathering.candidates": [{&"id": &"rabbit:2:0", &"resource_type": "food", &"position": Vector3(5.0, 0.0, 0.0), &"access": Vector3(5.0, 0.0, 0.0)}],
	}))
	var refreshed_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: moved}))
	assert(refreshed_orders.size() == 1)
	assert(refreshed_orders[0].target_position == Vector3(5.0, 0.0, 0.0))


static func _test_native_gathering_goal() -> void:
	var goal: RefCounted = TestAIHelpers.GatheringGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.gathering_citizen(1, false)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.gathering_order(1, Vector3(3.0, 0.0, 0.0), &"branch:3:0")
	order.id = 20
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3(2.5, 0.0, 0.0))
	assert(actuator.action_start_count == 0)
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"gathering.source", &"branch:3:0"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(snapshot.reservations.owner_of([&"gathering.source", &"branch:3:0"], 0.0) == 0)


static func _test_gathering_provider_prefers_access_position() -> void:
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": false,
		&"work.gathering.role": &"gather_branches",
		&"work.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
		&"work.gathering.candidates": [
			{&"id": &"branch:10:0", &"resource_type": "branches", &"position": Vector3(10.0, 0.0, 0.0), &"access": Vector3(9.5, 0.0, 0.0)},
			{&"id": &"branch:2:0", &"resource_type": "branches", &"position": Vector3(2.0, 0.0, 0.0), &"access": Vector3(50.0, 0.0, 0.0)},
		],
	}))
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.gathering.targets": []}), {1: citizen})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].payload.value(&"work.source_id", &"") == &"branch:10:0")


static func _test_gather_food_does_not_fallback_to_other_resources() -> void:
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": false,
		&"work.gathering.can_start": true,
		&"work.gathering.role": &"gather_food",
		&"work.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
		&"work.gathering.candidates": [],
	}))
	var global_non_food := [{&"id": &"branch:1:0", &"resource_type": "branches", &"position": Vector3.ONE, &"access": Vector3.ONE}]
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.gathering.targets": global_non_food}), {1: citizen})
	assert(provider.collect_orders(snapshot).is_empty())


static func _test_excavation_provider_assigns_unique_stable_sites() -> void:
	var provider: RefCounted = TestAIHelpers.ExcavationOrderProviderScript.new()
	var first := TestAIHelpers.excavation_citizen(1, false)
	var second := TestAIHelpers.excavation_citizen(2, false)
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].target_key != orders[1].target_key)
	var active_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: TestAIHelpers.excavation_citizen(1, true),
		2: TestAIHelpers.excavation_citizen(2, true),
	}))
	assert(active_orders.size() == 2)
	assert(active_orders[0].target_key == orders[0].target_key)
	assert(active_orders[1].target_key == orders[1].target_key)


static func _test_native_excavation_goal() -> void:
	var goal: RefCounted = TestAIHelpers.ExcavationGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.excavation_citizen(1, false)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.excavation_order(1, 61, &"dig:61")
	order.id = 21
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.action_start_count == 0)
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"excavation.site", &"dig:61"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(snapshot.reservations.owner_of([&"excavation.site", &"dig:61"], 0.0) == 0)


static func _test_excavation_actuator_completes_after_courier_pickup() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 21
	citizen.permanent_role = "excavation"
	var target := Node3D.new()
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(citizen, func(_key: StringName) -> Node3D: return target)
	assert(actuator.begin_action(&"excavation", &"dig:3:0"))
	citizen.state = Citizen.State.WAITING_COURIER
	citizen.register_pending_resource("soil", 1)
	citizen.task_timer.start(0.0)
	citizen._process_courier_wait(0.1)
	assert(citizen.state == Citizen.State.WAITING_COURIER)
	assert(int(citizen.take_pending_resource().get("amount", 0)) == 1)
	assert(citizen.state == Citizen.State.IDLE and citizen.active_role.is_empty())
	assert(citizen.assigned_dig_site == null)
	assert(actuator.action_status() == CitizenActuator.ActionStatus.SUCCEEDED)
	target.free()
	citizen.free()


static func _test_service_provider_keeps_active_workplace() -> void:
	var provider: RefCounted = TestAIHelpers.ServiceWorkOrderProviderScript.new()
	var ready := TestAIHelpers.service_citizen(1, false, true, &"cook")
	var inactive := TestAIHelpers.service_citizen(2, false, false, &"teacher")
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"service_work")
	assert(orders[0].payload.value(&"work.service.role") == &"cook")
	var active := TestAIHelpers.service_citizen(1, true, false, &"cook")
	var active_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].target_position == Vector3(5.0, 0.0, 0.0))


static func _test_native_service_goal() -> void:
	var goal: RefCounted = TestAIHelpers.ServiceWorkGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.service_citizen(1, false, true, &"cook")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.service_order(1, &"cook")
	order.id = 22
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"service_work")
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


static func _test_service_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 22
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(citizen)
	assert(actuator.begin_action(&"cook", &"", AIFactSet.new({&"workplace.position": Vector3.ZERO})))
	assert(citizen.state == Citizen.State.TO_CANTEEN_WORK)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	citizen.free()


static func _test_factory_provider_keeps_active_station() -> void:
	var provider: RefCounted = TestAIHelpers.FactoryWorkOrderProviderScript.new()
	var ready := TestAIHelpers.factory_citizen(1, false, true, &"factory_work")
	var inactive := TestAIHelpers.factory_citizen(2, false, false, &"engineering")
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"factory_work" and orders[0].target_key == &"factory:7")
	var active := TestAIHelpers.factory_citizen(1, true, false, &"factory_work")
	var active_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].payload.value(&"factory.role") == &"factory_work")


static func _test_native_factory_goal() -> void:
	var goal: RefCounted = TestAIHelpers.FactoryWorkGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.factory_citizen(1, false, true, &"engineering")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.factory_order(1, &"engineering")
	order.id = 23
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"factory_work")
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


static func _test_factory_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 23
	var factory := Node3D.new()
	factory.set_meta("service_position", Vector3.ZERO)
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(citizen, func(_key: StringName) -> Node3D: return factory)
	assert(actuator.begin_action(&"factory_work", &"factory:7", AIFactSet.new({&"factory.role": &"engineering"})))
	assert(citizen.state == Citizen.State.TO_FACTORY and citizen.active_role == "engineering")
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	factory.free()
	citizen.free()


static func _test_daily_player_order_provider_keeps_gathering_assignment() -> void:
	var provider: RefCounted = TestAIHelpers.DailyPlayerOrderProviderScript.new()
	var source := {
		&"id": &"branch:4:0",
		&"resource_type": "branches",
		&"position": Vector3(4.0, 0.0, 0.0),
		&"access": Vector3(3.5, 0.0, 0.0),
	}
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "gather_branches",
		&"daily.order.workday_id": 3,
		&"daily.order.expires_at": 42.0,
		&"daily.gathering.can_start": true,
		&"daily.gathering.in_progress": false,
		&"daily.gathering.candidates": [source],
		&"daily.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	var order: CitizenOrder = orders[0]
	assert(order.kind == &"gathering")
	assert(order.issuer == &"player")
	assert(order.workday_id == 3)
	assert(is_equal_approx(order.expires_at, 42.0))
	assert(order.payload.value(&"work.source_id") == &"branch:4:0")
	assert(order.payload.value(&"resource.type") == "branches")
	assert(order.target_position == Vector3(4.0, 0.0, 0.0))

	var running := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "gather_branches",
		&"daily.order.workday_id": 3,
		&"daily.order.expires_at": 42.0,
		&"daily.gathering.in_progress": true,
		&"daily.gathering.can_start": false,
	}))
	var continued: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: running}))
	assert(continued.size() == 1)
	assert(continued[0].payload.to_dictionary() == order.payload.to_dictionary())

	var inactive := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": false,
		&"daily.order.role": "gather_branches",
	}))
	assert(provider.collect_orders(WorldSnapshot.new(3, 2.0, 0.0, AIFactSet.new(), {1: inactive})).is_empty())


static func _test_daily_player_order_provider_publishes_construction_order() -> void:
	var provider: RefCounted = TestAIHelpers.DailyPlayerOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "construction",
		&"daily.order.workday_id": 5,
		&"daily.order.expires_at": 99.0,
		&"daily.construction.can_start": true,
		&"daily.construction.mode": &"construction",
		&"daily.construction.target_key": &"construction:1:2",
		&"daily.construction.position": Vector3(1.0, 0.0, 2.0),
	}))
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"construction")
	assert(orders[0].issuer == &"player")
	assert(orders[0].workday_id == 5)
	assert(orders[0].target_key == &"construction:1:2")
	assert(orders[0].target_position == Vector3(1.0, 0.0, 2.0))


static func _test_daily_player_order_provider_publishes_cleaning_order() -> void:
	var provider: RefCounted = TestAIHelpers.DailyPlayerOrderProviderScript.new()
	var citizen := TestAIHelpers.cleaning_citizen(1, false)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	var order: CitizenOrder = orders[0]
	assert(order.kind == &"cleaning")
	assert(order.issuer == &"player")
	assert(order.workday_id == 3)
	assert(is_equal_approx(order.expires_at, 42.0))
	assert(order.payload.value(&"work.source_id") == &"pile:3:0:branches")
	assert(order.payload.value(&"resource.type") == "branches")
	assert(order.target_position == Vector3(3.0, 0.0, 0.0))

	var running := TestAIHelpers.cleaning_citizen(1, true)
	var continued: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: running}))
	assert(continued.size() == 1)
	assert(continued[0].payload.to_dictionary() == order.payload.to_dictionary())

	var inactive := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": false,
		&"daily.order.role": "cleaning",
	}))
	assert(provider.collect_orders(WorldSnapshot.new(3, 2.0, 0.0, AIFactSet.new(), {1: inactive})).is_empty())


static func _test_native_cleaning_goal() -> void:
	var goal: RefCounted = TestAIHelpers.CleaningGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.cleaning_citizen(1, false)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := TestAIHelpers.cleaning_order(1, Vector3(3.0, 0.0, 0.0), &"pile:3:0:branches")
	order.id = 30
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3(3.0, 0.0, 0.0))
	assert(actuator.action_start_count == 0)
	actuator.arrived_flag = true
	brain.tick(snapshot, order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"cleaning.pile", &"pile:3:0:branches"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(snapshot.reservations.owner_of([&"cleaning.pile", &"pile:3:0:branches"], 0.0) == 0)


static func _test_register_provider_keeps_order_while_registering() -> void:
	var provider: RefCounted = TestAIHelpers.WorkforceOrderProviderScript.new()
	var settlement := AIFactSet.new({
		&"workforce.world_data": {"officer_available": true, "assigned_roles": {}, "forestry_jobs": 1, "warehouses": 1, "trees": 1},
		&"workforce.employment_center_position": Vector3(2.0, 0.0, 0.0),
		&"workforce.role_employers": {
			"forestry": {"position": Vector3(6.0, 0.0, 0.0), "target_key": &"building:6:0"},
		},
	})
	var unregistered := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "unregistered", "skills": {"forestry": 1.0}},
	}))
	var initial_orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, settlement, {1: unregistered}))
	assert(initial_orders.size() == 1)
	assert(initial_orders[0].kind == &"register")
	assert(is_equal_approx(initial_orders[0].priority, 0.74))

	var registering := CitizenSnapshot.new(1, Vector3(1.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "registering", "pending_employment_role": "forestry"},
		&"workforce.pending_workplace_key": &"building:6:0",
		&"workforce.pending_workplace_position": Vector3(6.0, 0.0, 0.0),
	}))
	var continued_orders: Array = provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, settlement, {1: registering}))
	assert(continued_orders.size() == 1)
	assert(continued_orders[0].kind == &"register")
	assert(continued_orders[0].payload.value(&"workplace.role") == "forestry")
	assert(continued_orders[0].target_position == initial_orders[0].target_position)


static func _test_register_provider_supports_tent_era_couriers() -> void:
	var provider: RefCounted = TestAIHelpers.WorkforceOrderProviderScript.new()
	var settlement := AIFactSet.new({
		&"workforce.world_data": {"officer_available": true, "assigned_roles": {}, "courier_jobs": 1},
		&"workforce.employment_center_position": Vector3(2.0, 0.0, 0.0),
		&"workforce.role_employers": {
			"courier": {"position": Vector3(2.0, 0.0, 0.0), "target_key": &""},
		},
	})
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "no_permanent_work", "skills": {}},
	}))
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, settlement, {1: citizen}))
	assert(orders.size() == 1)
	assert(orders[0].payload.value(&"workplace.role") == "courier")
	assert(orders[0].payload.value(&"workplace.node_key") == &"")


static func _test_register_provider_distributes_workplaces_by_capacity() -> void:
	var provider: RefCounted = TestAIHelpers.WorkforceOrderProviderScript.new()
	var settlement := AIFactSet.new({
		&"workforce.world_data": {
			"officer_available": true, "assigned_roles": {}, "forestry_jobs": 2,
			"warehouses": 1, "trees": 2,
		},
		&"workforce.employment_center_position": Vector3(2.0, 0.0, 0.0),
		&"workforce.role_employers": {
			"forestry": [
				{"position": Vector3(6.0, 0.0, 0.0), "target_key": &"building:6:0", "available_slots": 1},
				{"position": Vector3(10.0, 0.0, 0.0), "target_key": &"building:10:0", "available_slots": 1},
			],
		},
	})
	var first := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "unregistered", "skills": {"forestry": 1.0}},
	}))
	var second := CitizenSnapshot.new(2, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "unregistered", "skills": {"forestry": 1.0}},
	}))
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, settlement, {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"workplace.node_key") != orders[1].payload.value(&"workplace.node_key"))


static func _test_production_sleep_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 17
	var home := Node3D.new()
	citizen.assign_home(home)
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(citizen)
	assert(actuator.is_valid())
	assert(actuator.begin_action(&"sleep"))
	assert(citizen.state == Citizen.State.TO_HOME)
	assert(actuator.action_status() == CitizenActuator.ActionStatus.RUNNING)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	assert(actuator.begin_action(&"eat", &"", AIFactSet.new({&"target.position": Vector3.ZERO})))
	assert(citizen.state == Citizen.State.TO_CANTEEN)
	citizen.state = Citizen.State.IDLE
	assert(actuator.action_status() == CitizenActuator.ActionStatus.SUCCEEDED)
	actuator.cancel_action()
	assert(actuator.begin_action(&"relieve", &"", AIFactSet.new({
		&"target.position": Vector3.ZERO,
		&"target.kind": &"tree",
	})))
	assert(citizen.state == Citizen.State.TO_BUSH)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	assert(not citizen.has_toilet_resume_state)
	var queue_release_calls := [0]
	citizen.queue_release_notifier = func(_actor: Citizen) -> void: queue_release_calls[0] += 1
	citizen.state = Citizen.State.TO_TREE
	citizen.go_to_relief(Vector3.ONE, &"tree")
	citizen._resume_after_toilet()
	assert(citizen.state == Citizen.State.TO_TREE)
	assert(queue_release_calls[0] == 1)
	citizen.state = Citizen.State.TO_TREE
	citizen.go_to_relief(Vector3.ONE, &"tree")
	citizen.set_player_controlled(true)
	assert(citizen.state == Citizen.State.IDLE and not citizen.has_toilet_resume_state)
	citizen.set_player_controlled(false)
	assert(actuator.begin_action(&"rest", &"", AIFactSet.new({
		&"target.position": Vector3.ZERO,
		&"action.duration": 2.0,
	})))
	assert(citizen.state == Citizen.State.TO_PARK)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	home.free()
	citizen.free()
