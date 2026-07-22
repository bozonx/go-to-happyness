class_name WorkforceMenuController
extends RefCounted

const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_workforce_menu() -> void:
	if simulation == null or simulation.workforce_menu == null:
		return
	simulation.campfire_menu.visible = false
	if not simulation.officer_exists():
		simulation._update_interface(simulation.permanent_profession_block_message())
		return
	simulation.workforce_menu.visible = true
	refresh_workforce_menu()


func hide_workforce_menu() -> void:
	if simulation == null:
		return
	if simulation.workforce_menu != null:
		simulation.workforce_menu.visible = false


func close_workforce_menu() -> void:
	hide_workforce_menu()
	if simulation != null and simulation.campfire_menu != null:
		simulation.campfire_menu.visible = true


func refresh_campfire_occupancy_button() -> void:
	if simulation == null or simulation.campfire_menu == null:
		return
	var total := employment_resident_count()
	var employed := employment_state_count(Citizen.EmploymentState.EMPLOYED) + employment_state_count(Citizen.EmploymentState.REGISTERING)
	var daily_order := employment_state_count(Citizen.EmploymentState.NO_PERMANENT_WORK)
	if not simulation.officer_exists():
		simulation.campfire_menu.update_occupancy_button("Workers automation: assign officer", true, simulation.permanent_profession_block_message())
	else:
		simulation.campfire_menu.update_occupancy_button("Employment: %d/%d  No permanent: %d" % [employed, total, daily_order], false, "")


func workforce_roles() -> Array[String]:
	var roles: Array[String] = ["construction", "forestry", "farming", "excavation", "gather_branches", "gather_food", "courier", "cook", "teacher", "seller", "official", "factory_worker", "engineer", "craftsman"]
	return roles


func daily_order_roles() -> Array[String]:
	var roles: Array[String] = ["courier", "construction", "gather_branches", "gather_grass", "gather_water", "cleaning", "cook"]
	if not simulation.settlement.is_research_completed("official"):
		roles.append("researcher")
	return roles


func workforce_role_label(role: String) -> String:
	var labels := {
		"construction": "Construction", "forestry": "Forestry", "farming": "Farming",
		"excavation": "Excavation", "gather_branches": "Gather branches",
		"gather_grass": "Gather grass", "gather_food": "Foraging",
		"gather_water": "Collect water", "cleaning": "Cleaning",
		"cook": "Cook", "researcher": "Researcher", "teacher": "Teacher", "seller": "Seller", "official": "Employment officer",
		"factory_worker": "Factory worker", "engineer": "Engineer",
		"courier": "Courier", "craftsman": "Craftsman"
	}
	return str(labels.get(role, role.replace("_", " ").capitalize()))


func workforce_role_limit(role: String) -> int:
	match role:
		"construction": return simulation.builder_job_capacity() if simulation.settlement.era >= SettlementStateScript.Era.STONE else -1
		"forestry": return simulation.sawmill_positions.size()
		"farming": return simulation.farm_positions.size()
		"gather_branches": return simulation.available_employer_capacity("gather_branches")
		"gather_food": return simulation.available_employer_capacity("gather_food")
		"courier": return simulation.warehouse_positions.size()
		"cook": return 1 if is_instance_valid(simulation.canteen) else 0
		"official": return simulation.available_employer_capacity("official")
		"teacher": return simulation.school_positions.size()
		"seller": return simulation.market_positions.size()
		"factory_worker": return simulation.available_employer_capacity("factory_worker")
		"engineer": return simulation.available_employer_capacity("engineer")
		"craftsman": return simulation.available_employer_capacity("craftsman")
	return -1


func workforce_role_count(role: String) -> int:
	var count := 0
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if role == "courier":
			if citizen.is_courier():
				count += 1
		else:
			if simulation.work_role_for(citizen) == role:
				count += 1
	return count


func manually_assigned_count(role: String) -> int:
	var count := 0
	for citizen in simulation.citizens:
		if not citizen.is_player_controlled:
			if role == "courier" and citizen.is_courier():
				count += 1
			elif citizen.daily_order_role == role:
				count += 1
	return count


func auto_or_unassigned_worker_count() -> int:
	var count := 0
	for citizen in simulation.citizens:
		if not citizen.is_player_controlled:
			if citizen.daily_order_role.is_empty() and citizen.specialization not in ["courier", "cook", "teacher", "factory_worker", "engineer"]:
				count += 1
	return count


func refresh_workforce_menu() -> void:
	if simulation == null or simulation.workforce_menu == null:
		return
	var total := employment_resident_count()
	var employed := employment_state_count(Citizen.EmploymentState.EMPLOYED)
	var hiring := employment_state_count(Citizen.EmploymentState.REGISTERING)
	var no_permanent_work := employment_state_count(Citizen.EmploymentState.NO_PERMANENT_WORK)
	var unregistered := employment_state_count(Citizen.EmploymentState.UNREGISTERED)
	var can_manage_professions: bool = simulation.player_can_manage_permanent_professions()
	var blocked_tooltip: String = simulation.permanent_profession_block_message()

	var job_rows: Array[Dictionary] = []
	var shown_jobs := 0
	for role in workforce_roles():
		var employed_for_role := employment_role_count(role, Citizen.EmploymentState.EMPLOYED)
		var pending_for_role := employment_role_count(role, Citizen.EmploymentState.REGISTERING)
		if not simulation.is_role_available(role) and employed_for_role == 0 and pending_for_role == 0:
			continue
		var limit := workforce_role_limit(role)
		var capacity := " / %d" % limit if limit >= 0 else ""
		var dismiss_disabled: bool = employed + pending_for_role == 0 or not can_manage_professions
		var assign_disabled: bool = (role != "official" and not can_manage_professions) or not simulation.is_role_available(role) or (limit >= 0 and employed_for_role + pending_for_role >= limit) or not has_assignable_resident()
		job_rows.append({
			"label": "%s\nEmployed %d%s  Hiring %d" % [workforce_role_label(role), employed_for_role, capacity, pending_for_role],
			"role": role,
			"dismiss_disabled": dismiss_disabled,
			"dismiss_tooltip": blocked_tooltip if not can_manage_professions else "Dismiss one resident from this job",
			"assign_disabled": assign_disabled,
			"assign_tooltip": blocked_tooltip if (assign_disabled and role != "official" and not can_manage_professions) else "Assign a resident without permanent work",
		})
		shown_jobs += 1
	var no_jobs_text := "No workplaces are available. Registered residents remain without permanent work." if shown_jobs == 0 else ""

	var daily_order_rows: Array[String] = []
	for role in daily_order_roles():
		daily_order_rows.append("Daily order: %s  %d" % [workforce_role_label(role), daily_order_role_count(role)])

	var unregistered_header := ""
	var unregistered_rows: Array[Dictionary] = []
	var unregistered_residents := citizens_with_employment_states([Citizen.EmploymentState.UNREGISTERED, Citizen.EmploymentState.REGISTERING])
	if not unregistered_residents.is_empty():
		unregistered_header = "Unregistered residents"
		for citizen in unregistered_residents:
			var citizen_disabled: bool = not can_manage_professions or citizen.employment_state != Citizen.EmploymentState.UNREGISTERED or simulation.employment_center_position() == Vector3.INF
			unregistered_rows.append({
				"label": "%s%s" % [citizen.role_label(), " (registering)" if citizen.employment_state == Citizen.EmploymentState.REGISTERING else ""],
				"button_text": "Registering" if citizen.employment_state == Citizen.EmploymentState.REGISTERING else "Register",
				"tooltip": blocked_tooltip if not can_manage_professions else "Register this resident for workforce assignment",
				"disabled": citizen_disabled,
				"citizen": citizen,
			})

	var state := {
		"title_text": "Employment: %d residents" % total,
		"summary_text": "Employed %d   Registering %d   No permanent work %d   Unregistered %d" % [employed, hiring, no_permanent_work, unregistered],
		"job_rows": job_rows,
		"no_jobs_text": no_jobs_text,
		"daily_orders_available": "Available %d" % daily_order_role_count(""),
		"daily_order_rows": daily_order_rows,
		"unregistered_header": unregistered_header,
		"unregistered_rows": unregistered_rows,
	}
	simulation.workforce_menu.update_state(state)


func employment_resident_count() -> int:
	var count := 0
	for citizen in simulation.citizens:
		count += 1 if not citizen.is_player_controlled else 0
	return count


func employment_state_count(state: int) -> int:
	var count := 0
	for citizen in simulation.citizens:
		if not citizen.is_player_controlled and citizen.employment_state == state:
			count += 1
	return count


func daily_order_role_count(role: String) -> int:
	var count := 0
	for citizen in simulation.citizens:
		if not citizen.is_player_controlled and citizen.daily_order_role == role:
			count += 1
	return count


func employment_role_count(role: String, state: int) -> int:
	var count := 0
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.employment_state != state:
			continue
		var citizen_role: String = citizen.permanent_role if state == Citizen.EmploymentState.EMPLOYED else citizen.pending_employment_role
		if citizen_role == role:
			count += 1
	return count


func citizens_with_employment_states(states: Array) -> Array[Citizen]:
	var result: Array[Citizen] = []
	for citizen in simulation.citizens:
		if not citizen.is_player_controlled and citizen.employment_state in states:
			result.append(citizen)
	return result


func has_assignable_resident() -> bool:
	for citizen in simulation.citizens:
		if not citizen.is_player_controlled and citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
			return true
	return false


func remove_worker_from_role(role: String) -> void:
	if not simulation.player_can_manage_permanent_professions():
		simulation.show_labor_command_blocked()
		return
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.daily_order_role == role:
			citizen.clear_daily_order()
		elif citizen.permanent_role == role or citizen.pending_employment_role == role:
			citizen.release_to_no_permanent_work()
			citizen.assigned_dig_site = null
		else:
			continue
		simulation._update_workers()
		refresh_workforce_menu()
		refresh_campfire_occupancy_button()
		return


func assign_unemployed_worker(role: String) -> void:
	if role != "official" and not simulation.player_can_manage_permanent_professions():
		simulation.show_labor_command_blocked()
		return
	if not simulation.is_role_available(role):
		return
	var best: Citizen = null
	var best_score := -INF
	for citizen in simulation.citizens:
		if citizen.is_player_controlled:
			continue
		if citizen.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
			var score := float(citizen.skills.get(role, 0.0))
			if citizen.preferred_role() == role:
				score += 1.0
			if score > best_score:
				best = citizen
				best_score = score
	if best != null:
		simulation.selected_builder = best
		if role == "gather_branches":
			simulation._set_manual_specialist_employment(best, role)
		else:
			simulation._set_selected_work_role(role)
		refresh_workforce_menu()
		refresh_campfire_occupancy_button()


func enable_auto_for_citizen(citizen: Citizen) -> void:
	if not simulation.player_can_manage_permanent_professions():
		simulation.show_labor_command_blocked()
		return
	if not is_instance_valid(citizen) or citizen.is_player_controlled:
		return
	citizen.request_no_permanent_work_registration()
	simulation._update_workers()
	refresh_workforce_menu()
	refresh_campfire_occupancy_button()
