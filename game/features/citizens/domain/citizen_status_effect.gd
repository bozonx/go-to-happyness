class_name CitizenStatusEffect
extends RefCounted

const STORAGE_NO_WAREHOUSE := &"storage_no_warehouse"
const NO_HOME := &"no_home"
const TENT_SHELTER := &"tent_shelter"
const NO_LIT_COMMUNAL_FIRE := &"no_lit_communal_fire"
const BARE_HANDS := &"bare_hands"
const SMOKY_EYES := &"smoky_eyes"

var id := StringName()
var label := ""
var severity := 0.0
var duration_hours := -1.0


static func create(next_id: StringName, next_label: String, next_severity := 0.0, next_duration_hours := -1.0) -> RefCounted:
	var status: RefCounted = load("res://game/features/citizens/domain/citizen_status_effect.gd").new()
	status.id = next_id
	status.label = next_label
	status.severity = maxf(0.0, next_severity)
	status.duration_hours = next_duration_hours
	return status
