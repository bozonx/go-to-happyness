class_name PlayerController
extends Node

const PLAYER_SPEED := 6.5
const PLAYER_SPRINT_MULTIPLIER := 1.7
const PLAYER_JUMP_VELOCITY := 4.8
const PLAYER_GRAVITY := 14.0
const PLAYER_EYE_HEIGHT := 1.48
const INTERACTION_RANGE := 4.5
const HARVEST_DURATION := 2.0
const HERO_GATHER_YIELD := 3

var simulation: Node

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
		simulation.interaction_hint_label.text = "Работаем: %s..." % interaction_action
		return
	if interaction_action == "toilet":
		if player_citizen == null or not player_citizen.player_using_toilet:
			interaction_action = ""
			simulation.interaction_progress.visible = false
			simulation._refresh_interaction_hint()
			return
		var toilet_pct := int((1.0 - player_citizen.toilet_timer.remaining / Citizen.TOILET_USE_DURATION) * 100.0)
		simulation.interaction_progress.value = clampi(toilet_pct, 0, 100)
		simulation.interaction_hint_label.text = "Пользуемся туалетом %d%%" % clampi(toilet_pct, 0, 100)
		return
	if simulation._cell_from_position(player_citizen.global_position) != interaction_start_cell:
		interaction_action = ""
		simulation.interaction_progress.visible = false
		simulation._update_interface("Действие прервано: вы отошли от клетки.")
		simulation._refresh_interaction_hint()
		return
	if (interaction_resource in ["wood", "branches"] and not simulation._nearby_tree()) or (interaction_resource == "food" and not simulation._nearby_farm()) or (interaction_resource == "water" and not simulation._nearby_pond()) or (interaction_resource == "grass" and not simulation._nearby_grass_source()):
		interaction_action = ""
		simulation.interaction_progress.visible = false
		simulation._update_interface("Добыча отменена: вы отошли от источника.")
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
			"wood":
				gathered = simulation._add_to_pocket("wood", 1)
				if gathered > 0:
					simulation._fell_nearest_tree()
			"branches":
				var branch_batch := HERO_GATHER_YIELD
				gathered = simulation._add_to_pocket("branches", branch_batch)
				if gathered > 0:
					simulation._consume_tree_near_player(gathered)
			"grass":
				var grass_batch := HERO_GATHER_YIELD
				gathered = simulation._add_to_pocket("grass", grass_batch)
				if gathered > 0:
					simulation._consume_grass_near_player(gathered)
			"water":
				gathered = simulation._add_to_pocket("water", 1)
			"food":
				gathered = simulation._add_to_pocket("food", 1)
		if gathered > 0:
			simulation._update_interface("Собрано %s. %s" % [interaction_resource, simulation._format_pocket_hint()])
		else:
			simulation._update_interface("Карман полон. Невозможно собрать %s." % interaction_resource)
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
		simulation._update_interface("Только герой может выполнять действия. Остальными жителями можно только двигаться.")
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
				simulation.interaction_hint_label.text = "Работаем: стройка..."
			return
		"demolition":
			player_work_target = target.node
			interaction_action = "demolition"
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			simulation.interaction_progress.visible = true
			simulation.interaction_hint_label.text = "Работаем: снос..."
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
			simulation._update_interface("Лесные дары и зайца может собирать только специалист. Постройте палатку охотников-собирателей.")
			return
		"citizen", "building":
			return
		"tree":
			var gathering_branches: bool = int(simulation.settlement.era) < int(SettlementState.Era.WOOD)
			if not simulation._pocket_has_room():
				simulation._update_interface("Карман полон. Дерево — на лесопилку, еду — на склад.")
				return
			interaction_action = "harvesting"
			interaction_resource = "branches" if gathering_branches else "wood"
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return
		"farm":
			if not simulation._pocket_has_room():
				simulation._update_interface("Карман полон.")
				return
			interaction_action = "harvesting"
			interaction_resource = "food"
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return
		"pond":
			if not simulation._pocket_has_room():
				simulation._update_interface("Карман полон.")
				return
			interaction_action = "harvesting"
			interaction_resource = "water"
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return
		"grass":
			if not simulation._pocket_has_room():
				simulation._update_interface("Карман полон.")
				return
			interaction_action = "harvesting"
			interaction_resource = "grass"
			interaction_time = 0.0
			interaction_start_cell = simulation._cell_from_position(player_citizen.global_position)
			interaction_repeat_all = all
			return


func first_person_target() -> Dictionary:
	var result := {"kind": ""}
	if not is_first_person or player_citizen == null or simulation.camera == null:
		return result
	var from: Vector3 = simulation.camera.global_position
	var direction: Vector3 = -simulation.camera.global_transform.basis.z
	var to := from + direction * INTERACTION_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 | 4
	var hit: Dictionary = simulation.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_position := Vector3.INF
	if not hit.is_empty():
		hit_position = hit.position
		var collider: Object = hit.get("collider", null)
		if collider is StaticBody3D and collider.name == "TreeCollision":
			var tree := collider.get_parent() as Node3D
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				result = {"kind": "tree", "node": tree, "position": tree.global_position}
		elif collider is Area3D:
			var area_parent := collider.get_parent() as Node3D
			if collider.is_in_group("construction_selector") and is_instance_valid(area_parent):
				result = {"kind": "construction", "node": area_parent, "position": area_parent.global_position}
			elif collider.is_in_group("entrance_selector") and is_instance_valid(area_parent):
				result = {"kind": "entrance", "node": area_parent, "position": area_parent.global_position}
			elif collider.is_in_group("resource_pile_selector"):
				var pile: Dictionary = simulation._resource_pile_for_node(area_parent)
				if not pile.is_empty():
					result = {"kind": "pile", "node": area_parent, "pile": pile, "position": area_parent.global_position}
			elif collider.is_in_group("warehouse_selector"):
				result = {"kind": "warehouse", "node": area_parent, "position": area_parent.global_position, "warehouse_index": simulation._warehouse_index_for_building(area_parent)}
			elif collider.is_in_group("citizen_selector") and area_parent is Citizen:
				result = {"kind": "citizen", "node": area_parent as Citizen, "position": area_parent.global_position}
			elif collider.is_in_group("tree_selector") and is_instance_valid(area_parent):
				if not bool(area_parent.get_meta("felled", false)):
					result = {"kind": "tree", "node": area_parent, "position": area_parent.global_position}
			elif collider.is_in_group("forage_selector") and is_instance_valid(area_parent):
				result = {"kind": "forage", "node": area_parent, "position": area_parent.global_position}
			elif collider.is_in_group("rabbit_selector") and is_instance_valid(area_parent):
				result = {"kind": "rabbit", "node": area_parent, "position": area_parent.global_position}
			elif collider.is_in_group("building_selector") and is_instance_valid(area_parent):
				var building_type := str(area_parent.get_meta("building_type", ""))
				if bool(area_parent.get_meta("pending_demolition", false)):
					result = {"kind": "demolition", "node": area_parent, "position": area_parent.global_position}
				elif building_type == "sawmill":
					result = {"kind": "sawmill", "node": area_parent, "position": area_parent.global_position}
				elif building_type.begins_with("toilet_"):
					result = {"kind": "toilet", "node": area_parent, "position": area_parent.global_position}
				elif simulation._role_for_workplace(area_parent) != "":
					result = {"kind": "workplace", "node": area_parent, "position": area_parent.global_position}
				else:
					result = {"kind": "building", "node": area_parent, "position": area_parent.global_position}
			elif collider.is_in_group("campfire_selector") or collider.is_in_group("cook_campfire_selector") or collider.is_in_group("market_selector") or collider.is_in_group("school_selector") or collider.is_in_group("house_selector") or collider.is_in_group("materials_factory_selector"):
				if is_instance_valid(area_parent):
					result = {"kind": "building", "node": area_parent, "position": area_parent.global_position}
	if result.kind != "":
		return result
	if hit_position == Vector3.INF:
		hit_position = to
	var player_pos: Vector3 = player_citizen.global_position
	if player_pos.distance_to(hit_position) > INTERACTION_RANGE:
		return result
	var grass_pos: Vector3 = simulation._nearest_grass_source_to_point(hit_position, 1.0)
	if grass_pos != Vector3.INF and player_pos.distance_to(grass_pos) <= INTERACTION_RANGE:
		var grass_cell: Vector2i = simulation._cell_from_position(grass_pos)
		if simulation.grass_sources.has(grass_cell):
			return {"kind": "grass", "position": grass_pos}
	var farm_pos: Vector3 = simulation._nearest_point_to_point_array(simulation.farm_positions, hit_position, 5.0)
	if farm_pos != Vector3.INF and player_pos.distance_to(farm_pos) <= INTERACTION_RANGE:
		return {"kind": "farm", "position": farm_pos}
	var pond_pos: Vector3 = simulation._nearest_point_to_point_array(simulation.pond_positions, hit_position, 2.5)
	if pond_pos != Vector3.INF and player_pos.distance_to(pond_pos) <= INTERACTION_RANGE:
		return {"kind": "pond", "position": pond_pos}
	var tree_pos: Vector3 = simulation._nearest_point_to_point_array(simulation.tree_positions, hit_position, 1.5)
	if tree_pos != Vector3.INF and player_pos.distance_to(tree_pos) <= INTERACTION_RANGE:
		var tree_node: Node3D = simulation.tree_nodes.get(simulation._cell_from_position(tree_pos))
		if is_instance_valid(tree_node) and not bool(tree_node.get_meta("felled", false)):
			return {"kind": "tree", "node": tree_node, "position": tree_pos}
	return result
