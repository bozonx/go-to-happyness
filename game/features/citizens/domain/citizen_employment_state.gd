class_name CitizenEmploymentState
extends RefCounted

## Deterministic employment, daily-order, and overtime state for a citizen.
## No nodes, physics, rendering, simulation, or wall-clock time.

enum EmploymentState { UNREGISTERED, NO_PERMANENT_WORK, EMPLOYED, REGISTERING }

const DAILY_ORDER_ROLES := {
	"courier": true,
	"construction": true,
	"gather_branches": true,
	"gather_food": true,
	"gather_grass": true,
	"gather_water": true,
	"cleaning": true,
	"cook": true,
	"researcher": true,
}

var employment_state := EmploymentState.UNREGISTERED
var daily_order_role := ""
var daily_order_workday_id := 0
var daily_order_expires_at := -1.0
var permanent_role := ""
var pending_employment_role := ""
var registration_queue_order := -1
var overtime_mode := false
var overtime_until_workday_id := 0
var overtime_source := ""
## Source -> final workday. Sources are independent so cancelling a workplace
## order cannot cancel a concurrent settlement order.
var overtime_sources: Dictionary = {}
## Source -> day on which that source was last issued. Kept after cancellation
## to enforce the once-per-day command limit.
var overtime_issued_days: Dictionary = {}


func is_employed() -> bool:
	return employment_state == EmploymentState.EMPLOYED


func has_no_permanent_work() -> bool:
	return employment_state == EmploymentState.NO_PERMANENT_WORK


func is_registering() -> bool:
	return employment_state == EmploymentState.REGISTERING


func is_unregistered() -> bool:
	return employment_state == EmploymentState.UNREGISTERED


func is_daily_order_role(role: String) -> bool:
	return DAILY_ORDER_ROLES.has(role)


func has_daily_order() -> bool:
	return is_daily_order_role(daily_order_role)


func is_courier() -> bool:
	return permanent_role == "courier" and is_employed()


func activate_overtime(until_workday_id: int, source: String, issued_day := 0) -> bool:
	if source.is_empty():
		return false
	if issued_day > 0 and int(overtime_issued_days.get(source, -1)) == issued_day:
		return false
	if not overtime_mode:
		overtime_sources.clear()
	var previous_until := int(overtime_sources.get(source, 0))
	overtime_sources[source] = maxi(previous_until, until_workday_id)
	if issued_day > 0:
		overtime_issued_days[source] = issued_day
	_sync_overtime_state()
	return true


func has_active_overtime(current_workday_id: int) -> bool:
	if not overtime_mode:
		return false
	if overtime_sources.is_empty():
		return overtime_until_workday_id >= current_workday_id
	for until_workday in overtime_sources.values():
		if int(until_workday) >= current_workday_id:
			return true
	return false


func has_overtime_source(source: String, current_workday_id: int) -> bool:
	return overtime_mode and int(overtime_sources.get(source, 0)) >= current_workday_id


func clear_expired_overtime(current_workday_id: int) -> void:
	if not overtime_mode:
		overtime_sources.clear()
		overtime_until_workday_id = 0
		overtime_source = ""
		return
	if overtime_sources.is_empty():
		if overtime_until_workday_id < current_workday_id:
			overtime_mode = false
			overtime_until_workday_id = 0
			overtime_source = ""
		return
	for source in overtime_sources.keys().duplicate():
		if int(overtime_sources[source]) < current_workday_id:
			overtime_sources.erase(source)
	_sync_overtime_state()


func clear_overtime_source(source := "") -> void:
	if source.is_empty():
		overtime_sources.clear()
	else:
		overtime_sources.erase(source)
	_sync_overtime_state()


func _sync_overtime_state() -> void:
	overtime_until_workday_id = 0
	for until_workday in overtime_sources.values():
		overtime_until_workday_id = maxi(overtime_until_workday_id, int(until_workday))
	overtime_mode = overtime_until_workday_id > 0
	overtime_source = str(overtime_sources.keys().back()) if not overtime_sources.is_empty() else ""
