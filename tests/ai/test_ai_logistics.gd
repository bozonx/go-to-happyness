class_name TestAILogistics
extends RefCounted

const TestAIHelpers = preload("res://tests/ai/test_ai_helpers.gd")


static func run_all() -> void:
	_test_courier_provider_assigns_unique_tasks()
	_test_courier_provider_uses_stable_citizen_tie_break()
	_test_courier_provider_uses_shared_snapshot_tasks()
	_test_courier_provider_keeps_active_task_order()
	_test_courier_provider_more_couriers_than_tasks()
	_test_courier_provider_equal_couriers_and_tasks()
	_test_courier_provider_fewer_couriers_than_tasks()
	_test_courier_provider_active_courier_excluded_from_new_tasks()
	_test_courier_provider_same_site_different_resources()
	_test_courier_provider_two_couriers_same_task_not_duplicated()
	_test_courier_dispatcher_start_task_prevents_double_assignment()
	_test_courier_dispatcher_rejects_wrong_requested_courier()
	_test_courier_dispatcher_complete_for_clears_task()
	_test_courier_dispatcher_cancel_for_requeues_task()
	_test_courier_dispatcher_cleanup_removes_invalid_tasks()
	_test_courier_dispatcher_cleanup_unassigns_dead_courier()
	_test_courier_dispatcher_publish_does_not_duplicate()
	_test_courier_dispatcher_publishes_outside_regular_work_hours()
	_test_native_courier_goal()
	_test_facade_reports_no_permanent_work()
	_test_order_reconciliation()
	_test_order_board_deduplicates_provider_output()
	_test_order_board_owns_proposal_ids()
	_test_order_board_payload_change_replaces_order()
	_test_director_reconfiguration_clears_orders()
	_test_reservations()


static func _test_courier_provider_assigns_unique_tasks() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var first := TestAIHelpers.courier_citizen(1)
	var second := TestAIHelpers.courier_citizen(2)
	var orders: Array = provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"courier.task_id") != orders[1].payload.value(&"courier.task_id"))


static func _test_courier_provider_uses_stable_citizen_tie_break() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [{&"id": &"task", &"priority": 100, &"pickup": Vector3.ZERO}]
	var first := TestAIHelpers.courier_citizen_with_tasks(1, tasks)
	var second := TestAIHelpers.courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {2: second, 1: first})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].citizen_id == 1)


static func _test_courier_provider_uses_shared_snapshot_tasks() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var first := TestAIHelpers.courier_citizen(1)
	var second := TestAIHelpers.courier_citizen(2)
	var tasks := [
		{&"id": &"shared_first", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"shared_second", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: first, 2: second})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"courier.task_id") == &"shared_first")
	assert(orders[1].payload.value(&"courier.task_id") == &"shared_second")


static func _test_courier_provider_keeps_active_task_order() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.in_progress": true,
		&"work.courier.can_start": false,
		&"work.courier.active_task_id": &"construction_42_branches",
		&"work.courier.active_pickup": Vector3(3.0, 0.0, 4.0),
		&"work.courier.active_priority": 70,
	}))
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": []}), {1: citizen})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].citizen_id == 1)
	assert(orders[0].payload.value(&"courier.task_id") == &"construction_42_branches")
	assert(orders[0].target_position == Vector3(3.0, 0.0, 4.0))


static func _test_courier_provider_more_couriers_than_tasks() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_a", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_b", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var c1 := TestAIHelpers.courier_citizen_with_tasks(1, tasks)
	var c2 := TestAIHelpers.courier_citizen_with_tasks(2, tasks)
	var c3 := TestAIHelpers.courier_citizen_with_tasks(3, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2, 3: c3})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	var assigned_ids: Array[StringName] = []
	for order in orders:
		assigned_ids.append(order.payload.value(&"courier.task_id") as StringName)
	assert(assigned_ids.has(&"task_a"))
	assert(assigned_ids.has(&"task_b"))
	assert(not assigned_ids.has(&"task_a") or assigned_ids.count(&"task_a") == 1)
	assert(not assigned_ids.has(&"task_b") or assigned_ids.count(&"task_b") == 1)


static func _test_courier_provider_equal_couriers_and_tasks() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_a", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_b", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var c1 := TestAIHelpers.courier_citizen_with_tasks(1, tasks)
	var c2 := TestAIHelpers.courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	var task_ids: Array[StringName] = []
	for order in orders:
		task_ids.append(order.payload.value(&"courier.task_id") as StringName)
	assert(task_ids.has(&"task_a"))
	assert(task_ids.has(&"task_b"))
	assert(task_ids.count(&"task_a") == 1)
	assert(task_ids.count(&"task_b") == 1)


static func _test_courier_provider_fewer_couriers_than_tasks() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_high", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_mid", &"priority": 70, &"pickup": Vector3(2.0, 0.0, 0.0)},
		{&"id": &"task_low", &"priority": 40, &"pickup": Vector3(3.0, 0.0, 0.0)},
	]
	var c1 := TestAIHelpers.courier_citizen_with_tasks(1, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].payload.value(&"courier.task_id") == &"task_high")


static func _test_courier_provider_active_courier_excluded_from_new_tasks() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_a", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_b", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var active := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.in_progress": true,
		&"work.courier.can_start": false,
		&"work.courier.active_task_id": &"construction_42_branches",
		&"work.courier.active_pickup": Vector3(5.0, 0.0, 0.0),
		&"work.courier.active_priority": 70,
	}))
	var idle := TestAIHelpers.courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: active, 2: idle})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	var active_orders := orders.filter(func(o: CitizenOrder) -> bool: return o.citizen_id == 1)
	var idle_orders := orders.filter(func(o: CitizenOrder) -> bool: return o.citizen_id == 2)
	assert(active_orders.size() == 1)
	assert(active_orders[0].payload.value(&"courier.task_id") == &"construction_42_branches")
	assert(idle_orders.size() == 1)
	assert(idle_orders[0].payload.value(&"courier.task_id") == &"task_a")


static func _test_courier_provider_same_site_different_resources() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"construction_1_branches_storage", &"priority": 70, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"construction_1_grass_storage", &"priority": 70, &"pickup": Vector3(1.0, 0.0, 0.0)},
	]
	var c1 := TestAIHelpers.courier_citizen_with_tasks(1, tasks)
	var c2 := TestAIHelpers.courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"courier.task_id") != orders[1].payload.value(&"courier.task_id"))


static func _test_courier_provider_two_couriers_same_task_not_duplicated() -> void:
	var provider: RefCounted = TestAIHelpers.CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"construction_1_branches_storage", &"priority": 70, &"pickup": Vector3(1.0, 0.0, 0.0)},
	]
	var c1 := TestAIHelpers.courier_citizen_with_tasks(1, tasks)
	var c2 := TestAIHelpers.courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2})
	var orders: Array = provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].payload.value(&"courier.task_id") == &"construction_1_branches_storage")


static func _test_courier_dispatcher_start_task_prevents_double_assignment() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	var courier_a := Citizen.new()
	courier_a.ai_id = 1
	var courier_b := Citizen.new()
	courier_b.ai_id = 2
	assert(dispatcher.start_task(courier_a, &"task_1"))
	assert(not dispatcher.start_task(courier_b, &"task_1"))
	var task: RefCounted = dispatcher.tasks[&"task_1"]
	assert(task.assigned_courier_ai_id == courier_a.ai_id)
	courier_a.free()
	courier_b.free()
	sim.free()


static func _test_courier_dispatcher_rejects_wrong_requested_courier() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"manual_task", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, {"courier_ai_id": 2})
	var wrong := Citizen.new()
	wrong.ai_id = 1
	var requested := Citizen.new()
	requested.ai_id = 2
	assert(not dispatcher.start_task(wrong, &"manual_task"))
	assert(dispatcher.start_task(requested, &"manual_task"))
	wrong.free()
	requested.free()
	sim.free()


static func _test_courier_dispatcher_complete_for_clears_task() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	var courier := Citizen.new()
	courier.ai_id = 1
	assert(dispatcher.start_task(courier, &"task_1"))
	assert(dispatcher.tasks.has(&"task_1"))
	dispatcher.complete_for(courier)
	assert(not dispatcher.tasks.has(&"task_1"))
	courier.free()
	sim.free()


static func _test_courier_dispatcher_cancel_for_requeues_task() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	sim.courier_dispatcher = dispatcher
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3.ZERO, {})
	var courier := Citizen.new()
	courier.ai_id = 1
	courier.simulation = sim
	var actuator: RefCounted = TestAIHelpers.SettlementCitizenActuatorScript.new(courier)
	assert(actuator.begin_action(&"courier_delivery", &"", AIFactSet.new({&"courier.task_id": &"task_1"})))
	var assigned_task: RefCounted = dispatcher.tasks[&"task_1"]
	assigned_task.reserved_warehouse_index = 0
	assigned_task.reserved_resource_type = "branches"
	assigned_task.reserved_amount = 2
	actuator.cancel_action()
	var task: RefCounted = dispatcher.tasks.get(&"task_1")
	assert(task != null)
	assert(task.assigned_courier_ai_id == 0)
	assert(sim.released_reservations == 1)
	assert(not task.has_reservation())
	assert(dispatcher.task_for(courier) == null)
	assert(dispatcher.available_tasks().size() == 1)
	courier.free()
	sim.free()


static func _test_courier_dispatcher_cleanup_removes_invalid_tasks() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	sim.valid_result = false
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_invalid", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	assert(dispatcher.tasks.has(&"task_invalid"))
	dispatcher.dispatch()
	assert(not dispatcher.tasks.has(&"task_invalid"))
	sim.free()


static func _test_courier_dispatcher_cleanup_unassigns_dead_courier() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	var courier := Citizen.new()
	courier.ai_id = 1
	assert(dispatcher.start_task(courier, &"task_1"))
	courier.state = Citizen.State.IDLE
	dispatcher.dispatch()
	var task: RefCounted = dispatcher.tasks.get(&"task_1")
	assert(task != null)
	assert(task.assigned_courier_ai_id == 0)
	courier.free()
	sim.free()


static func _test_courier_dispatcher_publish_does_not_duplicate() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 99, Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	assert(dispatcher.tasks.size() == 1)
	var task: RefCounted = dispatcher.tasks[&"task_1"]
	assert(task.priority == 50)
	sim.free()


static func _test_courier_dispatcher_publishes_outside_regular_work_hours() -> void:
	var sim := TestAIHelpers.FakeCourierSimulation.new()
	sim.work_time = false
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.dispatch()
	assert(sim.publish_count == 1)
	sim.free()


static func _test_native_courier_goal() -> void:
	var goal: RefCounted = TestAIHelpers.CourierDeliveryGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := TestAIHelpers.courier_citizen(1)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"courier_delivery", &"logistics.courier", 0.8, AIFactSet.new({&"courier.task_id": &"canteen_food"}))
	order.id = 24
	order.target_position = Vector3(6.0, 0.0, 0.0)
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


static func _test_facade_reports_no_permanent_work() -> void:
	var citizen := Citizen.new()
	citizen.training_role = "forestry"
	citizen.training_days_completed = 0
	citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	var facade: RefCounted = TestAIHelpers.SettlementAIWorldFacadeScript.new()
	var data: Dictionary = facade._worker_data(citizen)
	assert(data["workforce_status"] == "no_permanent_work")
	citizen.free()


static func _test_order_reconciliation() -> void:
	var board := OrderBoard.new()
	var low := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	var high := CitizenOrder.new(5, &"build", &"construction", 0.8)
	board.replace_issuer_orders(&"logistics", [low], 0.0)
	board.replace_issuer_orders(&"construction", [high], 0.0)
	assert(board.candidate_count() == 2)
	assert(board.order_for(5, 0.0) == high)
	board.replace_issuer_orders(&"construction", [], 1.0)
	assert(board.order_for(5, 1.0) == low)
	var replacement := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	board.replace_issuer_orders(&"logistics", [replacement], 2.0)
	assert(replacement.id == low.id)


static func _test_order_board_deduplicates_provider_output() -> void:
	var board := OrderBoard.new()
	var first := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	var duplicate := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	board.replace_issuer_orders(&"logistics", [first, duplicate], 0.0)
	assert(board.candidate_count() == 1)
	assert(board.order_for(5, 0.0).id == first.id)
	var competing := CitizenOrder.new(5, &"haul", &"construction", 0.8)
	board.replace_issuer_orders(&"construction", [competing], 0.0)
	assert(board.candidate_count() == 2)
	assert(board.order_for(5, 0.0) == competing)


static func _test_order_board_owns_proposal_ids() -> void:
	var board := OrderBoard.new()
	var proposal := CitizenOrder.new(1, &"gathering", &"workforce.gathering", 0.5)
	proposal.id = 9001
	board.replace_issuer_orders(&"workforce.gathering", [proposal], 0.0)
	assert(proposal.id == 1)


static func _test_order_board_payload_change_replaces_order() -> void:
	var board := OrderBoard.new()
	var order1 := CitizenOrder.new(1, &"gathering", &"workforce.gathering", 0.5, AIFactSet.new({
		&"warehouse.position": Vector3(1.0, 0.0, 0.0),
	}))
	order1.target_key = &"branch:5:5"
	var order2 := CitizenOrder.new(1, &"gathering", &"workforce.gathering", 0.5, AIFactSet.new({
		&"warehouse.position": Vector3(2.0, 0.0, 0.0),
	}))
	order2.target_key = &"branch:5:5"
	board.replace_issuer_orders(&"workforce.gathering", [order1], 0.0)
	var initial := board.order_for(1, 0.0)
	assert(initial != null)
	board.replace_issuer_orders(&"workforce.gathering", [order2], 1.0)
	var best := board.order_for(1, 1.0)
	assert(best != null)
	assert(best.id != initial.id)


static func _test_director_reconfiguration_clears_orders() -> void:
	var director := SettlementDirector.new()
	director.order_board.replace_issuer_orders(&"jobs", [CitizenOrder.new(1, &"work", &"jobs", 1.0)], 0.0)
	assert(director.order_board.candidate_count() == 1)
	director.configure([])
	assert(director.order_board.candidate_count() == 0)


static func _test_reservations() -> void:
	var ledger := ReservationLedger.new()
	assert(ledger.claim(&"tree_7", 1, 0.0, 5.0))
	assert(not ledger.claim(&"tree_7", 2, 0.0, 5.0))
	assert(ledger.claim(&"tree_7", 1, 1.0, 5.0))
	assert(ledger.owner_of(&"tree_7", 1.0) == 1)
	assert(ledger.is_available_for(&"tree_7", 1, 1.0))
	assert(not ledger.is_available_for(&"tree_7", 2, 1.0))
	ledger.release(&"tree_7", 2)
	assert(ledger.owner_of(&"tree_7", 1.0) == 1)
	ledger.release(&"tree_7", 1)
	assert(ledger.claim(&"tree_7", 2, 2.0, 5.0))
	assert(ledger.owner_of(&"tree_7", 7.0) == 0)
	assert(ledger.active_count() == 0)
