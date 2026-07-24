class_name SettlementOutsideWorkController
extends RefCounted

## Manages outside work assignments: reward calculation, dispatching couriers
## to neighboring settlements, tracking departed workers, and processing
## their return with rewards. Extracted from SettlementGame.

const OUTSIDE_WORK_DURATION_MINUTES := SimulationClock.MINUTES_PER_DAY
const OUTSIDE_WORK_BASE_REWARD_MIN := 4
const OUTSIDE_WORK_BASE_REWARD_MAX := 12
const OUTSIDE_WORK_UPGRADE_REWARD := 16

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func outside_work_reward() -> int:
	if game.settlement != null and game.settlement.is_research_completed("outside_work_earnings"):
		return OUTSIDE_WORK_UPGRADE_REWARD
	return game.random.randi_range(OUTSIDE_WORK_BASE_REWARD_MIN, OUTSIDE_WORK_BASE_REWARD_MAX)


func send_selected_resident_to_outside_work() -> void:
	if not is_instance_valid(game.selected_builder) or game.selected_builder.is_player_controlled:
		game._update_interface("Select an AI-controlled Courier before sending them to outside work.")
		return
	if not game.selected_builder.can_handle_entry_logistics() or not game._is_work_time():
		game._update_interface("Outside work requires a Courier.")
		return
	var worker_id := game.selected_builder.get_stable_id()
	if game.outside_workers.has(worker_id):
		game._update_interface("This resident is already working in a neighboring settlement.")
		return
	var reward := outside_work_reward()
	if game.courier_dispatcher.task_for(game.selected_builder) != null:
		game._update_interface("Courier is already assigned to a logistics task.")
		return
	game.courier_dispatcher.publish(StringName("outside_work_%d" % worker_id), CourierTask.Kind.OUTSIDE_WORK, 85, game.entrance_stone.global_position, game.entrance_stone.global_position, {"courier": game.selected_builder, "reward": reward})
	game._request_courier_dispatch()
	game._update_interface("Outside work assigned. The courier is heading to the entrance sign.")


func on_outside_work_departed(worker: Citizen) -> void:
	var task: CourierTask = game.courier_dispatcher.task_for(worker)
	if task == null or task.kind != CourierTask.Kind.OUTSIDE_WORK:
		return
	var reward := int(task.payload.get("reward", OUTSIDE_WORK_BASE_REWARD_MIN))
	var worker_id := worker.get_stable_id()
	game.outside_workers[worker_id] = {
		"citizen": worker,
		"return_at_minute": absolute_game_minutes() + OUTSIDE_WORK_DURATION_MINUTES,
		"reward": reward,
	}
	worker.visible = false
	worker.process_mode = Node.PROCESS_MODE_DISABLED
	game.courier_dispatcher.complete_for(worker)
	game._update_interface("Courier left for outside work and will return in 24 hours with %d coins." % reward)


func absolute_game_minutes() -> int:
	return (game.day_cycle.current_day - 1) * SimulationClock.MINUTES_PER_DAY + floori(game.clock.minutes)


func return_outside_workers() -> void:
	var returned_any := false
	for worker_id in game.outside_workers.keys():
		var assignment := game.outside_workers[worker_id] as Dictionary
		if assignment.has("return_at_minute"):
			if absolute_game_minutes() < int(assignment.return_at_minute):
				continue
		elif game.day_cycle.current_day < int(assignment.get("return_day", 0)):
			continue
		var worker := assignment.get("citizen") as Citizen
		var reward: int = int(assignment.get("reward", OUTSIDE_WORK_BASE_REWARD_MIN))
		if is_instance_valid(worker):
			worker.process_mode = Node.PROCESS_MODE_INHERIT
			worker.visible = true
			worker.global_position = game.entrance_stone.global_position + Vector3(0.8, 0.08, 1.2)
			worker.idle()
			game.settlement.money += reward
			game.last_citizen_positions[worker_id] = worker.global_position
		game.outside_workers.erase(worker_id)
		returned_any = true
		game._update_interface("A resident returned from outside work with %d coins." % reward)
	if returned_any and game.citizen_ai != null:
		game.citizen_ai.request_decision_refresh()
