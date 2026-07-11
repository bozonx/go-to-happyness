class_name SettlementRules
extends RefCounted

const LOW_WELLBEING := 30
const LEAVE_AFTER_DAYS := 3

static func production_multiplier(workday_hours: int, night_shifts: bool) -> float:
	return clampf(float(workday_hours) / 8.0 + (0.2 if night_shifts else 0.0), 0.5, 1.5)

static func daily_wellbeing_change(has_home: bool, food_per_person: float, water_per_person: float, workday_hours: int, night_shifts: bool) -> int:
	var change := 2 if has_home else -8
	change += 2 if food_per_person >= 1.0 else -10
	change += 2 if water_per_person >= 1.0 else -14
	change -= maxi(0, workday_hours - 8) * 2
	change += maxi(0, 8 - workday_hours)
	if night_shifts: change -= 6
	return change

static func volunteer_can_arrive(free_beds: int, water: int, average_wellbeing: float) -> bool:
	return free_beds > 0 and water > 0 and average_wellbeing >= 50.0

static func should_volunteer_leave(consecutive_low_days: int) -> bool:
	return consecutive_low_days >= LEAVE_AFTER_DAYS
