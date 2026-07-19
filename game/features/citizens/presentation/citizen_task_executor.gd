class_name CitizenTaskExecutor
extends RefCounted

const SKILL_GROWTH_PER_SCHOOL_DAY := 0.05
const CitizenEmploymentStateScript = preload("res://game/features/citizens/domain/citizen_employment_state.gd")

func assign_construction(actor: Node3D, site: Node3D) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("construction_site", site)
	actor.set("factory", null)
	actor.set("construction_position", actor.call("_reachable_construction_approach", site))
	var path: Variant = actor.get("movement_path")
	if path is Array:
		(path as Array).clear()
	actor.set("active_role", "construction")
	actor.set("state", Citizen.State.CONSTRUCTING)

func assign_demolition(actor: Node3D, building: Node3D) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("construction_site", building)
	actor.set("factory", null)
	actor.set("construction_position", actor.call("_reachable_construction_approach", building))
	var path: Variant = actor.get("movement_path")
	if path is Array:
		(path as Array).clear()
	actor.set("active_role", "demolition")
	actor.set("state", Citizen.State.CONSTRUCTING)

func finish_construction(actor: Node3D, site: Node3D) -> void:
	if actor == null or actor.get("construction_site") != site:
		return
	actor.set("construction_site", null)
	actor.set("active_role", "")
	actor.set("is_waiting_for_materials", false)
	var path: Variant = actor.get("movement_path")
	if path is Array:
		(path as Array).clear()
	actor.set("path_destination", Vector3.INF)
	actor.set("state", Citizen.State.IDLE)
	actor.call("begin_role_recheck_cooldown")

func assign_excavation(actor: Node3D, site: Node3D) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("assigned_dig_site", site)
	actor.set("factory", null)
	actor.set("active_role", "excavation")
	actor.set("state", Citizen.State.EXCAVATING)

func deliver_excavation(actor: Node3D, next_resource_type: String, warehouse: Vector3) -> void:
	if actor == null:
		return
	actor.set("resource_type", next_resource_type)
	actor.set("warehouse_position", warehouse)
	actor.set("carried_amount", 1)
	actor.set("returning_to_excavation", true)
	actor.set("state", Citizen.State.TO_WAREHOUSE)

func storage_delivery_result(actor: Node3D, accepted: bool, reason := StringName()) -> void:
	if actor == null:
		return
	var status_script: Script = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
	var storage_no_wh: StringName = status_script.STORAGE_NO_WAREHOUSE if status_script != null else &"storage_no_warehouse"
	if accepted:
		actor.set("carried_amount", 0)
		actor.set("blocked_by_storage", false)
		actor.call("clear_status_effect", storage_no_wh)
		if bool(actor.call("is_courier")):
			actor.set("state", Citizen.State.IDLE)
			return
		var returning_exc: bool = bool(actor.get("returning_to_excavation"))
		var act_role: String = str(actor.get("active_role"))
		if returning_exc:
			actor.set("state", Citizen.State.EXCAVATING)
		elif act_role == "forestry":
			actor.call("idle")
		elif act_role.begins_with("gather_"):
			actor.set("state", Citizen.State.IDLE)
			actor.call("begin_role_recheck_cooldown")
		else:
			actor.set("state", Citizen.State.TO_TREE)
		actor.set("returning_to_excavation", false)
	else:
		actor.set("carried_amount", 0)
		actor.set("blocked_by_storage", true)
		if reason == storage_no_wh:
			actor.call("set_status_effect", storage_no_wh, "No warehouse", 1.0)
		actor.call("go_home")

func register_pending_resource(actor: Node3D, next_resource_type: String, amount: int) -> void:
	if actor == null:
		return
	var pending: Dictionary = actor.get("pending_resources")
	pending[next_resource_type] = int(pending.get(next_resource_type, 0)) + amount
	actor.set("pending_resources", pending)

func has_pending_resource(actor: Node3D) -> bool:
	if actor == null:
		return false
	var pending: Dictionary = actor.get("pending_resources")
	for amount in pending.values():
		if int(amount) > 0:
			return true
	return false

func take_pending_resource(actor: Node3D, max_amount := 0) -> Dictionary:
	if actor == null:
		return {}
	var pending: Dictionary = actor.get("pending_resources")
	for pending_type in pending.keys():
		var amount: int = int(pending[pending_type])
		if amount > 0:
			var taken := amount if max_amount <= 0 else mini(amount, max_amount)
			pending[pending_type] = amount - taken
			actor.set("pending_resources", pending)
			if int(actor.get("state")) == Citizen.State.WAITING_COURIER and int(pending[pending_type]) == 0:
				actor.set("state", Citizen.State.IDLE)
				actor.set("active_role", "")
				if str(actor.get("permanent_role")) == "excavation":
					actor.set("assigned_dig_site", null)
			return {"type": pending_type, "amount": taken}
	return {}

func assign_courier_pickup(actor: Node3D, worker: Node3D, warehouse: Vector3) -> void:
	if actor == null:
		return
	actor.call("_reset_assignment_navigation")
	actor.set("courier_target", worker)
	actor.set("warehouse_position", warehouse)
	actor.set("active_role", "")
	actor.set("factory", null)
	actor.set("state", Citizen.State.COURIER_TO_WORKER)

func assign_sawmill_pickup(actor: Node3D, sawmill: Vector3, warehouse: Vector3) -> void:
	if actor == null:
		return
	actor.call("_reset_assignment_navigation")
	actor.set("workplace_position", sawmill)
	actor.set("warehouse_position", warehouse)
	actor.set("active_role", "")
	actor.set("factory", null)
	actor.set("state", Citizen.State.COURIER_TO_SAWMILL)

func collect_sawmill_boards(actor: Node3D, amount: int) -> void:
	if actor == null:
		return
	var cap: int = int(actor.call("courier_capacity")) if actor.has_method("courier_capacity") else 1
	actor.set("carried_amount", mini(amount, cap))
	actor.set("courier_resource_type", "boards")
	actor.set("state", Citizen.State.COURIER_TO_WAREHOUSE if amount > 0 else Citizen.State.IDLE)

func assign_dew_collector_pickup(actor: Node3D, collector: Vector3, warehouse: Vector3) -> void:
	if actor == null:
		return
	actor.call("_reset_assignment_navigation")
	actor.set("workplace_position", collector)
	actor.set("warehouse_position", warehouse)
	actor.set("active_role", "")
	actor.set("factory", null)
	actor.set("state", Citizen.State.COURIER_TO_DEW)

func collect_dew(actor: Node3D, amount: int) -> void:
	if actor == null:
		return
	var carried := maxi(amount, 0)
	actor.set("carried_amount", carried)
	actor.set("courier_resource_type", "water")
	actor.set("state", Citizen.State.COURIER_TO_WAREHOUSE if carried > 0 else Citizen.State.IDLE)

func deliver_sawmill_boards(actor: Node3D, amount: int) -> void:
	if actor == null:
		return
	actor.set("resource_type", "boards")
	actor.set("carried_amount", amount)
	actor.set("state", Citizen.State.TO_WAREHOUSE)

func assign_next_forestry_tree(actor: Node3D, tree_position: Vector3) -> void:
	if actor == null:
		return
	if bool(actor.call("_start_pending_arrival_if_any")):
		return
	actor.set("source_position", tree_position)
	actor.set("state", Citizen.State.TO_TREE)

func assign_canteen_work(actor: Node3D, next_canteen_position: Vector3) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("canteen_position", next_canteen_position)
	actor.set("active_role", "cooking")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_CANTEEN_WORK)

func assign_teacher_work(actor: Node3D, next_school_position: Vector3) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("school_position", next_school_position)
	actor.set("active_role", "teaching")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_SCHOOL_WORK)

func assign_seller_work(actor: Node3D, next_market_position: Vector3) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("market_position", next_market_position)
	actor.set("active_role", "selling")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_MARKET_WORK)

func assign_official_work(actor: Node3D, next_office_position: Vector3) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("official_position", next_office_position)
	actor.set("active_role", "registration")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_OFFICIAL_WORK)

func assign_craft_work(actor: Node3D, next_craft_position: Vector3, next_speed_multiplier := 1.0) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("craft_position", next_craft_position)
	actor.set("craft_speed_multiplier", next_speed_multiplier)
	actor.set("active_role", "crafting")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_CRAFT_WORK)

func assign_research_work(actor: Node3D, next_research_position: Vector3) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("research_position", next_research_position)
	actor.set("active_role", "research")
	actor.set("factory", null)
	actor.set("state", Citizen.State.RESEARCHING)

func process_research(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var res_pos: Vector3 = actor.get("research_position")
	if bool(actor.call("_move_to", res_pos, delta, false, false)):
		actor.call("enter_work_position", res_pos, "researcher", null, true, false)

func process_craft_work_arrival(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var craft_pos: Vector3 = actor.get("craft_position")
	if bool(actor.call("_move_to", craft_pos, delta, false, false)):
		var eff: float = float(actor.call("get_efficiency", "craftsman"))
		var mult: float = float(actor.get("craft_speed_multiplier"))
		actor.set("craft_timer", 10.0 / (eff * mult))
		actor.set("state", Citizen.State.CRAFT_WORK)
		actor.call("enter_work_position", craft_pos, "craftsman", null, true, false)

func process_craft_work(actor: Node3D, delta: float) -> void:
	if actor == null:
		return
	var craft_timer: float = float(actor.get("craft_timer")) - delta
	actor.set("craft_timer", craft_timer)
	if craft_timer <= 0.0:
		if actor.has_signal("resource_ready"):
			actor.emit_signal("resource_ready", actor, "goods", 1)
		var eff: float = float(actor.call("get_efficiency", "craftsman"))
		var mult: float = float(actor.get("craft_speed_multiplier"))
		actor.set("craft_timer", 10.0 / (eff * mult))

func assign_factory_work(actor: Node3D, next_factory: Node3D, role: String) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("factory", next_factory)
	var pos: Vector3 = next_factory.get_meta("service_position", next_factory.global_position if next_factory.is_inside_tree() else next_factory.position)
	actor.set("factory_position", pos)
	actor.set("active_role", role)
	actor.set("state", Citizen.State.TO_FACTORY)

func go_to_park(actor: Node3D, next_park_position: Vector3, minimum_hours := 0, duration_override := -1.0) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("park_position", next_park_position)
	var dur := maxf(duration_override, 0.1) if duration_override > 0.0 else maxf(4.0, float(minimum_hours) * 12.5) if minimum_hours > 0 else 4.0
	actor.set("park_rest_duration", dur)
	actor.set("active_role", "relaxing")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_PARK)

func deliver_trade(actor: Node3D, source: Vector3, destination: Vector3) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("trade_source_position", source)
	actor.set("trade_destination_position", destination)
	actor.set("active_role", "trade")
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_TRADE_PICKUP)

func start_training(actor: Node3D, next_role: String, next_school_position: Vector3) -> void:
	if actor == null:
		return
	actor.set("training_role", next_role)
	actor.set("training_days_completed", 0)
	actor.set("school_position", next_school_position)

func attend_school(actor: Node3D, school_pos: Vector3, role_to_train: String) -> void:
	if actor == null or bool(actor.get("is_player_controlled")):
		return
	actor.call("_reset_assignment_navigation")
	actor.set("school_position", school_pos)
	actor.set("temp_training_role", role_to_train)
	actor.set("factory", null)
	actor.set("state", Citizen.State.TO_SCHOOL)

func finish_school_day(actor: Node3D, teacher_present := true) -> void:
	if actor == null or int(actor.get("state")) != Citizen.State.STUDYING:
		return
	var trained_role: String = str(actor.get("training_role"))
	if trained_role.is_empty():
		trained_role = str(actor.get("temp_training_role"))
	if not trained_role.is_empty() and teacher_present:
		var skills: Dictionary = actor.get("skills")
		var practiced_today: Dictionary = actor.get("practiced_today")
		var current_val := float(skills.get(trained_role, 0.0))
		var is_jack: bool = bool(actor.get("is_jack_of_all_trades"))
		var learning_multiplier := 1.20 if is_jack and trained_role in ["construction", "forestry", "farming", "excavation", "factory_worker", "craftsman"] else 1.0
		skills[trained_role] = minf(1.0, current_val + SKILL_GROWTH_PER_SCHOOL_DAY * learning_multiplier)
		practiced_today[trained_role] = true
		actor.set("skills", skills)
		actor.set("practiced_today", practiced_today)
		if not str(actor.get("training_role")).is_empty():
			var completed: int = int(actor.get("training_days_completed")) + 1
			actor.set("training_days_completed", completed)
			if completed >= 10:
				actor.set("specialization", "builder" if trained_role == "construction" else trained_role)
				actor.call("clear_daily_order")
				actor.set("permanent_role", "")
				actor.set("pending_employment_role", "")
				actor.set("employment_state", CitizenEmploymentStateScript.EmploymentState.NO_PERMANENT_WORK)
				actor.call("setup_specialization", actor.get("specialization"))
				actor.set("training_role", "")
				actor.set("training_days_completed", 0)
	actor.set("temp_training_role", "")
	actor.set("state", Citizen.State.IDLE)
