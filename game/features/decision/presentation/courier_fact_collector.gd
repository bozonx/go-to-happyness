## Scene fact collector for logistics.
class_name CourierFactCollector
extends RefCounted

## Collects courier work facts for one citizen. Requires the pre-built
## courier_tasks list from the facade since it is shared with settlement facts.

func collect(ctx: FacadeContext, courier_tasks: Array[Dictionary]) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time
	var citizen_id := ctx.citizen_id

	var courier_worker: bool = actor.can_handle_entry_logistics() and not actor.is_player_controlled
	var courier_task_candidates: Array[Dictionary] = []
	if courier_worker and ctx.simulation.courier_dispatcher != null:
		for task_data in courier_tasks:
			var task_id := task_data.get(&"id", &"") as StringName
			var task: CourierTask = ctx.simulation.courier_dispatcher.tasks.get(task_id)
			if task != null and ctx.simulation.courier_task_service.is_courier_task_reachable(actor, task):
				courier_task_candidates.append(task_data)


	var courier_active_task_id: StringName = &""
	var courier_active_pickup := Vector3.INF
	var courier_active_priority := 0
	if courier_worker and ctx.simulation.courier_dispatcher != null:
		var active_courier_task: CourierTask = ctx.simulation.courier_dispatcher.task_for(actor)
		if active_courier_task != null and actor.has_active_delivery():
			courier_active_task_id = active_courier_task.id
			courier_active_pickup = active_courier_task.pickup
			courier_active_priority = active_courier_task.priority
	var courier_in_progress := courier_active_task_id != &""
	var courier_can_start: bool = courier_worker and actor.state in [Citizen.State.IDLE, Citizen.State.WAITING] and actor_work_time

	return {
		&"work.courier.worker": courier_worker,
		&"work.courier.permanent": actor.is_courier(),
		&"work.courier.actor_id": citizen_id,
		&"work.courier.in_progress": courier_in_progress,
		&"work.courier.can_start": courier_can_start,
		&"work.courier.active_task_id": courier_active_task_id,
		&"work.courier.active_pickup": courier_active_pickup,
		&"work.courier.active_priority": courier_active_priority,
		&"work.courier.tasks": courier_task_candidates,
		&"work.courier.use_personal_tasks": true,
	}
