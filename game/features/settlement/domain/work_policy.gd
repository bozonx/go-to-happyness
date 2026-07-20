class_name WorkPolicy
extends RefCounted

## Tracks work schedule settings and daily orders issued from the campfire.

var workday_hours := 8
## Chosen during a shift and applied when the next workday opens.
var pending_workday_hours := 0
var night_work_order_day := -1
var double_time_order_day := -1
var road_walking_order_enabled := false
var cheer_up_used_today := false


func reset() -> void:
	workday_hours = 8
	pending_workday_hours = 0
	night_work_order_day = -1
	double_time_order_day = -1
	road_walking_order_enabled = false
	cheer_up_used_today = false


func apply_pending_workday_hours() -> void:
	if pending_workday_hours <= 0:
		return
	workday_hours = pending_workday_hours
	pending_workday_hours = 0
