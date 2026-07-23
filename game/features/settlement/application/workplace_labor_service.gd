class_name WorkplaceLaborService
extends RefCounted

## Manages workplace labor permissions, officer checks, permanent profession rules,
## employment center positions, and role checks (courier, cook, factory worker).

const S = preload("res://game/features/ui/domain/game_strings.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _campfire_node_getter: Callable
var _canteen_getter: Callable
var _canteen_position_getter: Callable
var _warehouse_positions: Array[Vector3] = []
var _construction_sites: Array = []
var _demolition_sites: Array = []
var _tree_positions: Array[Vector3] = []
var _pond_positions: Array[Vector3] = []
var _craft_tent_positions: Array[Vector3] = []
var _dig_sites: Array = []
var _is_fire_lit: Callable
var _update_interface: Callable
var _available_employer_capacity: Callable
var _builder_job_capacity: Callable
var _can_work_at_dig_site: Callable
var _employment_centre_building_getter: Callable


func configure(
	p_settlement: SettlementState,
	p_citizens: Array,
	p_campfire_node_getter: Callable,
	p_canteen_getter: Callable,
	p_canteen_position_getter: Callable,
	p_warehouse_positions: Array[Vector3],
	p_construction_sites: Array,
	p_demolition_sites: Array,
	p_tree_positions: Array[Vector3],
	p_pond_positions: Array[Vector3],
	p_craft_tent_positions: Array[Vector3],
	p_dig_sites: Array,
	p_is_fire_lit: Callable,
	p_update_interface: Callable,
	p_available_employer_capacity: Callable,
	p_builder_job_capacity: Callable,
	p_can_work_at_dig_site: Callable,
	p_employment_centre_building_getter: Callable
) -> void:
	_settlement = p_settlement
	_citizens = p_citizens
	_campfire_node_getter = p_campfire_node_getter
	_canteen_getter = p_canteen_getter
	_canteen_position_getter = p_canteen_position_getter
	_warehouse_positions = p_warehouse_positions
	_construction_sites = p_construction_sites
	_demolition_sites = p_demolition_sites
	_tree_positions = p_tree_positions
	_pond_positions = p_pond_positions
	_craft_tent_positions = p_craft_tent_positions
	_dig_sites = p_dig_sites
	_is_fire_lit = p_is_fire_lit
	_update_interface = p_update_interface
	_available_employer_capacity = p_available_employer_capacity
	_builder_job_capacity = p_builder_job_capacity
	_can_work_at_dig_site = p_can_work_at_dig_site
	_employment_centre_building_getter = p_employment_centre_building_getter


func employment_center_position() -> Vector3:
	var campfire: Node3D = _campfire_node_getter.call()
	if is_instance_valid(campfire):
		if campfire.has_meta("entrance_position"):
			return campfire.get_meta("entrance_position")
		return campfire.get_meta("service_position", campfire.global_position)
	return Vector3.INF


func employment_centre_building() -> Node3D:
	var campfire: Node3D = _campfire_node_getter.call()
	return campfire if is_instance_valid(campfire) else null


func officer_holder() -> Citizen:
	for citizen in _citizens:
		if is_instance_valid(citizen) and citizen.permanent_role == "official":
			return citizen
	return null


func officer_exists() -> bool:
	return officer_holder() != null


func player_can_command_labor() -> bool:
	return true


func labor_command_block_message() -> String:
	return ""


func player_can_manage_permanent_professions() -> bool:
	return officer_exists()


func permanent_profession_block_message() -> String:
	return S.AUTOMATION_REQUIRES_OFFICER


func show_labor_command_blocked() -> void:
	_update_interface.call(permanent_profession_block_message())


func work_role_for(citizen: Citizen) -> String:
	return citizen.permanent_role if is_instance_valid(citizen) else ""


func is_factory_worker_active(citizen: Citizen, factory: Node3D) -> bool:
	return is_instance_valid(citizen) and citizen.factory == factory and citizen.specialization == "factory_worker" and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]


func has_courier() -> bool:
	for citizen in _citizens:
		if is_instance_valid(citizen) and citizen.can_handle_entry_logistics():
			return true
	return false


func has_cook() -> bool:
	var canteen: Node3D = _canteen_getter.call()
	if not _is_fire_lit.call(canteen):
		return false
	var canteen_position: Vector3 = _canteen_position_getter.call()
	for citizen in _citizens:
		if not is_instance_valid(citizen) or not is_instance_valid(canteen):
			continue
		if not citizen.global_position.distance_to(canteen_position) <= 2.2:
			continue
		if not citizen.is_player_controlled:
			if citizen.specialization == "cook":
				return true
			if citizen.daily_order_role == "cook" and citizen.has_active_daily_order():
				return true
		if citizen.work_position_locked and citizen.work_position_role == "cook":
			return true
	return false


func is_role_available(role: String) -> bool:
	if not _settlement.construction_gloves_available() and _settlement.wellbeing < 30 and role in ["construction", "gather_branches", "gather_grass", "gather_food", "forestry", "farming", "excavation", "factory_worker", "craftsman"]:
		return false
	match role:
		"": return true
		"courier": return not _warehouse_positions.is_empty()
		"construction":
			return (not _construction_sites.is_empty() or not _demolition_sites.is_empty()) and (_settlement.era < SettlementState.Era.STONE or _builder_job_capacity.call() > 0)
		"forestry": return _available_employer_capacity.call("forestry") > 0 and bool(_settlement.tools.get("axe", false)) and bool(_settlement.tools.get("hand_saw", false)) and not _tree_positions.is_empty() and not _warehouse_positions.is_empty()
		"farming": return _available_employer_capacity.call("farming") > 0 and not _warehouse_positions.is_empty()
		"excavation":
			if _dig_sites.is_empty() or _warehouse_positions.is_empty():
				return false
			for site in _dig_sites:
				if _can_work_at_dig_site.call(site):
					return true
			return false
		"gather_branches": return not _tree_positions.is_empty()
		"gather_grass": return _settlement.era == SettlementState.Era.TENT
		"gather_food": return _available_employer_capacity.call("gather_food") > 0
		"gather_water": return bool(_settlement.tools.get("bucket", false)) and not _pond_positions.is_empty() and not _warehouse_positions.is_empty()
		"cook": return _available_employer_capacity.call("cook") > 0
		"teacher": return _available_employer_capacity.call("teacher") > 0
		"seller": return _available_employer_capacity.call("seller") > 0
		"factory_worker": return _available_employer_capacity.call("factory_worker") > 0
		"engineer": return _available_employer_capacity.call("engineer") > 0
		"craftsman": return not _craft_tent_positions.is_empty()
		"official": return _settlement.is_research_completed("official") and is_instance_valid(_employment_centre_building_getter.call())
	return false


func is_daily_order_role_available(role: String) -> bool:
	match role:
		"cook": return _available_employer_capacity.call("cook") > 0
		"researcher": return not _settlement.is_research_completed("official") and is_instance_valid(_employment_centre_building_getter.call()) and _is_fire_lit.call(_employment_centre_building_getter.call())
		"gather_water": return bool(_settlement.tools.get("bucket", false)) and not _pond_positions.is_empty() and not _warehouse_positions.is_empty()
	return true

