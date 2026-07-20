class_name CitizenIdleIndicator
extends RefCounted

const CitizenEmploymentStateScript = preload("res://game/features/citizens/domain/citizen_employment_state.gd")

func update_idle_indicator(actor: Citizen) -> void:
	if actor.is_player_controlled:
		actor.idle_indicator.visible = false
		return
	if actor.is_dangerously_tired():
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = "Dangerously tired"
		actor.idle_indicator.modulate = Color("e57373")
		return
	var visible_state := actor._displayed_state
	if visible_state == Citizen.State.TO_TOILET:
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = "Going to Toilet"
		actor.idle_indicator.modulate = Color("a5d6a7")
		return
	if visible_state == Citizen.State.WAITING_FOR_TOILET:
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = "Waiting in Queue"
		actor.idle_indicator.modulate = Color("ffb74d")
		return
	if visible_state == Citizen.State.USING_TOILET:
		actor.idle_indicator.visible = true
		var pct := int((1.0 - actor.toilet_timer.remaining / actor.TOILET_USE_DURATION) * 100.0)
		actor.idle_indicator.text = "Using Toilet (%d%%)" % clamp(pct, 0, 100)
		actor.idle_indicator.modulate = Color("81c784")
		return
	if visible_state == Citizen.State.TO_BUSH:
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = "Going to %s" % ("Tree" if actor.toilet_relief_type == "tree" else "Grass")
		actor.idle_indicator.modulate = Color("a5d6a7")
		return
	if visible_state == Citizen.State.USING_BUSH:
		actor.idle_indicator.visible = true
		var pct := int((1.0 - actor.toilet_timer.remaining / actor.TOILET_USE_DURATION) * 100.0)
		actor.idle_indicator.text = "Relieving by %s (%d%%)" % ["Tree" if actor.toilet_relief_type == "tree" else "Grass", clamp(pct, 0, 100)]
		actor.idle_indicator.modulate = Color("81c784")
		return
	if visible_state == Citizen.State.RESEARCHING:
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = "Researching"
		actor.idle_indicator.modulate = Color("6ab0df")
		return
	if visible_state == Citizen.State.WORK_POSITION:
		actor.idle_indicator.visible = true
		var display_role := actor.work_position_role.replace("_", " ")
		actor.idle_indicator.text = "Working: %s" % display_role if not display_role.is_empty() else "At work position"
		actor.idle_indicator.modulate = Color("7bb7e8")
		return
	if visible_state == Citizen.State.WAITING:
		actor.idle_indicator.visible = true
		var remaining_hours := int(actor.task_timer.remaining / actor.WAIT_DURATION) + 1
		actor.idle_indicator.text = "No work (waiting %dh)" % clamp(remaining_hours, 1, 24)
		actor.idle_indicator.modulate = Color("f0873d")
		return
	if visible_state == Citizen.State.AI_MOVING:
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = "Going to: %s" % actor.ai_activity_label if not actor.ai_activity_label.is_empty() else "Moving"
		actor.idle_indicator.modulate = Color("7bb7e8")
		return
	if visible_state != Citizen.State.IDLE:
		actor.idle_indicator.visible = true
		actor.idle_indicator.text = state_display_name(visible_state)
		actor.idle_indicator.modulate = Color("7bb7e8")
		return
	actor.idle_indicator.visible = true
	var EmploymentState = CitizenEmploymentStateScript.EmploymentState
	match actor.employment_state:
		EmploymentState.EMPLOYED:
			actor.idle_indicator.text = "Employed: %s%s" % [actor.permanent_role.replace("_", " "), employment_workplace_suffix(actor.employment_workplace)]
			actor.idle_indicator.modulate = Color("76c893")
		EmploymentState.REGISTERING:
			var registration_label := "no permanent work" if actor.pending_employment_role.is_empty() else actor.pending_employment_role.replace("_", " ")
			actor.idle_indicator.text = "Registering: %s%s" % [registration_label, employment_workplace_suffix(actor.pending_employment_workplace)]
			actor.idle_indicator.modulate = Color("7bb7e8")
		EmploymentState.UNREGISTERED:
			actor.idle_indicator.text = "Unregistered"
			actor.idle_indicator.modulate = Color("f0873d")
		_:
			var visible_role := actor.daily_order_role
			var automatic := false
			if visible_role.is_empty() and not actor.active_role.is_empty():
				visible_role = actor.active_role
				automatic = true
			if actor.is_daily_order_role(visible_role):
				actor.idle_indicator.text = "Daily order: %s" % visible_role.replace("_", " ")
			elif visible_role.is_empty():
				actor.idle_indicator.text = "No permanent work"
			else:
				actor.idle_indicator.text = "Work order: %s%s" % [visible_role.replace("_", " "), " (planned)" if automatic else ""]
			actor.idle_indicator.modulate = Color("f0c45d")


func update_privacy_blur(actor: Citizen) -> void:
	if actor._privacy_blur == null:
		return
	var active := not actor.is_player_controlled and actor.state == Citizen.State.USING_BUSH
	actor._privacy_blur.visible = active


func state_display_name(displayed_state: int) -> String:
	var state_names := Citizen.State.keys()
	if displayed_state < 0 or displayed_state >= state_names.size():
		return "Unknown state"
	return str(state_names[displayed_state]).capitalize().replace("_", " ")


func employment_workplace_suffix(workplace: Node3D) -> String:
	if not is_instance_valid(workplace):
		return ""
	return " (%s)" % str(workplace.get_meta("building_type", "site")).replace("_", " ")
