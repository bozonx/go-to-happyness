class_name BehaviorTask
extends RefCounted

var goal_id: StringName
var root: BehaviorStep
var order_id: int
var resumable: bool
var label: String


func _init(
	next_goal_id: StringName = &"",
	next_root: BehaviorStep = null,
	next_resumable: bool = true,
	next_label: String = ""
) -> void:
	goal_id = next_goal_id
	root = next_root
	resumable = next_resumable
	label = next_label
	order_id = 0
