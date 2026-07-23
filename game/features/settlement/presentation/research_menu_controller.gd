class_name ResearchMenuController
extends RefCounted

const BuildingCatalog = preload("res://game/features/buildings/domain/building_catalog.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_research_menu() -> void:
	if simulation == null or simulation.ui_manager.research_menu == null:
		return
	simulation.ui_manager.campfire_menu.visible = false
	simulation.ui_manager.research_menu.visible = true
	refresh_research_menu()


func hide_research_menu() -> void:
	if simulation == null:
		return
	if simulation.ui_manager.research_menu != null:
		simulation.ui_manager.research_menu.visible = false
	simulation.ui_manager.campfire_menu.visible = true


func get_available_researcher(_required_skill: String) -> Citizen:
	for citizen in simulation.citizens:
		if citizen.work_position_locked and citizen.work_position_role in ["researcher", "official"]:
			if is_instance_valid(citizen.work_position_node) and citizen.work_position_node == simulation.campfire_node:
				return citizen
		if citizen.permanent_role == "official" and citizen.employment_workplace == simulation.campfire_node and citizen.state == Citizen.State.OFFICIAL_WORK:
			return citizen
		if citizen.has_active_daily_order() and citizen.daily_order_role == "researcher" and citizen.state == Citizen.State.RESEARCHING:
			return citizen
	return null


func refresh_research_menu() -> void:
	if simulation == null or simulation.ui_manager.research_menu == null:
		return
	var tech_rows: Array[Dictionary] = []
	for tech_id in simulation.building_research_service.visible_tech_ids():
		var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
		var researcher := get_available_researcher(str(tech.get("required_skill", "construction")))
		var research_state: Dictionary = simulation.building_research_service.menu_state(tech_id, researcher != null)
		var effect_str: String = str(tech.get("effect", ""))
		tech_rows.append({
			"title": "%s (%s)" % [tech.name, research_state.cost_text],
			"description": "Duration: %ds | Skill: %s%s" % [int(research_state.duration), str(research_state.required_skill).capitalize(), " | %s" % effect_str if not effect_str.is_empty() else ""],
			"completed": bool(research_state.completed),
			"active": bool(research_state.active),
			"progress_pct": int(research_state.progress_pct),
			"can_start": bool(research_state.can_start),
			"tooltip": simulation.building_research_service.message_for_reason(research_state.reason) if not bool(research_state.can_start) else "",
			"tech_id": tech_id,
		})
	simulation.ui_manager.research_menu.update_state({"title_text": "Research (Campfire)", "tech_rows": tech_rows})


func start_research(tech_id: String) -> void:
	if not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		return
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	if simulation.settlement.active_research_tech_id != "":
		simulation._update_interface("Already researching another technology.")
		return
	if not is_instance_valid(simulation.campfire_node) or not simulation._is_fire_lit(simulation.campfire_node):
		simulation._update_interface("Research requires an active Campfire.")
		return

	var researcher := get_available_researcher(tech.required_skill)
	if researcher == null:
		simulation._update_interface("Assign a researcher to the civic post or occupy it in first person.")
		return

	if simulation.building_research_service.start_block_reason(tech_id, true) != BuildingResearchServiceScript.REASON_OK:
		simulation._update_interface("Research prerequisites or resources are missing.")
		return
	if not simulation.building_research_service.start_research(tech_id, researcher.ai_id):
		simulation._update_interface("Research prerequisites or resources are missing.")
		return

	simulation._update_interface("Research started: %s. %s is studying at the Campfire." % [tech.name, researcher.role_label()])
	refresh_research_menu()
	if simulation.campfire_menu_controller != null:
		simulation.campfire_menu_controller.refresh_campfire_menu()


func cancel_research() -> void:
	if simulation.settlement.active_research_tech_id == "":
		return
	simulation._cancel_active_building_research(true, "Research cancelled. Resources refunded.")
	refresh_research_menu()
	if simulation.campfire_menu_controller != null:
		simulation.campfire_menu_controller.refresh_campfire_menu()
