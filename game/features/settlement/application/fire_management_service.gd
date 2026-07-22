class_name FireManagementService
extends RefCounted

const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")

var building_registry: RefCounted
var event_service: RefCounted
var settlement: RefCounted
var day_cycle: RefCounted

var game_minutes_query: Callable
var campfire_node_query: Callable
var add_message_callback: Callable
var refresh_living_statuses_callback: Callable
var wellbeing_decay_callback: Callable

func setup(
	building_registry_ref: RefCounted,
	event_service_ref: RefCounted,
	settlement_ref: RefCounted,
	day_cycle_ref: RefCounted,
	game_minutes_fn: Callable = Callable(),
	campfire_node_fn: Callable = Callable(),
	add_message_fn: Callable = Callable(),
	refresh_living_fn: Callable = Callable(),
	wellbeing_decay_fn: Callable = Callable()
) -> void:
	building_registry = building_registry_ref
	event_service = event_service_ref
	settlement = settlement_ref
	day_cycle = day_cycle_ref
	game_minutes_query = game_minutes_fn
	campfire_node_query = campfire_node_fn
	add_message_callback = add_message_fn
	refresh_living_statuses_callback = refresh_living_fn
	wellbeing_decay_callback = wellbeing_decay_fn

func fire_state_for(building: Node3D) -> RefCounted:
	if not is_instance_valid(building):
		return FireSourceStateScript.new()
	return FireSourceStateScript.from_values(
		int(building.get_meta("fire_fuel", 0)),
		int(building.get_meta("fire_reserved", 0)),
		bool(building.get_meta("fire_lit", true)),
		int(building.get_meta("fire_embers_until", -1))
	)

func is_managed_fire_source(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	return building_registry.building_type_for_node(building) in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]

func apply_fire_state(building: Node3D, fire_state: RefCounted) -> void:
	if not is_instance_valid(building) or fire_state == null:
		return
	var minutes: int = int(game_minutes_query.call()) if game_minutes_query.is_valid() else 0
	building.set_meta("fire_fuel", fire_state.fuel)
	building.set_meta("fire_reserved", fire_state.reserved_fuel)
	building.set_meta("fire_lit", fire_state.is_burning_at(minutes))
	building.set_meta("fire_embers_until", fire_state.embers_until_minute)

func is_fire_lit(building: Node3D) -> bool:
	if not is_instance_valid(building):
		return false
	if not is_managed_fire_source(building):
		return bool(building.get_meta("fire_lit", true))
	var minutes: int = int(game_minutes_query.call()) if game_minutes_query.is_valid() else 0
	return fire_state_for(building).is_burning_at(minutes)

func fire_smoke_work_multiplier(position_on_board: Vector3) -> float:
	var is_smoky: bool = event_service != null and event_service.log.has_flag(&"smoky_firewood")
	if not is_smoky:
		return 1.0
	if building_registry != null:
		for record in building_registry.records():
			var building: Node3D = record.node
			if is_instance_valid(building) and is_fire_lit(building) and building.global_position.distance_to(position_on_board) <= 15.0:
				return 0.70
	return 1.0

func campfire_story_efficiency_multiplier(role: String) -> float:
	if settlement != null and "campfire_story_effect" in settlement:
		var current_day: int = int(day_cycle.current_day) if day_cycle != null and "current_day" in day_cycle else 0
		if settlement.campfire_story_effect == "plan" and settlement.campfire_story_target_role == role and current_day == settlement.campfire_story_target_day:
			return 1.15
	return 1.0

func update_fire_status(host_node: Node, branches_count: int) -> void:
	var minute: int = int(game_minutes_query.call()) if game_minutes_query.is_valid() else 0
	var consume_tick: bool = minute % (4 * 60) == 0 and int(host_node.get_meta("last_fire_tick", -1)) != minute
	if consume_tick:
		host_node.set_meta("last_fire_tick", minute)

	var campfire_node: Node3D = campfire_node_query.call() if campfire_node_query.is_valid() else null

	if building_registry != null:
		for record in building_registry.records():
			var building: Node3D = record.node
			if not is_instance_valid(building) or record.building_type not in ["campfire", "campfire_lvl2", "campfire_lvl3", "cook_campfire", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
				continue
			var fire_state := fire_state_for(building)
			if consume_tick and fire_state.is_burning_at(minute):
				fire_state.consume(1, minute)
			apply_fire_state(building, fire_state)
			update_fire_visual(building, fire_state, minute)
			report_fire_phase_change(building, fire_state, minute, campfire_node, branches_count)

	if consume_tick and is_instance_valid(campfire_node) and fire_state_for(campfire_node).phase_at(minute) == FireSourceStateScript.Phase.OUT:
		if wellbeing_decay_fn_valid():
			wellbeing_decay_callback.call()

	if refresh_living_statuses_callback.is_valid():
		refresh_living_statuses_callback.call()

func wellbeing_decay_fn_valid() -> bool:
	return wellbeing_decay_callback != null and wellbeing_decay_callback.is_valid()

func update_fire_visual(building: Node3D, fire_state: RefCounted, minute: int) -> void:
	var phase: int = fire_state.phase_at(minute)
	for child in building.get_children():
		if child is OmniLight3D:
			child.visible = phase != FireSourceStateScript.Phase.OUT
			child.light_energy = 0.22 if phase == FireSourceStateScript.Phase.EMBERS else 1.0

func report_fire_phase_change(building: Node3D, fire_state: RefCounted, minute: int, campfire_node: Node3D, branches_count: int) -> void:
	var phase: int = fire_state.phase_at(minute)
	var phase_name := str(FireSourceStateScript.Phase.keys()[phase]).to_lower()
	var previous_phase := str(building.get_meta("fire_phase", phase_name))
	if previous_phase == phase_name:
		return
	building.set_meta("fire_phase", phase_name)
	var is_main := building == campfire_node
	var fire_name := "Главный костер" if is_main else "Костер для готовки"
	match phase:
		FireSourceStateScript.Phase.DYING:
			if fire_state.reserved_fuel <= 0 and branches_count <= 0:
				_send_msg("%s догорает: топлива осталось примерно на 4 часа." % fire_name)
		FireSourceStateScript.Phase.EMBERS:
			_send_msg("%s превратился в угли. Доставьте ветки в течение 2 часов, чтобы он разгорелся сам." % fire_name)
		FireSourceStateScript.Phase.OUT:
			var consequence := "Оформление жителей и исследования приостановлены." if is_main else "Следующий прием пищи будет сырым рационом."
			_send_msg("%s погас. %s" % [fire_name, consequence])
		FireSourceStateScript.Phase.BURNING:
			if previous_phase in ["embers", "out", "dying"]:
				_send_msg("%s снова горит." % fire_name)

func _send_msg(text: String) -> void:
	if add_message_callback.is_valid():
		add_message_callback.call(text)
