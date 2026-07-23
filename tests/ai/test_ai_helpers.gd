class_name TestAIHelpers
extends RefCounted

const GrassSourceRecord = preload("res://game/features/production/domain/grass_source_record.gd")
const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
const ReturnHomeWhenIdleGoalScript = preload("res://game/features/decision/domain/goals/return_home_when_idle_goal.gd")
const MealGoalScript = preload("res://game/features/decision/domain/goals/meal_goal.gd")
const ToiletGoalScript = preload("res://game/features/decision/domain/goals/toilet_goal.gd")
const RestGoalScript = preload("res://game/features/decision/domain/goals/rest_goal.gd")
const ForestryGoalScript = preload("res://game/features/decision/domain/goals/forestry_goal.gd")
const ForestryOrderProviderScript = preload("res://game/features/decision/application/forestry_order_provider.gd")
const ForestryWorkStepScript = preload("res://game/features/decision/domain/behavior/forestry_work_step.gd")
const FarmingGoalScript = preload("res://game/features/decision/domain/goals/farming_goal.gd")
const FarmingOrderProviderScript = preload("res://game/features/decision/application/farming_order_provider.gd")
const ConstructionGoalScript = preload("res://game/features/decision/domain/goals/construction_goal.gd")
const ConstructionOrderProviderScript = preload("res://game/features/decision/application/construction_order_provider.gd")
const ConstructionWorkStepScript = preload("res://game/features/decision/domain/behavior/construction_work_step.gd")
const GatheringGoalScript = preload("res://game/features/decision/domain/goals/gathering_goal.gd")
const GatheringOrderProviderScript = preload("res://game/features/decision/application/gathering_order_provider.gd")
const CleaningGoalScript = preload("res://game/features/decision/domain/goals/cleaning_goal.gd")
const ExcavationGoalScript = preload("res://game/features/decision/domain/goals/excavation_goal.gd")
const ExcavationOrderProviderScript = preload("res://game/features/decision/application/excavation_order_provider.gd")
const ServiceWorkGoalScript = preload("res://game/features/decision/domain/goals/service_work_goal.gd")
const ServiceWorkOrderProviderScript = preload("res://game/features/decision/application/service_work_order_provider.gd")
const FactoryWorkGoalScript = preload("res://game/features/decision/domain/goals/factory_work_goal.gd")
const FactoryWorkOrderProviderScript = preload("res://game/features/decision/application/factory_work_order_provider.gd")
const CourierDeliveryGoalScript = preload("res://game/features/decision/domain/goals/courier_delivery_goal.gd")
const CourierDeliveryOrderProviderScript = preload("res://game/features/decision/application/courier_delivery_order_provider.gd")
const SettlementCitizenActuatorScript = preload("res://game/features/decision/presentation/settlement_citizen_actuator.gd")
const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")
const RelaxAtPositionStepScript = preload("res://game/features/decision/domain/behavior/relax_at_position_step.gd")
const WorkforceOrderProviderScript = preload("res://game/features/decision/application/workforce_order_provider.gd")
const DailyPlayerOrderProviderScript = preload("res://game/features/decision/application/daily_player_order_provider.gd")
const SettlementAIWorldFacadeScript = preload("res://game/features/decision/presentation/settlement_ai_world_facade.gd")


class ScriptedStep extends BehaviorStep:
	var statuses: Array[BehaviorStep.Status]
	var ticks := 0
	var suspends := 0
	var resumes := 0
	var cancels := 0
	var finishes := 0
	var final_status := Status.RUNNING

	func _init(next_statuses: Array[BehaviorStep.Status]) -> void:
		statuses = next_statuses.duplicate()

	func _tick(_context: BehaviorContext, _delta: float) -> Status:
		var index := mini(ticks, statuses.size() - 1)
		ticks += 1
		return statuses[index]

	func _suspend(_context: BehaviorContext) -> void:
		suspends += 1

	func _resume(_context: BehaviorContext) -> void:
		resumes += 1

	func _cancel(_context: BehaviorContext) -> void:
		cancels += 1

	func _finish(_context: BehaviorContext, status: Status) -> void:
		finishes += 1
		final_status = status


class FailingStep extends BehaviorStep:
	var reason: FailureReason

	func _init(next_reason: FailureReason) -> void:
		reason = next_reason

	func _tick(_context: BehaviorContext, _delta: float) -> Status:
		return fail(reason)


class FixedGoal extends AICitizenGoal:
	var utility: float

	func _init(next_id: StringName, next_utility: float) -> void:
		super(next_id)
		utility = next_utility

	func score(
		_snapshot: WorldSnapshot,
		_citizen: CitizenSnapshot,
		_order: CitizenOrder,
		_blackboard: AIBlackboard
	) -> float:
		return utility


class ScriptedGoal extends FixedGoal:
	var statuses: Array[BehaviorStep.Status]
	var build_count := 0
	var last_step: ScriptedStep

	func _init(
		next_id: StringName,
		next_utility: float,
		next_statuses: Array[BehaviorStep.Status]
	) -> void:
		super(next_id, next_utility)
		statuses = next_statuses.duplicate()

	func build_task(
		_snapshot: WorldSnapshot,
		_citizen: CitizenSnapshot,
		_order: CitizenOrder,
		_blackboard: AIBlackboard
	) -> BehaviorTask:
		build_count += 1
		last_step = ScriptedStep.new(statuses)
		return BehaviorTask.new(id, last_step)


class NullTaskGoal extends FixedGoal:
	func build_task(
		_snapshot: WorldSnapshot,
		_citizen: CitizenSnapshot,
		_order: CitizenOrder,
		_blackboard: AIBlackboard
	) -> BehaviorTask:
		return null


class FakeActuator extends CitizenActuator:
	var stop_count := 0
	var cancel_action_count := 0
	var action_start_count := 0
	var move_to_count := 0
	var move_to_destination := Vector3.INF
	var move_started := false
	var arrived_flag := false
	var movement_failed_flag := false
	var next_movement_failure_reason := BehaviorStep.FailureReason.MOVEMENT_FAILED
	var next_action_failure_reason := BehaviorStep.FailureReason.UNKNOWN
	var next_action_status := ActionStatus.RUNNING

	func _init(next_citizen_id: int = 1) -> void:
		citizen_id = next_citizen_id

	func stop() -> void:
		stop_count += 1
		move_started = false
		arrived_flag = false

	func cancel_action() -> void:
		cancel_action_count += 1

	func move_to(destination: Vector3, _arrival_radius: float = 0.25) -> bool:
		move_to_count += 1
		move_to_destination = destination
		move_started = true
		arrived_flag = false
		movement_failed_flag = false
		return true

	func has_arrived() -> bool:
		return arrived_flag

	func movement_failed() -> bool:
		return movement_failed_flag

	func movement_failure_reason() -> BehaviorStep.FailureReason:
		return next_movement_failure_reason

	func begin_action(
		action: StringName,
		_target_key: StringName = &"",
		_payload: AIFactSet = null
	) -> bool:
		action_start_count += 1
		return action in [&"sleep", &"eat", &"relieve", &"rest", &"relax", &"register", &"forestry", &"farming", &"construction", &"demolition", &"gathering", &"cleaning", &"excavation", &"cook", &"teacher", &"seller", &"official", &"craftsman", &"factory_work", &"courier_delivery"]

	func action_status() -> ActionStatus:
		return next_action_status

	func action_failure_reason() -> BehaviorStep.FailureReason:
		return next_action_failure_reason


class FakeFacade extends AIWorldFacade:
	var citizens: Dictionary
	var simulation_seconds := 0.0
	var game_minutes := 0.0

	func _init(next_citizens: Dictionary) -> void:
		citizens = next_citizens

	func capture(sequence: int) -> WorldSnapshot:
		return WorldSnapshot.new(
			sequence,
			simulation_seconds,
			game_minutes,
			AIFactSet.new(),
			citizens
		)


class FakeRouteCacheSimulation extends Node:
	var nav_grid := NavGrid.new()
	var runtime_seconds := 0.0

	func _init() -> void:
		nav_grid.configure(1.0, 10)

	func _cell_from_position(position: Vector3) -> Vector2i:
		return nav_grid.cell_from_position(position)


class NullFacade extends AIWorldFacade:
	func capture(_sequence: int) -> WorldSnapshot:
		return null


class FakeSettlement extends RefCounted:
	func construction_gloves_available() -> bool:
		return false


class FakeGatheringSimulation extends Node:
	var settlement := FakeSettlement.new()
	var grass_sources: Dictionary = {}
	var consumed_count := 0

	func fire_smoke_work_multiplier(_position_on_board: Vector3) -> float:
		return 1.0

	func _cell_from_position(position: Vector3) -> Vector2i:
		return Vector2i(floori(position.x), floori(position.z))

	func _consume_grass_source(position: Vector3) -> int:
		var cell := _cell_from_position(position)
		if not grass_sources.has(cell):
			return 0
		var source: GrassSourceRecord = grass_sources[cell]
		if source.remaining <= 0:
			return 0
		consumed_count += 1
		source.remaining -= 1
		if source.remaining == 0:
			grass_sources.erase(cell)
		return 1


class FakeCourierSimulation extends Node:
	var citizens: Array[Citizen] = []
	var courier_dispatcher: CourierDispatcher
	var warehouse_positions: Array[Vector3] = [Vector3.ZERO]
	var runtime_seconds := 0.0
	var valid_result := true
	var work_time := true
	var publish_count := 0
	var released_reservations := 0

	func _is_work_time() -> bool:
		return work_time

	func _publish_courier_tasks(dispatcher: RefCounted) -> void:
		publish_count += 1

	func _is_courier_task_valid(_task: RefCounted) -> bool:
		return valid_result

	func _start_courier_task(courier: Citizen, _task: RefCounted) -> bool:
		courier.state = Citizen.State.COURIER_TO_WAREHOUSE
		return true

	func _release_task_warehouse_reservation(task: RefCounted) -> void:
		released_reservations += 1
		task.reserved_warehouse_index = -1
		task.reserved_resource_type = ""
		task.reserved_amount = 0

	func _cancel_courier_task(_courier: Citizen, _task: RefCounted) -> void:
		pass

	func configure_dispatcher(dispatcher: CourierDispatcher) -> void:
		var routing := StorageRoutingService.new()
		dispatcher.configure(
			citizens,
			warehouse_positions,
			routing,
			func() -> float: return runtime_seconds,
			func(d): _publish_courier_tasks(d),
			func(t) -> bool: return _is_courier_task_valid(t),
			func(c, t) -> bool: return _start_courier_task(c, t),
			func(c, t): _cancel_courier_task(c, t),
			func(t): _release_task_warehouse_reservation(t)
		)



static func context(order: CitizenOrder = null) -> BehaviorContext:
	var actuator := FakeActuator.new(1)
	var ctx := BehaviorContext.new(actuator, AIBlackboard.new())
	ctx.refresh(snapshot(0.0, CitizenSnapshot.new(1)), order)
	return ctx


static func snapshot(simulation_seconds: float, citizen: CitizenSnapshot) -> WorldSnapshot:
	return WorldSnapshot.new(simulation_seconds as int, simulation_seconds, 0.0, AIFactSet.new(), {
		citizen.id: citizen,
	})


static func sleep_snapshot(should_sleep: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": should_sleep,
		&"needs.has_home": true,
		&"needs.home_position": Vector3.ZERO,
		&"needs.can_start_sleep": true,
	}))
	return snapshot(0.0, citizen)


static func meal_snapshot(meal_requested: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": meal_requested,
		&"needs.can_start_meal": true,
		&"needs.canteen_position": Vector3.ZERO,
	}))
	return snapshot(0.0, citizen)


static func toilet_snapshot(toilet_requested: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": toilet_requested,
		&"needs.can_start_toilet": true,
		&"needs.relief_candidates": [{
			&"id": &"tree:0:0:0",
			&"position": Vector3.ZERO,
			&"kind": &"tree",
		}],
	}))
	return snapshot(0.0, citizen)


static func rest_snapshot(rest_requested: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.rest_requested": rest_requested,
		&"needs.can_start_rest": true,
		&"needs.rest_position": Vector3.ZERO,
		&"needs.rest_duration": 4.0,
	}))
	return snapshot(0.0, citizen)


static func forestry_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.forestry.worker": true,
		&"work.forestry.in_progress": in_progress,
		&"work.forestry.candidates": [
			{
				&"id": &"tree:3:0",
				&"position": Vector3(3.0, 0.0, 0.0),
				&"access": Vector3(2.5, 0.0, 0.0),
				&"sawmill_position": Vector3(6.0, 0.0, 0.0),
				&"warehouse_position": Vector3(8.0, 0.0, 0.0),
			},
			{
				&"id": &"tree:9:0",
				&"position": Vector3(9.0, 0.0, 0.0),
				&"access": Vector3(8.5, 0.0, 0.0),
				&"sawmill_position": Vector3(6.0, 0.0, 0.0),
				&"warehouse_position": Vector3(8.0, 0.0, 0.0),
			},
		],
	}))


static func forestry_order(citizen_id: int, tree_position: Vector3, tree_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"forestry", &"workforce.forestry", 0.55, AIFactSet.new({
		&"work.tree_id": tree_id,
		&"work.tree_access": tree_position + Vector3(-0.5, 0.0, 0.0),
		&"work.sawmill_position": Vector3(6.0, 0.0, 0.0),
		&"work.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))
	order.target_position = tree_position
	return order


static func farming_citizen(citizen_id: int, in_progress: bool, can_start: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.farming.worker": true,
		&"work.farming.in_progress": in_progress,
		&"work.farming.can_start": can_start,
		&"work.farming.position": Vector3(4.0, 0.0, 0.0),
		&"work.farming.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))


static func farming_order(citizen_id: int, farm_position: Vector3) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"farming", &"workforce.farming", 0.50, AIFactSet.new({
		&"work.farm_position": farm_position,
		&"work.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))
	order.target_position = farm_position
	return order


static func construction_citizen(citizen_id: int, in_progress: bool, can_start: bool, mode: StringName, target_id: int) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.construction.worker": true,
		&"work.construction.in_progress": in_progress,
		&"work.construction.can_start": can_start,
		&"work.construction.mode": mode,
		&"work.construction.target_key": StringName("%s:%d" % [mode, target_id]),
		&"work.construction.position": Vector3(5.0, 0.0, 0.0),
	}))


static func construction_order(citizen_id: int, mode: StringName, target_id: int) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, mode, &"workforce.construction", 0.60, AIFactSet.new({
		&"work.construction.mode": mode,
	}))
	order.target_key = StringName("%s:%d" % [mode, target_id])
	order.target_position = Vector3(5.0, 0.0, 0.0)
	return order


static func gathering_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": in_progress,
		&"work.gathering.candidates": [
			{&"id": &"branch:3:0", &"resource_type": "branches", &"position": Vector3(3.0, 0.0, 0.0), &"access": Vector3(2.5, 0.0, 0.0), &"warehouse_position": Vector3(8.0, 0.0, 0.0)},
			{&"id": &"branch:9:0", &"resource_type": "branches", &"position": Vector3(9.0, 0.0, 0.0), &"access": Vector3(8.5, 0.0, 0.0), &"warehouse_position": Vector3(8.0, 0.0, 0.0)},
		],
	}))


static func gathering_citizen_with_candidates(citizen_id: int, candidates: Array) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": false,
		&"work.gathering.can_start": true,
		&"work.gathering.role": &"gather_food",
		&"work.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
		&"work.gathering.candidates": candidates,
	}))


static func gathering_candidate(source_id: StringName) -> Dictionary:
	var x := 3.0 if source_id == &"branch:3:0" else 9.0
	return {
		&"id": source_id,
		&"resource_type": "branches",
		&"position": Vector3(x, 0.0, 0.0),
		&"access": Vector3(x - 0.5, 0.0, 0.0),
		&"warehouse_position": Vector3(8.0, 0.0, 0.0),
	}


static func gathering_order(citizen_id: int, source_position: Vector3, source_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"gathering", &"workforce.gathering", 0.50, AIFactSet.new({
		&"work.source_id": source_id,
		&"resource.type": "branches",
		&"target.access_position": source_position + Vector3(-0.5, 0.0, 0.0),
		&"warehouse.position": Vector3(8.0, 0.0, 0.0),
	}))
	order.target_position = source_position
	return order


static func cleaning_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "cleaning",
		&"daily.order.workday_id": 3,
		&"daily.order.expires_at": 42.0,
		&"daily.cleaning.in_progress": in_progress,
		&"daily.cleaning.can_start": true,
		&"daily.cleaning.candidates": [
			{&"id": &"pile:3:0:branches", &"pile_id": &"pile:3:0", &"resource_type": "branches", &"position": Vector3(3.0, 0.0, 0.0), &"access": Vector3(3.0, 0.0, 0.0)},
			{&"id": &"pile:9:0:branches", &"pile_id": &"pile:9:0", &"resource_type": "branches", &"position": Vector3(9.0, 0.0, 0.0), &"access": Vector3(9.0, 0.0, 0.0)},
		],
		&"daily.cleaning.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))


static func cleaning_order(citizen_id: int, source_position: Vector3, source_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"cleaning", &"player", 0.82, AIFactSet.new({
		&"work.source_id": source_id,
		&"resource.type": "branches",
		&"target.access_position": source_position,
		&"warehouse.position": Vector3(8.0, 0.0, 0.0),
		&"daily.role": "cleaning",
		&"daily.workday_id": 3,
	}))
	order.workday_id = 3
	order.expires_at = 42.0
	order.target_position = source_position
	return order


static func excavation_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.excavation.worker": true,
		&"work.excavation.in_progress": in_progress,
		&"work.excavation.candidates": [
			{&"id": &"dig:61", &"target_key": &"dig:61", &"position": Vector3(3.0, 0.0, 0.0)},
			{&"id": &"dig:62", &"target_key": &"dig:62", &"position": Vector3(9.0, 0.0, 0.0)},
		],
	}))


static func excavation_order(citizen_id: int, target_id: int, site_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"excavation", &"workforce.excavation", 0.50, AIFactSet.new({&"work.site_id": site_id}))
	order.target_key = site_id
	order.target_position = Vector3(3.0, 0.0, 0.0)
	return order


static func service_citizen(citizen_id: int, in_progress: bool, can_start: bool, role: StringName) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.service.worker": true,
		&"work.service.in_progress": in_progress,
		&"work.service.can_start": can_start,
		&"work.service.role": role,
		&"work.service.position": Vector3(5.0, 0.0, 0.0),
	}))


static func service_order(citizen_id: int, role: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"service_work", &"workforce.service", 0.45, AIFactSet.new({
		&"work.service.role": role,
		&"workplace.position": Vector3(5.0, 0.0, 0.0),
	}))
	order.target_position = Vector3(5.0, 0.0, 0.0)
	return order


static func factory_citizen(citizen_id: int, in_progress: bool, can_start: bool, role: StringName) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.factory.worker": true,
		&"work.factory.in_progress": in_progress,
		&"work.factory.can_start": can_start,
		&"work.factory.role": role,
		&"work.factory.target_key": &"factory:7",
		&"work.factory.position": Vector3(7.0, 0.0, 0.0),
	}))


static func factory_order(citizen_id: int, role: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"factory_work", &"workforce.factory", 0.46, AIFactSet.new({&"factory.role": role}))
	order.target_key = &"factory:7"
	order.target_position = Vector3(7.0, 0.0, 0.0)
	return order


static func courier_citizen(citizen_id: int) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.can_start": true,
		&"work.courier.tasks": [
			{&"id": &"canteen_food", &"priority": 100, &"pickup": Vector3.ZERO},
			{&"id": &"worker:2", &"priority": 45, &"pickup": Vector3(4.0, 0.0, 0.0)},
		],
	}))


static func courier_citizen_with_tasks(citizen_id: int, tasks: Array) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.can_start": true,
		&"work.courier.tasks": tasks,
	}))


static func snapshot_with_wellbeing(wellbeing: int, citizen: CitizenSnapshot) -> WorldSnapshot:
	var facts := AIFactSet.new({&"settlement.wellbeing": wellbeing})
	return WorldSnapshot.new(0, 0.0, 0.0, facts, {citizen.id: citizen})
