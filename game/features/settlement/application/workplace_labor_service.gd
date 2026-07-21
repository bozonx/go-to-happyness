class_name WorkplaceLaborService
extends RefCounted

## Manages workplace labor permissions, officer checks, permanent profession rules,
## employment center positions, and role checks (courier, cook, factory worker).

var simulation: Node


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func employment_center_position() -> Vector3:
	if is_instance_valid(simulation.campfire_node):
		if simulation.campfire_node.has_meta("entrance_position"):
			return simulation.campfire_node.get_meta("entrance_position")
		return simulation.campfire_node.get_meta("service_position", simulation.campfire_node.global_position)
	return Vector3.INF


func employment_centre_building() -> Node3D:
	return simulation.campfire_node if is_instance_valid(simulation.campfire_node) else null


func officer_holder() -> Citizen:
	for citizen in simulation.citizens:
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
	return "Автоматизация труда требует чиновника. Назначьте свободного жителя исследователем, изучите технологию «Чиновник», затем повысьте его у поста."


func show_labor_command_blocked() -> void:
	simulation._update_interface(permanent_profession_block_message())


func work_role_for(citizen: Citizen) -> String:
	return citizen.permanent_role if is_instance_valid(citizen) else ""


func is_factory_worker_active(citizen: Citizen, factory: Node3D) -> bool:
	return is_instance_valid(citizen) and citizen.factory == factory and citizen.specialization == "factory_worker" and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]


func has_courier() -> bool:
	for citizen in simulation.citizens:
		if is_instance_valid(citizen) and citizen.can_handle_entry_logistics():
			return true
	return false


func has_cook() -> bool:
	if not simulation._is_fire_lit(simulation.canteen):
		return false
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen) or not is_instance_valid(simulation.canteen):
			continue
		if not citizen.global_position.distance_to(simulation.canteen_position) <= 2.2:
			continue
		if not citizen.is_player_controlled:
			if citizen.specialization == "cook":
				return true
			if citizen.daily_order_role == "cook" and citizen.has_active_daily_order():
				return true
		if citizen.work_position_locked and citizen.work_position_role == "cook":
			return true
	return false
