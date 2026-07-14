class_name BuildingResearchService
extends RefCounted

const REASON_OK := &"ok"
const REASON_UNKNOWN := &"unknown"
const REASON_LATER_ERA := &"later_era"
const REASON_COMPLETED := &"completed"
const REASON_PREREQUISITES := &"prerequisites"
const REASON_NO_WORKER := &"no_worker"
const REASON_NOT_ENOUGH_RESOURCES := &"not_enough_resources"
const REASON_ALREADY_ACTIVE := &"already_active"

var settlement: SettlementState


func configure(next_settlement: SettlementState) -> void:
	settlement = next_settlement


func visible_tech_ids() -> Array[String]:
	var ids: Array[String] = []
	for tech_id in BuildingCatalog.RESEARCH_TECHS:
		if _is_visible_for_era(str(tech_id)):
			ids.append(str(tech_id))
	return ids


func menu_state(tech_id: String, has_worker: bool) -> Dictionary:
	if settlement == null or not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		return {"visible": false, "reason": REASON_UNKNOWN}
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	if not _is_visible_for_era(tech_id):
		return {"visible": false, "reason": REASON_LATER_ERA}
	if settlement.is_research_completed(tech_id):
		return _base_menu_state(tech_id, tech, REASON_COMPLETED, has_worker)
	if settlement.active_research_tech_id == tech_id:
		var state := _base_menu_state(tech_id, tech, REASON_OK, has_worker)
		state.active = true
		state.progress_pct = active_progress_pct()
		return state
	var reason := start_block_reason(tech_id, has_worker)
	return _base_menu_state(tech_id, tech, reason, has_worker)


func start_block_reason(tech_id: String, has_worker: bool) -> StringName:
	if settlement == null or not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		return REASON_UNKNOWN
	if settlement.active_research_tech_id != "":
		return REASON_ALREADY_ACTIVE
	if settlement.is_research_completed(tech_id):
		return REASON_COMPLETED
	if not _is_visible_for_era(tech_id) or not _prerequisites_met(tech_id):
		return REASON_PREREQUISITES
	if not has_worker:
		return REASON_NO_WORKER
	if not settlement.can_afford_research(tech_id):
		return REASON_NOT_ENOUGH_RESOURCES
	if not settlement.can_start_building_research(tech_id):
		return REASON_PREREQUISITES
	return REASON_OK


func start_research(tech_id: String, researcher_id: int) -> bool:
	if start_block_reason(tech_id, true) != REASON_OK:
		return false
	if not settlement.pay_for_research(tech_id):
		return false
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	settlement.active_research_tech_id = tech_id
	settlement.active_research_worker_id = researcher_id
	settlement.active_research_duration = float(tech.get("base_duration", 0.0))
	settlement.active_research_remaining_time = settlement.active_research_duration
	return true


func advance_active(delta: float, speed_multiplier: float) -> void:
	if settlement == null or settlement.active_research_tech_id.is_empty():
		return
	settlement.active_research_remaining_time -= delta * maxf(0.0, speed_multiplier)


func is_active_complete() -> bool:
	return settlement != null and not settlement.active_research_tech_id.is_empty() and settlement.active_research_remaining_time <= 0.0


func complete_active() -> Dictionary:
	if settlement == null or settlement.active_research_tech_id.is_empty():
		return {}
	var tech_id := settlement.active_research_tech_id
	if not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		clear_active()
		return {}
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	var unlocked_target := settlement.complete_research(tech_id)
	var required_skill := str(tech.get("required_skill", "construction"))
	var reward_skill := str(tech.get("reward_skill", "craftsman" if required_skill == "craftsman" else "construction"))
	var result := {
		"tech_id": tech_id,
		"tech": tech,
		"unlocked_target": unlocked_target,
		"display_name": display_name(tech_id),
		"reward_skill": reward_skill,
	}
	clear_active()
	return result


func cancel_active(refund: bool) -> String:
	if settlement == null or settlement.active_research_tech_id.is_empty():
		return ""
	var tech_id := settlement.active_research_tech_id
	if refund:
		for resource_type in BuildingCatalog.research_resources(tech_id):
			settlement.add(resource_type, BuildingCatalog.research_cost(tech_id, resource_type))
	clear_active()
	return tech_id


func clear_active() -> void:
	if settlement == null:
		return
	settlement.active_research_tech_id = ""
	settlement.active_research_worker_id = -1
	settlement.active_research_remaining_time = 0.0
	settlement.active_research_duration = 0.0


func active_progress_pct() -> float:
	if settlement == null or settlement.active_research_duration <= 0.0:
		return 0.0
	return clampf((1.0 - (settlement.active_research_remaining_time / settlement.active_research_duration)) * 100.0, 0.0, 100.0)


func cost_text(tech_id: String) -> String:
	var costs_array: Array[String] = []
	for resource_type in BuildingCatalog.RESEARCH_COSTS.get(tech_id, {}):
		costs_array.append("%d %s" % [BuildingCatalog.research_cost(tech_id, str(resource_type)), resource_type])
	return ", ".join(costs_array) if not costs_array.is_empty() else "free"


func display_name(tech_id: String) -> String:
	if not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		return tech_id
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	if tech.has("target_building"):
		var target := str(tech.get("target_building", ""))
		return str(BuildingCatalog.definition_for(target).get("name", target))
	return str(tech.get("name", tech_id))


func message_for_reason(reason: StringName) -> String:
	match reason:
		REASON_PREREQUISITES:
			return "Research the previous level first."
		REASON_NO_WORKER:
			return "Requires an idle resident."
		REASON_NOT_ENOUGH_RESOURCES:
			return "Not enough resources."
		REASON_ALREADY_ACTIVE:
			return "Another research is already active."
		REASON_COMPLETED:
			return "Already researched."
		_:
			return ""


func _base_menu_state(tech_id: String, tech: Dictionary, reason: StringName, has_worker: bool) -> Dictionary:
	return {
		"visible": true,
		"active": false,
		"completed": reason == REASON_COMPLETED,
		"can_start": reason == REASON_OK,
		"reason": reason,
		"title": str(tech.get("name", tech_id)),
		"duration": float(tech.get("base_duration", 0.0)),
		"required_skill": str(tech.get("required_skill", "construction")),
		"effect": str(tech.get("effect", "")),
		"cost_text": cost_text(tech_id),
		"has_worker": has_worker,
		"progress_pct": 0.0,
	}


func _is_visible_for_era(tech_id: String) -> bool:
	if settlement == null or not BuildingCatalog.RESEARCH_TECHS.has(tech_id):
		return false
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	var target_building := str(tech.get("target_building", ""))
	if target_building.is_empty():
		return true
	return BuildingCatalog.era_for(target_building) <= settlement.era


func _prerequisites_met(tech_id: String) -> bool:
	var tech: Dictionary = BuildingCatalog.RESEARCH_TECHS[tech_id]
	for prerequisite in tech.get("prerequisites", []):
		if BuildingCatalog.RESEARCH_TECHS.has(prerequisite):
			if not settlement.is_research_completed(str(prerequisite)):
				return false
		elif not settlement.has_building(str(prerequisite)):
			return false
	return true
