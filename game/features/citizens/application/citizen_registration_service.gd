class_name CitizenRegistrationService
extends RefCounted

## Manages civic registration, registration officer staffing checks,
## queue ticket generation, registration timing, and employment completion.

var _citizens: Array = []
var _officer_post_radius: float
var _employment_centre_building_getter: Callable
var _employment_center_position_getter: Callable
var _is_work_time: Callable
var _update_workers: Callable
var _registration_queue_counter_setter: Callable


func configure(
	p_citizens: Array,
	p_officer_post_radius: float,
	p_employment_centre_building_getter: Callable,
	p_employment_center_position_getter: Callable,
	p_is_work_time: Callable,
	p_update_workers: Callable,
	p_registration_queue_counter_setter: Callable
) -> void:
	_citizens = p_citizens
	_officer_post_radius = p_officer_post_radius
	_employment_centre_building_getter = p_employment_centre_building_getter
	_employment_center_position_getter = p_employment_center_position_getter
	_is_work_time = p_is_work_time
	_update_workers = p_update_workers
	_registration_queue_counter_setter = p_registration_queue_counter_setter


func registration_official() -> Citizen:
	var centre: Node3D = _employment_centre_building_getter.call()
	if not is_instance_valid(centre):
		return null
	var center: Vector3 = _employment_center_position_getter.call()
	for citizen in _citizens:
		if not is_instance_valid(citizen) or citizen.permanent_role != "official":
			continue
		if citizen.employment_workplace != centre:
			continue
		if citizen.global_position.distance_to(center) > _officer_post_radius:
			continue
		if citizen.is_player_controlled or citizen.state == Citizen.State.OFFICIAL_WORK:
			return citizen
	return null


func is_registration_staffed() -> bool:
	return _is_work_time.call() and registration_official() != null


func next_registration_ticket() -> int:
	return _registration_queue_counter_setter.call()


func can_start_registration(citizen: Citizen) -> bool:
	if not is_registration_staffed() or citizen.employment_state != Citizen.EmploymentState.REGISTERING:
		return false
	for other in _citizens:
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
	if not _is_work_time.call():
		citizen.state = Citizen.State.IDLE
		return
	citizen.finish_employment_processing()
	_update_workers.call()
