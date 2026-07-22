class_name PlayerController
extends Node

const PlayerInteractionTargetResolverScript = preload("res://game/features/citizens/presentation/player_interaction_target_resolver.gd")
const S = preload("res://game/features/ui/domain/game_strings.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

const PLAYER_SPEED := 6.5
const PLAYER_SPRINT_MULTIPLIER := 1.7
const PLAYER_JUMP_VELOCITY := 4.8
const PLAYER_GRAVITY := 14.0
const PLAYER_EYE_HEIGHT := 1.48
const INTERACTION_RANGE := 4.5
const HARVEST_DURATION := 2.0
const HERO_GATHER_YIELD := 3

var simulation: Node
var _target_resolver: PlayerInteractionTargetResolverScript

var is_first_person := false
var player_citizen: Citizen
var player_yaw := 0.0
var player_pitch := 0.0

var interaction_action := ""
var interaction_resource := ""
var interaction_time := 0.0
var interaction_start_cell := Vector2i(-9999, -9999)
var interaction_repeat_all := false
var player_work_target: Node3D
var player_toilet_notified := false


func setup(p_simulation: Node) -> void:
	simulation = p_simulation
	_target_resolver = PlayerInteractionTargetResolverScript.new()


func toggle_hero_view() -> void:
	if is_first_person:
		if player_citizen == simulation.hero_citizen:
			leave_first_person_to_hero_overview()
		else:
			enter_first_person(simulation.hero_citizen, "Returned to the hero.")
		return
	enter_first_person(simulation.hero_citizen, "Hero view enabled.")


func take_control_of_selected_citizen() -> void:
	if simulation.selected_builder == null:
		return
	enter_first_person(simulation.selected_builder, "%s is now under direct control." % simulation.selected_builder.role_label())


func enter_first_person(citizen: Citizen, message: String) -> void:
	if citizen == null:
		return
	simulation._close_context_menus()
	if is_first_person and player_citizen != null and player_citizen != citizen:
		player_citizen.set_player_controlled(false)
		player_citizen.set_head_visible(true)
		if simulation.citizen_ai != null:
			simulation.citizen_ai.request_decision_refresh()
	player_citizen = citizen
	player_toilet_notified = false
	player_citizen.set_head_visible(false)
	player_citizen.set_player_controlled(false)
	is_first_person = true
	simulation.build_mode = ""
	simulation.selection_marker.visible = false
	simulation._show_territory_overlay(false)
	simulation.build_menu.visible = false
	simulation.build_menu_is_global = false
	simulation.build_menu_is_job_menu = false
	simulation.build_menu_is_daily_order_menu = false
	simulation._close_pocket_take_menu()
	if simulation.time_controls_panel != null:
		simulation.time_controls_panel.set_speed_controls_visible(false)
		simulation.time_controls_panel.hide_skip_buttons()
	if simulation.build_toggle_btn != null:
		simulation.build_toggle_btn.visible = false
	interaction_action = ""
	interaction_resource = ""
	interaction_start_cell = Vector2i(-9999, -9999)
	interaction_repeat_all = false
	player_yaw = player_citizen.rotation.y
	player_pitch = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if simulation.crosshair != null:
		simulation.crosshair.visible = true
	Engine.time_scale = 1.0
	simulation._update_interface(message)


func leave_first_person_to_hero_overview() -> void:
	is_first_person = false
	if player_citizen != null:
		player_citizen.set_player_controlled(false)
		player_citizen.set_head_visible(true)
		if simulation.citizen_ai != null:
			simulation.citizen_ai.request_decision_refresh()
	player_citizen = null
	player_toilet_notified = false
	simulation._close_pocket_take_menu()
	interaction_action = ""
	interaction_resource = ""
	interaction_start_cell = Vector2i(-9999, -9999)
	interaction_repeat_all = false
	if simulation.interaction_hint_panel != null:
		simulation.interaction_hint_panel.visible = false
	if simulation.time_controls_panel != null:
		simulation.time_controls_panel.set_speed_controls_visible(true)
	if simulation.build_toggle_btn != null:
		simulation.build_toggle_btn.visible = true
	simulation._update_skip_night_button()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if simulation.crosshair != null:
		simulation.crosshair.visible = false
	if simulation.hero_citizen != null:
		simulation.camera_target = simulation.hero_citizen.global_position
	simulation._update_camera_position()
	simulation.build_menu.visible = simulation.selected_builder != null
	simulation._update_workers()
	Engine.time_scale = simulation.time_multiplier
	simulation._update_interface("Overview centered on the hero.")


func update_player_control(delta: float) -> void:
	if player_citizen == null:
		leave_first_person_to_hero_overview()
		return
	if player_citizen.work_position_locked:
		simulation.camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
		simulation.camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
		simulation._refresh_interaction_hint()
		return
	if player_citizen.player_using_toilet:
		simulation.camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
		simulation.camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
		simulation._refresh_interaction_hint()
		return
	var move_direction := Vector3.ZERO
	var forward := Vector3(-sin(player_yaw), 0.0, -cos(player_yaw))
	var right := Vector3(cos(player_yaw), 0.0, -sin(player_yaw))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_direction += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_direction -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_direction += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_direction -= right
	if not player_citizen.is_player_controlled:
		if move_direction.is_zero_approx():
			simulation.camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
			simulation.camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
			simulation._refresh_interaction_hint()
			return
		if simulation.citizen_ai != null:
			simulation.citizen_ai.cancel_citizen_work(player_citizen.ai_id)
		player_citizen.set_player_controlled(true)
	var speed := PLAYER_SPEED * (PLAYER_SPRINT_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized()
		player_citizen.velocity.x = move_direction.x * speed
		player_citizen.velocity.z = move_direction.z * speed
		player_citizen.rotation.y = player_yaw
	else:
		player_citizen.velocity.x = move_toward(player_citizen.velocity.x, 0.0, speed * 8.0 * delta)
		player_citizen.velocity.z = move_toward(player_citizen.velocity.z, 0.0, speed * 8.0 * delta)
	if player_citizen.is_on_floor():
		player_citizen.velocity.y = -0.5
		if Input.is_key_pressed(KEY_SPACE):
			player_citizen.velocity.y = PLAYER_JUMP_VELOCITY
	else:
		player_citizen.velocity.y -= PLAYER_GRAVITY * delta
	player_citizen.move_and_slide()
	player_citizen.drive_player_animation(Input.is_key_pressed(KEY_SHIFT))
	simulation.camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
	simulation.camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
	simulation._refresh_interaction_hint()


func update_interaction(delta: float) -> void:
	if interaction_action.is_empty():
		return
	if simulation.interaction_hint_panel != null:
		simulation.interaction_hint_panel.visible = true
	if interaction_action in ["construction", "demolition"]:
		if not is_instance_valid(player_work_target) or player_citizen.global_position.distance_to(player_work_target.global_position) > INTERACTION_RANGE:
			interaction_action = ""
			player_work_target = null
			simulation.interaction_progress.visible = false
			simulation._refresh_interaction_hint()
			return
		simulation.interaction_progress.value = 100.0
		simulation.interaction_hint_label.text = S.WORKING_FORMAT % interaction_action
		return
	if interaction_action == "toilet":
		if player_citizen == null or not player_citizen.player_using_toilet:
			interaction_action = ""
			simulation.interaction_progress.visible = false
			simulation._refresh_interaction_hint()
			return
		var toilet_pct := int((1.0 - player_citizen.toilet_timer.remaining / Citizen.TOILET_USE_DURATION) * 100.0)
		simulation.interaction_progress.value = clampi(toilet_pct, 0, 100)
		simulation.interaction_hint_label.text = S.USING_TOILET_PERCENT % clampi(toilet_pct, 0, 100)
		return
	if simulation._cell_from_position(player_citizen.global_position) != interaction_start_cell:
		interaction_action = ""
		simulation.interaction_progress.visible = false
		simulation._update_interface(S.ACTION_CANCELLED_AWAY)
		simulation._refresh_interaction_hint()
		return
	if (interaction_resource in [ResourceIds.WOOD, ResourceIds.BRANCHES] and not simulation._nearby_tree()) or (interaction_resource == ResourceIds.FOOD and not simulation._nearby_farm()) or (interaction_resource == ResourceIds.WATER and not simulation._nearby_pond()) or (interaction_resource == ResourceIds.GRASS and not simulation._nearby_grass_source()):
		interaction_action = ""
		simulation.interaction_progress.visible = false
		simulation._update_interface(S.HARVEST_CANCELLED_AWAY_SOURCE)
		return
	interaction_time += delta
	var progress_pct := clampi(int(interaction_time / HARVEST_DURATION * 100.0), 0, 100)
	simulation.interaction_progress.value = progress_pct
	var source_info: String = simulation._harvest_source_info(interaction_resource)
	simulation.interaction_hint_label.text = "%s %d%% (%s)" % [simulation._gather_action_name(interaction_resource), progress_pct, source_info]
	if interaction_time >= HARVEST_DURATION:
		interaction_action = ""
		var gathered := 0
		match interaction_resource:
			ResourceIds.WOOD:
				gathered = simulation._add_to_pocket(ResourceIds.WOOD, 1)
				if gathered > 0:
					simulation._fell_nearest_tree()
			ResourceIds.BRANCHES:
				var branch_batch := HERO_GATHER_YIELD
				gathered = simulation._add_to_pocket(ResourceIds.BRANCHES, branch_batch)
				if gathered > 0:
					simulation._consume_tree_near_player(gathered)
			ResourceIds.GRASS:
				var grass_batch := HERO_GATHER_YIELD
				gathered = simulation._add_to_pocket(ResourceIds.GRASS, grass_batch)
				if gathered > 0:
					simulation._consume_grass_near_player(gathered)
			ResourceIds.WATER:
				gathered = simulation._add_to_pocket(ResourceIds.WATER, 1)
			ResourceIds.FOOD:
				gathered = simulation._add_to_pocket(ResourceIds.FOOD, 1)
		if gathered > 0:
			simulation._update_interface(S.GATHERED_FORMAT % [interaction_resource, simulation._format_pocket_hint()])
		else:
			simulation._update_interface(S.POCKET_FULL_CANNOT_GATHER % interaction_resource)
		simulation.interaction_progress.visible = false


func start_interaction(all: bool) -> void:
	if not is_first_person or player_citizen == null:
		return
	if simulation.pocket_menu_open:
		simulation._close_pocket_take_menu()
		return
	if player_citizen.work_position_locked:
		simulation._exit_player_work_position()
		return
	if not interaction_action.is_empty():
		return
	var target := first_person_target()
	if target.kind == "entrance":
		simulation._meet_arrival_at_entrance()
		return
	if target.kind == "building" and simulation._is_managed_fire_source(target.node):
		simulation._refuel_fire_from_pocket(target.node, all)
		return
	if target.kind == "toilet":
		simulation._player_use_toilet(target.node)
		return
	if not player_citizen.is_hero:
		simulation._update_interface(S.ONLY_HERO_CAN_ACT)
		return
	match target.kind:
		"construction":
			var site: ConstructionSite = simulation.construction.site_for_node(target.node)
			if site != null and not site.is_supplied():
				simulation._deliver_pocket_to_site(site, all)
			else:
				player_work_target = target.node
				interaction_action = "construction"
				interaction_time = 0.0
				interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
				simulation.interaction_progress.visible = true
				simulation.interaction_hint_label.text = S.WORKING_CONSTRUCTION
			return
		"demolition":
			player_work_target = target.node
			interaction_action = "demolition"
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			simulation.interaction_progress.visible = true
			simulation.interaction_hint_label.text = S.WORKING_DEMOLITION
			return
		"pile":
			simulation._take_from_pile(target.pile, all)
			return
		"sawmill":
			simulation._handle_sawmill_interaction(all, target.position)
			return
		"warehouse":
			simulation._handle_warehouse_interaction(all, int(target.get("warehouse_index", -1)))
			return
		"forage", "rabbit":
			simulation._update_interface(S.FORAGE_SPECIALIST_ONLY_SHORT)
			return
		"citizen", "building":
			return
		"tree":
			var gathering_branches: bool = int(simulation.settlement.era) < int(SettlementState.Era.WOOD)
			if not simulation._pocket_has_room():
				simulation._update_interface(S.POCKET_FULL_TREE_HINT)
				return
			interaction_action = "harvesting"
			interaction_resource = ResourceIds.BRANCHES if gathering_branches else ResourceIds.WOOD
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return
		"farm":
			if not simulation._pocket_has_room():
				simulation._update_interface(S.POCKET_FULL_SHORT)
				return
			interaction_action = "harvesting"
			interaction_resource = ResourceIds.FOOD
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return
		"pond":
			if not simulation._pocket_has_room():
				simulation._update_interface(S.POCKET_FULL_SHORT)
				return
			interaction_action = "harvesting"
			interaction_resource = ResourceIds.WATER
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return
		"grass":
			if not simulation._pocket_has_room():
				simulation._update_interface(S.POCKET_FULL_SHORT)
				return
			interaction_action = "harvesting"
			interaction_resource = ResourceIds.GRASS
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return


func first_person_target() -> Dictionary:
	if not is_first_person or player_citizen == null or simulation.camera == null:
		return {"kind": ""}
	return _target_resolver.resolve(simulation.camera, player_citizen, simulation)
