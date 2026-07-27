class_name SettlementOutsideWorkController
extends RefCounted

## Manages outside work assignments: reward calculation, dispatching couriers
## to neighboring settlements, tracking departed workers, and processing
## their return with rewards. Extracted from SettlementGame.

const OUTSIDE_WORK_DURATION_MINUTES := SimulationClock.MINUTES_PER_DAY
const OUTSIDE_WORK_BASE_REWARD_MIN := 4
const OUTSIDE_WORK_BASE_REWARD_MAX := 12
const OUTSIDE_WORK_UPGRADE_REWARD := 16

var runtime: OutsideWorkRuntimePort


func _init(p_runtime: OutsideWorkRuntimePort) -> void:
	runtime = p_runtime


func outside_work_reward() -> int:
	if runtime.settlement != null and runtime.settlement.is_research_completed("outside_work_earnings"):
		return OUTSIDE_WORK_UPGRADE_REWARD
	return runtime.random.randi_range(OUTSIDE_WORK_BASE_REWARD_MIN, OUTSIDE_WORK_BASE_REWARD_MAX)


func send_selected_resident_to_outside_work() -> void:
	var selected_builder: Citizen = runtime.selected_builder_getter.call()
	if not is_instance_valid(selected_builder) or selected_builder.is_player_controlled:
		runtime.update_interface.call("Select an AI-controlled Courier before sending them to outside work.")
		return
	if not selected_builder.can_handle_entry_logistics() or not runtime.is_work_time.call():
		runtime.update_interface.call("Outside work requires a Courier.")
		return
	var worker_id := selected_builder.get_stable_id()
	if runtime.outside_workers.has(worker_id):
		runtime.update_interface.call("This resident is already working in a neighboring settlement.")
		return
	var reward := outside_work_reward()
	var courier_dispatcher: CourierDispatcher = runtime.courier_dispatcher_getter.call()
	if courier_dispatcher.task_for(selected_builder) != null:
		runtime.update_interface.call("Courier is already assigned to a logistics task.")
		return
	var entrance: Node3D = runtime.entrance_getter.call()
	courier_dispatcher.publish(StringName("outside_work_%d" % worker_id), CourierTask.Kind.OUTSIDE_WORK, 85, entrance.global_position, entrance.global_position, {"courier": selected_builder, "reward": reward})
	runtime.request_courier_dispatch.call()
	runtime.update_interface.call("Outside work assigned. The courier is heading to the entrance sign.")


func on_outside_work_departed(worker: Citizen) -> void:
	var courier_dispatcher: CourierDispatcher = runtime.courier_dispatcher_getter.call()
	var task: CourierTask = courier_dispatcher.task_for(worker)
	if task == null or task.kind != CourierTask.Kind.OUTSIDE_WORK:
		return
	var reward := int(task.payload.get("reward", OUTSIDE_WORK_BASE_REWARD_MIN))
	var worker_id := worker.get_stable_id()
	runtime.outside_workers[worker_id] = {
		"citizen": worker,
		"return_at_minute": absolute_game_minutes() + OUTSIDE_WORK_DURATION_MINUTES,
		"reward": reward,
	}
	worker.visible = false
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	courier_dispatcher.complete_for(worker)
	runtime.update_interface.call("Courier left for outside work and will return in 24 hours with %d coins." % reward)


func absolute_game_minutes() -> int:
	return runtime.absolute_game_minutes.call()


func return_outside_workers() -> void:
	var returned_any := false
	for worker_id in runtime.outside_workers.keys():
		var assignment := runtime.outside_workers[worker_id] as Dictionary
		if assignment.has("return_at_minute"):
			if absolute_game_minutes() < int(assignment.return_at_minute):
				continue
		elif int(runtime.current_day_getter.call()) < int(assignment.get("return_day", 0)):
			continue
		var worker := assignment.get("citizen") as Citizen
		var reward: int = int(assignment.get("reward", OUTSIDE_WORK_BASE_REWARD_MIN))
		if is_instance_valid(worker):
			worker.process_mode = Node.PROCESS_MODE_INHERIT
			worker.visible = true
			var entrance: Node3D = runtime.entrance_getter.call()
			worker.global_position = entrance.global_position + Vector3(0.8, 0.08, 1.2)
			worker.idle()
			runtime.settlement.money += reward
			runtime.last_citizen_positions[worker_id] = worker.global_position
		runtime.outside_workers.erase(worker_id)
		returned_any = true
		runtime.update_interface.call("A resident returned from outside work with %d coins." % reward)
	if returned_any:
		runtime.refresh_ai.call()
