class_name EventChoiceDef
extends RefCounted

## A selectable option within a game event. Contains a label for the button
## and a list of outcomes that are all applied when this choice is selected.

var label: String = ""
var outcomes: Array = []
var sets_flag: StringName = &""


const _script = preload("res://game/features/events/domain/event_choice_def.gd")


static func create(p_label: String, p_outcomes: Array, p_sets_flag: StringName = &"") -> RefCounted:
	var c: RefCounted = _script.new()
	c.label = p_label
	c.outcomes = p_outcomes.duplicate()
	c.sets_flag = p_sets_flag
	return c
