class_name SettlementResearchController
extends RefCounted

const S = preload("res://game/features/ui/domain/game_strings.gd")

## Handles building research progression, civic post assignment,
## official appointment/dismissal, and employment centre activation.
## Extracted from SettlementGame to reduce monolithic file size.

var game: SettlementGame


func _init(p_game: SettlementGame) -> void:
	game = p_game


func update_building_research(delta: float) -> void:
	if game.settlement.active_research_tech_id == "":
		return

	var tech_id := game.settlement.active_research_tech_id
	if not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		cancel_active_building_research(true, "Research cancelled: invalid technology.")
		return
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	if not is_instance_valid(game.campfire_node) or not game._is_fire_lit(game.campfire_node):
		cancel_active_building_research(true, "Research cancelled: the Campfire is unavailable. Resources refunded.")
		return
	var worker: Citizen = null

	for citizen in game.citizens:
		if citizen.ai_id == game.settlement.active_research_worker_id:
			worker = citizen
			break

	if worker == null:
		cancel_active_building_research(true, "Research cancelled: researcher citizen is no longer available. Resources refunded.")
		return

	# The researcher must be physically at the campfire work position
	# (FPP researcher/official) or actively performing a daily research order.
	var is_at_research_position := worker.work_position_locked and worker.work_position_role in ["researcher", "official"] and worker.work_position_node == game.campfire_node
	if not is_at_research_position and worker.state != Citizen.State.RESEARCHING:
		cancel_active_building_research(true, "Research cancelled: researcher stopped working. Resources refunded.")
		return

	var skill_name: String = tech.required_skill
	var skill_val := float(worker.skills.get(skill_name, 0.0))
	var speed_mult := 1.0 + skill_val

	var research_pos: Vector3 = game.campfire_node.get_meta("service_position", game.campfire_node.global_position)
	if worker.global_position.distance_to(research_pos) > 0.5:
		return
	game.building_research_service.advance_active(delta, speed_mult)

	if game.ui_manager.research_menu != null and game.ui_manager.research_menu.visible:
		if game.research_menu_controller != null:
			game.research_menu_controller.refresh_research_menu()

	if game.building_research_service.is_active_complete():
		var completion: Dictionary = game.building_research_service.complete_active()
		var skill_to_upgrade: String = str(completion.get("reward_skill", "construction"))
		worker.skills[skill_to_upgrade] = minf(1.0, float(worker.skills.get(skill_to_upgrade, 0.0)) + 0.20)

		# Do not disrupt a player-controlled citizen who is still at the post.
		if not worker.is_player_controlled:
			if worker.permanent_role == "official" and is_instance_valid(game.campfire_node):
				worker.assign_official_work(game.campfire_node.get_meta("service_position", game.campfire_node.global_position))
			else:
				worker.idle()
		var b_name := str(completion.get("display_name", tech_id))
		game._update_interface("Research completed: %s unlocked! %s skill improved by 20%%." % [b_name, skill_to_upgrade.capitalize()])

		if game.campfire_menu_controller != null:
			game.campfire_menu_controller.refresh_campfire_menu()
		if game.building_menu_controller != null:
			game.building_menu_controller.refresh_build_menu()
		if game.ui_manager.research_menu != null and game.ui_manager.research_menu.visible:
			if game.research_menu_controller != null:
				game.research_menu_controller.refresh_research_menu()


func cancel_active_building_research(refund: bool, message: String) -> void:
	var worker_id := game.settlement.active_research_worker_id
	var worker: Citizen = null
	for citizen in game.citizens:
		if citizen.ai_id == worker_id:
			worker = citizen
			break
	if worker != null:
		if worker.permanent_role == "official" and is_instance_valid(game.campfire_node):
			worker.assign_official_work(game.campfire_node.get_meta("service_position", game.campfire_node.global_position))
		else:
			worker.idle()
	game.building_research_service.cancel_active(refund)
	game._update_interface(message)
	if game.campfire_menu_controller != null:
		game.campfire_menu_controller.refresh_campfire_menu()


func handle_civic_post_assignment() -> void:
	var centre := game.selected_campfire if is_instance_valid(game.selected_campfire) else game._employment_centre_building()
	if not is_instance_valid(centre) or not game.settlement.is_research_completed("official"):
		return
	var researcher := daily_researcher_at(centre)
	if researcher == null:
		game._update_interface("Assign a daily researcher and wait until they reach the civic post.")
		return
	appoint_official(researcher, centre)


func daily_researcher_at(centre: Node3D) -> Citizen:
	if not is_instance_valid(centre):
		return null
	var position: Vector3 = centre.get_meta("service_position", centre.global_position)
	for citizen in game.citizens:
		if is_instance_valid(citizen) and citizen.daily_order_role == "researcher" and citizen.global_position.distance_to(position) <= game.OFFICER_POST_RADIUS:
			return citizen
	return null


func appoint_official(citizen: Citizen, workplace: Node3D = null, require_at_post := true) -> bool:
	# Promotion requires both the researched technology and physical occupation
	# of the civic post. The unit-menu appointment is the explicit exception:
	# it is unlocked by the research and sends the new officer to the post by AI.
	if citizen == null or not game.settlement.is_research_completed("official"):
		return false
	var centre := workplace if is_instance_valid(workplace) else game._employment_centre_building()
	if not is_instance_valid(centre) or (require_at_post and citizen.global_position.distance_to(game._employment_center_position()) > game.OFFICER_POST_RADIUS):
		return false
	for other in game.citizens:
		if not is_instance_valid(other) or other == citizen or other.permanent_role != "official":
			continue
		dismiss_official(other)
	citizen.setup_specialization("official")
	citizen.clear_daily_order()
	citizen.assigned_dig_site = null
	citizen.pending_employment_role = ""
	citizen.pending_employment_workplace = null
	citizen.permanent_role = "official"
	citizen.employment_workplace = centre
	citizen.employment_state = Citizen.EmploymentState.EMPLOYED
	if not is_instance_valid(citizen.employment_workplace):
		citizen.active_role = ""
		return false
	if game.citizen_ai != null:
		game.citizen_ai.request_decision_refresh()
	return true


func dismiss_official(citizen: Citizen) -> void:
	if citizen == null or citizen.permanent_role != "official":
		return
	if game.settlement.active_research_tech_id != "" and game.settlement.active_research_worker_id == citizen.ai_id:
		cancel_active_building_research(true, "Research cancelled: the official left the post. Resources refunded.")
	citizen.idle()
	citizen.setup_specialization("unassigned")
	citizen.clear_daily_order()
	citizen.assigned_dig_site = null
	citizen.pending_employment_role = ""
	citizen.pending_employment_workplace = null
	citizen.permanent_role = ""
	citizen.employment_workplace = null
	citizen.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	citizen.active_role = ""
	game._update_interface(S.CITIZEN_LEFT_OFFICER_POST % citizen.role_label())
	game._update_workers()
	if game.building_menu_controller != null:
		game.building_menu_controller.refresh_build_menu()


func activate_employment_centre(centre: Node3D) -> void:
	if not is_instance_valid(centre):
		return
	var service_position: Vector3 = centre.get_meta("service_position", centre.global_position)
	for citizen in game.citizens:
		if not is_instance_valid(citizen) or citizen.permanent_role != "official":
			continue
		citizen.employment_workplace = centre
		citizen.pending_employment_workplace = null
		citizen.employment_state = Citizen.EmploymentState.EMPLOYED
		if citizen.is_player_controlled:
			# A player-controlled official is already physically at a work position;
			# do not cancel their current FPP state.
			continue
		# Start the post in the same hand-off so another scheduler tick cannot
		# replace the job before the route starts.
		if game._is_work_time():
			citizen.assign_official_work(service_position)
		else:
			citizen.idle()
	game._update_workers()


func set_manual_specialist_employment(citizen: Citizen, role: String) -> bool:
	if not game._player_can_manage_permanent_professions():
		if game.workplace_labor_service != null:
			game.workplace_labor_service.show_labor_command_blocked()
		return false
	if citizen.employment_state != Citizen.EmploymentState.NO_PERMANENT_WORK:
		return false
	citizen.idle()
	citizen.begin_employment_processing(game._employment_center_position(), role, game._employer_for_role(role))
	return true
