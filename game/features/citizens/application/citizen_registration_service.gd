class_name CitizenRegistrationService
extends RefCounted

## Manages civic registration, registration officer staffing checks,
## queue ticket generation, registration timing, and employment completion.

var simulation: Node


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func registration_official() -> Citizen:
	var centre: Node3D = simulation._employment_centre_building()
	if not is_instance_valid(centre):
		return null
	var center: Vector3 = simulation._employment_center_position()
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or citizen.permanent_role != "official":
			continue
		if citizen.employment_workplace != centre:
			continue
		if citizen.global_position.distance_to(center) > simulation.OFFICER_POST_RADIUS:
			continue
		if citizen.is_player_controlled or citizen.state == Citizen.State.OFFICIAL_WORK:
			return citizen
	return null


func is_registration_staffed() -> bool:
	return simulation._is_work_time() and registration_official() != null


func next_registration_ticket() -> int:
	simulation._registration_queue_counter += 1
	return simulation._registration_queue_counter


func can_start_registration(citizen: Citizen) -> bool:
	if not is_registration_staffed() or citizen.employment_state != Citizen.EmploymentState.REGISTERING:
		return false
	for other in simulation.citizens:
		if not is_instance_valid(other) or other == citizen:
			continue
		if other.state == Citizen.State.EMPLOYMENT_PROCESSING:
			return false
		if other.employment_state == Citizen.EmploymentState.REGISTERING and other.registration_queue_order >= 0 and other.registration_queue_order < citizen.registration_queue_order:
			return false
	return true


func registration_duration() -> float:
	var official := registration_official()
	if official == null:
		return Citizen.EMPLOYMENT_PROCESS_DURATION
	return Citizen.EMPLOYMENT_PROCESS_DURATION / official.get_efficiency("official")


func on_employment_processing_finished(citizen: Citizen) -> void:
	if not simulation._is_work_time():
		citizen.state = Citizen.State.IDLE
		return
	citizen.finish_employment_processing()
	simulation._update_workers()
