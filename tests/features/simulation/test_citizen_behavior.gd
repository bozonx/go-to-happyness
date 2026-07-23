extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## Tests citizen idle wander targeting, position guard, toilet needs
## scheduling, and park rest behaviour.

func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var resident: Citizen = simulation.citizens[1]

	# Idle wander: reachability is checked but path is not computed until a
	# candidate is selected.
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

	# Position guard: citizens near the entrance are pulled back; far ones are left.
	var original_resident_position := resident.global_position
	var entrance: Vector3 = simulation.entrance_stone.global_position
	resident.global_position = entrance + Vector3(2.4, 0.0, 0.0)
	simulation.last_citizen_positions[resident.get_stable_id()] = entrance + Vector3(2.6, 0.0, 0.0)
	simulation._guard_citizen_positions()
	assert(resident.global_position.distance_to(entrance) < 2.5)
	resident.global_position = entrance
	simulation.last_citizen_positions[resident.get_stable_id()] = entrance + Vector3(10.0, 0.0, 0.0)
	simulation._guard_citizen_positions()
	assert(resident.global_position.distance_to(entrance) > 5.0)
	resident.global_position = original_resident_position
	simulation.last_citizen_positions[resident.get_stable_id()] = original_resident_position

	# Toilet needs: the service schedules relief; the actor preserves work state.
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

	# A scheduled leisure break must only claim an idle citizen.
	resident.setup_specialization("cook")
	resident.state = Citizen.State.TO_TREE
	resident.source_access_position = work_target
	simulation.park_positions.clear()
	simulation.park_positions.append(resident.global_position + Vector3(1.0, 0.0, 0.0))
	simulation._start_park_rest(true)
	assert(resident.state == Citizen.State.TO_TREE)
	assert(resident.source_access_position == work_target)

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
