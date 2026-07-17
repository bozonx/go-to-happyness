class_name SettlementRules
extends RefCounted

const LEAVE_SATISFACTION_THRESHOLD := 10.0
const WARNING_SATISFACTION_THRESHOLD := 30.0
const MIN_SETTLEMENT_POPULATION := 2
const OPEN_AIR_ORGANIC_DECAY_RATES := {
	"food": 0.10,
	"grass": 0.05,
	"branches": 0.05,
	"wood": 0.05,
	"logs": 0.05,
}

static func production_multiplier(workday_hours: int) -> float:
	return clampf(float(workday_hours) / 8.0, 0.5, 1.5)

static func daily_wellbeing_change(has_home: bool, food_per_person: float, water_per_person: float, workday_hours: int) -> int:
	var change := 2 if has_home else -8
	change += 2 if food_per_person >= 1.0 else -10
	change += 2 if water_per_person >= 1.0 else -14
	change -= maxi(0, workday_hours - 8) * 2
	change += maxi(0, 8 - workday_hours)
	return change

static func volunteer_can_arrive(free_beds: int, water: int, average_wellbeing: float) -> bool:
	return free_beds > 0 and water > 0 and average_wellbeing >= 50.0

static func should_citizen_leave(satisfaction_value: float) -> bool:
	return satisfaction_value < LEAVE_SATISFACTION_THRESHOLD

static func is_satisfaction_warning(satisfaction_value: float) -> bool:
	return satisfaction_value < WARNING_SATISFACTION_THRESHOLD


static func open_air_storage_decay_losses(amounts: Dictionary, total_stored_units: float, safe_capacity_units: float) -> Dictionary:
	var losses := {}
	if total_stored_units <= safe_capacity_units or total_stored_units <= 0.0:
		return losses
	var exposed_ratio := (total_stored_units - safe_capacity_units) / total_stored_units
	for resource_type in OPEN_AIR_ORGANIC_DECAY_RATES:
		var amount := int(amounts.get(resource_type, 0))
		if amount <= 0:
			continue
		var exposed_amount := float(amount) * exposed_ratio
		var rate := float(OPEN_AIR_ORGANIC_DECAY_RATES[resource_type])
		var lost := ceili(exposed_amount * rate)
		if lost > 0:
			losses[resource_type] = mini(amount, lost)
	return losses
