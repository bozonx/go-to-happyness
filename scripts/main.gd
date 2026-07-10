extends Node3D

const BOARD_CELLS := 12
const CELL_SIZE := 2.0
const STARTING_WOOD := 30
const WAREHOUSE_COST := 10
const SAWMILL_COST := 10
const HOUSE_COST := 12
const FARM_COST := 12
const POPULATION := 5
const BED_CAPACITY := 4
const FOOD_CONSUMPTION_INTERVAL := 10.0
const CONSTRUCTION_DURATION := 4.0
const PLAYER_SPEED := 4.2
const PLAYER_EYE_HEIGHT := 1.18
const HARVEST_DURATION := 1.25
const INTERACTION_RANGE := 2.15
const POCKET_WOOD_CAPACITY := 8

var wood := STARTING_WOOD
var food := 20
var soil := 0
var clay := 0
var wellbeing := 75
var consumption_time := FOOD_CONSUMPTION_INTERVAL
var selected_cell := Vector2i(0, 0)
var build_mode := ""
var placed_buildings: Dictionary = {}
var tree_cells: Dictionary = {}
var warehouse_positions: Array[Vector3] = []
var sawmill_positions: Array[Vector3] = []
var farm_positions: Array[Vector3] = []
var tree_positions: Array[Vector3] = []
var citizens: Array[Citizen] = []
var camera: Camera3D
var camera_target := Vector3.ZERO
var camera_distance := 30.0
var camera_yaw := 42.0
var camera_pitch := 52.0
var selection_marker: MeshInstance3D
var selection_material: StandardMaterial3D
var wood_label: Label
var status_label: Label
var selected_builder: Citizen
var build_menu: Panel
var build_menu_title: Label
var camera_hint_label: Label
var is_panning_camera := false
var is_rotating_camera := false
var construction_sites: Array[Dictionary] = []
var completed_house_count := 0
var player_citizen: Citizen
var is_first_person := false
var player_yaw := 0.0
var player_pitch := -8.0
var pocket_wood := 0
var interaction_time := 0.0
var interaction_action := ""
var interaction_hint_label: Label
var interaction_progress: ProgressBar
var dig_sites: Array[Dictionary] = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}
var dig_mode := false
var house_menu: Panel
var house_menu_title: Label
var selected_house: Node3D

func _ready() -> void:
	_create_world()
	_create_interface()
	_create_forest()
	_create_citizens()
	_update_interface("Build a warehouse, sawmill, farm and homes to sustain the settlement.")

func _process(delta: float) -> void:
	if is_first_person:
		_update_player_control(delta)
		_update_interaction(delta)
	else:
		_update_camera(delta)
	_update_construction(delta)
	_update_couriers()
	consumption_time -= delta
	if consumption_time <= 0.0:
		consumption_time = FOOD_CONSUMPTION_INTERVAL
		_apply_daily_needs()
	if selected_builder != null and build_menu.visible:
		_show_selected_citizen_menu()

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("78a9c5")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("d7ebef")
	world_environment.ambient_light_energy = 0.65
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world_environment
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	add_child(camera)
	_update_camera_position()
	_create_ground()
	_create_grid()
	_create_selection_marker()

func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(BOARD_CELLS * CELL_SIZE, 0.25, BOARD_CELLS * CELL_SIZE)
	ground.mesh = ground_mesh
	ground.position.y = -0.125
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5f8953")
	material.roughness = 0.95
	ground.material_override = material
	add_child(ground)

	var ground_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BOARD_CELLS * CELL_SIZE, 0.25, BOARD_CELLS * CELL_SIZE)
	collision.shape = shape
	collision.position.y = -0.125
	ground_body.add_child(collision)
	add_child(ground_body)

func _create_grid() -> void:
	var grid := ImmediateMesh.new()
	var half_size := BOARD_CELLS * CELL_SIZE * 0.5
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color(0.16, 0.27, 0.16, 0.5)
	grid.surface_begin(Mesh.PRIMITIVE_LINES, grid_material)
	for line in range(BOARD_CELLS + 1):
		var coordinate := -half_size + line * CELL_SIZE
		grid.surface_add_vertex(Vector3(coordinate, 0.02, -half_size))
		grid.surface_add_vertex(Vector3(coordinate, 0.02, half_size))
		grid.surface_add_vertex(Vector3(-half_size, 0.02, coordinate))
		grid.surface_add_vertex(Vector3(half_size, 0.02, coordinate))
	grid.surface_end()
	var grid_instance := MeshInstance3D.new()
	grid_instance.mesh = grid
	add_child(grid_instance)

func _create_selection_marker() -> void:
	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(CELL_SIZE - 0.08, 0.04, CELL_SIZE - 0.08)
	selection_marker.mesh = marker_mesh
	selection_material = StandardMaterial3D.new()
	selection_material.albedo_color = Color(0.95, 0.79, 0.24, 0.55)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_marker.material_override = selection_material
	selection_marker.visible = false
	add_child(selection_marker)
	_move_selection(Vector2i(0, 0))

func _create_forest() -> void:
	var cells := [Vector2i(-5, -4), Vector2i(-4, -5), Vector2i(-5, 4), Vector2i(4, -5), Vector2i(5, 4), Vector2i(4, 5)]
	for cell in cells:
		var tree_position := _cell_center(cell)
		tree_cells[cell] = true
		tree_positions.append(tree_position)
		_create_tree(tree_position)

func _create_tree(position_on_board: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = position_on_board
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.17
	trunk_mesh.height = 1.1
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.55
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("684630")
	trunk.material_override = trunk_material
	tree.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.62
	crown_mesh.height = 1.25
	crown.mesh = crown_mesh
	crown.position.y = 1.35
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color("2d633b")
	crown.material_override = crown_material
	tree.add_child(crown)

func _create_citizens() -> void:
	for index in POPULATION:
		_add_citizen(Vector3(-1.1 + (index % 3) * 1.1, 0.0, -0.8 + (index / 3) * 1.1))

func _add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	var citizen := Citizen.new()
	citizen.position = spawn_position
	add_child(citizen)
	citizen.setup_specialization(primary_specialization if not primary_specialization.is_empty() else ["builder", "forestry", "farming"][citizens.size() % 3])
	citizen.resource_delivered.connect(_on_resource_delivered)
	citizen.excavation_cycle.connect(_on_excavation_cycle)
	citizen.resource_ready.connect(_on_resource_ready)
	citizens.append(citizen)

func _create_interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.07, 0.09, 0.88)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(460, 150)
	ui.add_child(panel)
	wood_label = Label.new()
	wood_label.position = Vector2(18, 14)
	wood_label.size = Vector2(424, 42)
	wood_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(wood_label)
	status_label = Label.new()
	status_label.position = Vector2(18, 62)
	status_label.size = Vector2(424, 70)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)
	camera_hint_label = Label.new()
	camera_hint_label.position = Vector2(20, 682)
	camera_hint_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(camera_hint_label)
	interaction_hint_label = Label.new()
	interaction_hint_label.position = Vector2(20, 592)
	interaction_hint_label.size = Vector2(500, 28)
	interaction_hint_label.add_theme_font_size_override("font_size", 18)
	interaction_hint_label.visible = false
	ui.add_child(interaction_hint_label)
	interaction_progress = ProgressBar.new()
	interaction_progress.position = Vector2(20, 625)
	interaction_progress.size = Vector2(310, 22)
	interaction_progress.show_percentage = false
	interaction_progress.visible = false
	ui.add_child(interaction_progress)
	_create_build_menu(ui)
	_create_house_menu(ui)

func _create_build_menu(ui: CanvasLayer) -> void:
	build_menu = Panel.new()
	build_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_menu.offset_left = -324.0
	build_menu.offset_top = -464.0
	build_menu.offset_right = -20.0
	build_menu.offset_bottom = -20.0
	build_menu.visible = false
	ui.add_child(build_menu)
	build_menu_title = Label.new()
	build_menu_title.position = Vector2(16, 14)
	build_menu_title.size = Vector2(272, 74)
	build_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_menu_title.add_theme_font_size_override("font_size", 15)
	build_menu.add_child(build_menu_title)
	_add_role_button("Auto task", "", 96)
	_add_role_button("Assign: construction", "construction", 130)
	_add_role_button("Assign: forestry", "forestry", 164)
	_add_role_button("Assign: farming", "farming", 198)
	_add_role_button("Assign: excavation", "excavation", 232)
	_add_build_button("Warehouse - 10 wood", "warehouse", 290)
	_add_build_button("Sawmill - 10 wood", "sawmill", 326)
	_add_build_button("Farm - 12 wood", "farm", 362)
	_add_build_button("House - 12 wood", "house", 398)

func _create_house_menu(ui: CanvasLayer) -> void:
	house_menu = Panel.new()
	house_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	house_menu.offset_left = -324.0
	house_menu.offset_top = -302.0
	house_menu.offset_right = -20.0
	house_menu.offset_bottom = -20.0
	house_menu.visible = false
	ui.add_child(house_menu)
	house_menu_title = Label.new()
	house_menu_title.position = Vector2(16, 14)
	house_menu_title.size = Vector2(272, 42)
	house_menu_title.add_theme_font_size_override("font_size", 17)
	house_menu.add_child(house_menu_title)
	_add_house_spawn_button("Spawn Builder", "builder", 64)
	_add_house_spawn_button("Spawn Forester", "forestry", 104)
	_add_house_spawn_button("Spawn Farmer", "farming", 144)
	_add_house_spawn_button("Spawn Digger", "excavation", 184)
	_add_house_spawn_button("Spawn Courier", "courier", 224)

func _add_house_spawn_button(title: String, specialization: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 30)
	button.pressed.connect(_spawn_house_citizen.bind(specialization))
	house_menu.add_child(button)

func _spawn_house_citizen(specialization: String) -> void:
	if selected_house == null:
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	if slots <= 0:
		return
	var offset := Vector3(-0.45 + (2 - slots) * 0.9, 0.0, -0.85)
	_add_citizen(selected_house.global_position + offset, specialization)
	selected_house.set_meta("spawn_slots", slots - 1)
	_update_workers()
	_show_house_menu()
	_update_interface("New %s joined the settlement and received an automatic task." % specialization)

func _show_house_menu() -> void:
	if selected_house == null:
		return
	var slots: int = selected_house.get_meta("spawn_slots", 0)
	house_menu.visible = slots > 0
	if slots <= 0:
		return
	house_menu_title.text = "House recruitment\nChoose resident (%d/2 slots)" % slots

func _add_build_button(title: String, building_type: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 30)
	button.pressed.connect(_select_build_mode.bind(building_type))
	build_menu.add_child(button)

func _add_role_button(title: String, role: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 28)
	button.pressed.connect(_set_manual_role.bind(role))
	build_menu.add_child(button)

func _set_manual_role(role: String) -> void:
	if selected_builder == null:
		return
	if role == "excavation":
		_start_dig_assignment()
		return
	selected_builder.manual_role = role
	selected_builder.assigned_dig_site = null
	_update_workers()
	_show_selected_citizen_menu()
	_update_interface("Citizen assigned to %s." % ("automatic work" if role.is_empty() else role))

func _start_dig_assignment() -> void:
	if selected_builder == null:
		return
	dig_mode = true
	build_mode = ""
	selection_marker.visible = true
	selection_material.albedo_color = Color(0.65, 0.42, 0.2, 0.55)
	_move_selection(selected_cell)
	_update_interface("Choose a clear cell for excavation.")

func _place_dig_site(cell: Vector2i) -> void:
	if not _can_excavate(cell):
		_update_interface("Excavation is not allowed on this cell.")
		return
	var site := _dig_site_at(cell)
	if site.is_empty():
		site = _create_dig_site(cell)
	selected_builder.assigned_dig_site = site.node
	selected_builder.manual_role = "excavation"
	dig_mode = false
	selection_marker.visible = false
	_update_workers()
	_show_selected_citizen_menu()
	_update_interface("Excavation assigned. Soil and clay will be exposed before stone.")

func _can_excavate(cell: Vector2i) -> bool:
	return not placed_buildings.has(cell) and not tree_cells.has(cell) and not exhausted_dig_cells.has(cell)

func _dig_site_at(cell: Vector2i) -> Dictionary:
	for site in dig_sites:
		if site.cell == cell:
			return site
	return {}

func _create_dig_site(cell: Vector2i) -> Dictionary:
	var site_node := Node3D.new()
	site_node.position = _cell_center(cell)
	add_child(site_node)
	var pit := MeshInstance3D.new()
	var pit_mesh := CylinderMesh.new()
	pit_mesh.top_radius = 0.62
	pit_mesh.bottom_radius = 0.72
	pit_mesh.height = 0.12
	pit.mesh = pit_mesh
	pit.position.y = 0.03
	var pit_material := StandardMaterial3D.new()
	pit_material.albedo_color = Color("78533b")
	pit.material_override = pit_material
	site_node.add_child(pit)
	var site := {"cell": cell, "node": site_node, "pit": pit, "soil_limit": randi_range(3, 6), "clay_limit": randi_range(7, 12), "depth": 0}
	dig_sites.append(site)
	dig_cells[cell] = true
	return site

func _select_build_mode(next_mode: String) -> void:
	if selected_builder == null:
		return
	build_mode = next_mode
	selection_marker.visible = true
	_move_selection(selected_cell)
	_update_interface("%s selected. Choose a valid cell." % build_mode.capitalize())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		_toggle_first_person()
		get_viewport().set_input_as_handled()
		return
	if is_first_person:
		if event is InputEventMouseMotion:
			player_yaw -= event.relative.x * 0.0035
			player_pitch = clampf(player_pitch - event.relative.y * 0.003, -70.0, 65.0)
		elif event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
			_start_interaction()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		camera_distance = maxf(7.0, camera_distance - 2.0)
		_update_camera_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		camera_distance = minf(46.0, camera_distance + 2.0)
		_update_camera_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning_camera = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rotating_camera = event.pressed
	elif event is InputEventMouseMotion:
		if is_rotating_camera:
			_rotate_camera(event.relative)
		elif is_panning_camera:
			_pan_camera(event.relative)
		elif selected_builder != null and (not build_mode.is_empty() or dig_mode):
			var cell: Variant = _cell_at_screen_position(event.position)
			if cell != null:
				_move_selection(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_builder != null and dig_mode:
			var dig_cell: Variant = _cell_at_screen_position(event.position)
			if dig_cell != null:
				_place_dig_site(dig_cell)
		elif selected_builder != null and not build_mode.is_empty():
			var cell: Variant = _cell_at_screen_position(event.position)
			if cell != null:
				_place_building(cell)
		else:
			_select_citizen_at(event.position)

func _select_citizen_at(screen_position: Vector2) -> void:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if hit.collider.is_in_group("house_selector"):
		selected_house = hit.collider.get_parent() as Node3D
		selected_builder = null
		build_menu.visible = false
		_show_house_menu()
		_update_interface("House selected. Choose two residents to recruit.")
		return
	if not hit.collider.is_in_group("citizen_selector"):
		return
	selected_builder = hit.collider.get_parent() as Citizen
	selected_house = null
	house_menu.visible = false
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = true
	_show_selected_citizen_menu()
	_update_interface("Citizen selected. Choose a building in the lower-right menu.")

func _show_selected_citizen_menu() -> void:
	if selected_builder == null:
		return
	var assignment := "Auto" if selected_builder.manual_role.is_empty() else selected_builder.manual_role.capitalize()
	build_menu_title.text = "%s  Sat: %d%%  Task: %s\nBuild %.1f  Wood %.1f\nFarm %.1f  Dig %.1f" % [selected_builder.role_label(), roundi(selected_builder.satisfaction), assignment, float(selected_builder.skills.construction), float(selected_builder.skills.forestry), float(selected_builder.skills.farming), float(selected_builder.skills.excavation)]
	build_menu_title.add_theme_color_override("font_color", selected_builder.specialization_color())

func _toggle_first_person() -> void:
	if is_first_person:
		is_first_person = false
		if player_citizen != null:
			player_citizen.set_player_controlled(false)
			camera_target = player_citizen.global_position
		player_citizen = null
		interaction_action = ""
		interaction_hint_label.visible = false
		interaction_progress.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		build_menu.visible = selected_builder != null
		_update_workers()
		_update_interface("Left first-person control. Citizen remains selected.")
		return
	if selected_builder == null:
		_update_interface("Select a citizen first, then press R to take control.")
		return
	player_citizen = selected_builder
	player_citizen.set_player_controlled(true)
	is_first_person = true
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = false
	player_yaw = player_citizen.rotation.y
	player_pitch = -8.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_interface("First-person control enabled. Gather wood and bring it to a warehouse.")

func _update_player_control(delta: float) -> void:
	if player_citizen == null:
		_toggle_first_person()
		return
	var move_direction := Vector3.ZERO
	var forward := Vector3(-sin(player_yaw), 0.0, -cos(player_yaw))
	var right := Vector3(cos(player_yaw), 0.0, -sin(player_yaw))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_direction += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_direction -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_direction += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_direction -= right
	if not move_direction.is_zero_approx():
		player_citizen.global_position += move_direction.normalized() * PLAYER_SPEED * delta
		player_citizen.global_position.x = clampf(player_citizen.global_position.x, -11.3, 11.3)
		player_citizen.global_position.z = clampf(player_citizen.global_position.z, -11.3, 11.3)
		player_citizen.rotation.y = player_yaw
	camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
	camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
	_refresh_interaction_hint()

func _start_interaction() -> void:
	if not interaction_action.is_empty():
		return
	if _nearby_warehouse() and pocket_wood > 0:
		wood += pocket_wood
		var delivered := pocket_wood
		pocket_wood = 0
		_update_interface("Delivered %d wood to the warehouse." % delivered)
		_refresh_interaction_hint()
		return
	if _nearby_tree():
		if pocket_wood >= POCKET_WOOD_CAPACITY:
			_update_interface("Pocket is full. Take the wood to a warehouse.")
			_refresh_interaction_hint()
			return
		interaction_action = "harvesting"
		interaction_time = 0.0
		interaction_progress.visible = true
		interaction_hint_label.text = "Gathering wood..."
		return
	if _nearby_warehouse():
		_update_interface("Your pocket is empty.")
	else:
		_update_interface("Move closer to a tree to gather wood or a warehouse to unload it.")

func _update_interaction(delta: float) -> void:
	if interaction_action.is_empty():
		return
	if not _nearby_tree():
		interaction_action = ""
		interaction_progress.visible = false
		_update_interface("Gathering cancelled: you moved away from the tree.")
		return
	interaction_time += delta
	interaction_progress.value = interaction_time / HARVEST_DURATION * 100.0
	interaction_hint_label.text = "Gathering wood: %d%%" % roundi(interaction_progress.value)
	if interaction_time >= HARVEST_DURATION:
		interaction_action = ""
		pocket_wood += 1
		interaction_progress.visible = false
		_update_interface("Wood gathered. %d/%d in pocket." % [pocket_wood, POCKET_WOOD_CAPACITY])
		_refresh_interaction_hint()

func _nearby_tree() -> bool:
	if player_citizen == null:
		return false
	for tree_position in tree_positions:
		if player_citizen.global_position.distance_to(tree_position) <= INTERACTION_RANGE:
			return true
	return false

func _nearby_warehouse() -> bool:
	if player_citizen == null:
		return false
	for warehouse_position in warehouse_positions:
		if player_citizen.global_position.distance_to(warehouse_position) <= INTERACTION_RANGE:
			return true
	return false

func _refresh_interaction_hint() -> void:
	if not is_first_person or not interaction_action.is_empty():
		return
	interaction_hint_label.visible = true
	if _nearby_warehouse():
		interaction_hint_label.text = "F: unload wood into warehouse (%d in pocket)" % pocket_wood
	elif _nearby_tree():
		interaction_hint_label.text = "F: gather wood (%d/%d in pocket)" % [pocket_wood, POCKET_WOOD_CAPACITY]
	else:
		interaction_hint_label.text = "Find a tree to gather wood or a warehouse to unload it."

func _cell_at_screen_position(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var point: Vector3 = hit.position
	var half_cells := BOARD_CELLS / 2
	var x := floori(point.x / CELL_SIZE)
	var z := floori(point.z / CELL_SIZE)
	if x < -half_cells or x >= half_cells or z < -half_cells or z >= half_cells:
		return null
	return Vector2i(x, z)

func _move_selection(cell: Vector2i) -> void:
	selected_cell = cell
	selection_marker.position = _cell_center(cell) + Vector3(0.0, 0.04, 0.0)
	if selected_builder != null and not build_mode.is_empty():
		selection_material.albedo_color = Color(0.25, 0.85, 0.37, 0.55) if _can_place(cell) else Color(0.9, 0.2, 0.18, 0.6)

func _place_building(cell: Vector2i) -> void:
	if not _can_place(cell):
		_update_interface("Construction is not allowed on this cell.")
		return
	var cost := _building_cost()
	if wood < cost:
		_update_interface("Not enough wood.")
		return
	wood -= cost
	placed_buildings[cell] = build_mode
	var position_on_board := _cell_center(cell)
	_create_construction_site(cell, build_mode, position_on_board)
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = false
	selected_builder = null
	_update_interface("Construction started. The progress bar shows completion.")

func _can_place(cell: Vector2i) -> bool:
	return not placed_buildings.has(cell) and not tree_cells.has(cell) and not dig_cells.has(cell)

func _create_construction_site(cell: Vector2i, building_type: String, position_on_board: Vector3) -> void:
	var site := Node3D.new()
	site.position = position_on_board
	add_child(site)
	var foundation := MeshInstance3D.new()
	var foundation_mesh := BoxMesh.new()
	foundation_mesh.size = Vector3(1.7, 0.12, 1.7)
	foundation.mesh = foundation_mesh
	foundation.position.y = 0.06
	var foundation_material := StandardMaterial3D.new()
	foundation_material.albedo_color = Color("736d63")
	foundation.material_override = foundation_material
	site.add_child(foundation)
	var bar_back := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.45, 0.11, 0.12)
	bar_back.mesh = bar_mesh
	bar_back.position = Vector3(0.0, 2.15, 0.0)
	var back_material := StandardMaterial3D.new()
	back_material.albedo_color = Color("392d2e")
	bar_back.material_override = back_material
	site.add_child(bar_back)
	var fill := MeshInstance3D.new()
	fill.mesh = bar_mesh
	fill.position = Vector3(-0.725, 2.17, -0.07)
	var fill_material := StandardMaterial3D.new()
	fill_material.albedo_color = Color("56bd58")
	fill.material_override = fill_material
	fill.scale.x = 0.01
	site.add_child(fill)
	construction_sites.append({"cell": cell, "type": building_type, "position": position_on_board, "node": site, "fill": fill, "progress": 0.0})
	_update_workers()

func _update_construction(delta: float) -> void:
	for index in range(construction_sites.size() - 1, -1, -1):
		var site: Dictionary = construction_sites[index]
		var builder_power := _building_power(site.node)
		var progress: float = minf(1.0, site.progress + delta / CONSTRUCTION_DURATION * builder_power)
		if index == 0:
			status_label.text = "Building %s: %d builder(s), %.1fx speed." % [site.type, _builder_count(site.node), builder_power]
		site.progress = progress
		var fill: MeshInstance3D = site.fill
		fill.scale.x = maxf(0.01, progress)
		fill.position.x = -0.725 + 0.725 * progress
		construction_sites[index] = site
		if progress >= 1.0:
			site.node.queue_free()
			construction_sites.remove_at(index)
			_complete_building(site.cell, site.type, site.position)

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3) -> void:
	match building_type:
		"warehouse":
			warehouse_positions.append(position_on_board)
			_create_warehouse(position_on_board)
		"sawmill":
			sawmill_positions.append(position_on_board)
			_create_sawmill(position_on_board)
		"farm":
			farm_positions.append(position_on_board)
			_create_farm(position_on_board)
		"house":
			completed_house_count += 1
			_create_house(position_on_board)
	_update_workers()
	_update_interface("%s construction completed." % building_type.capitalize())

func _create_warehouse(position_on_board: Vector3) -> void:
	var building := Node3D.new()
	building.position = position_on_board
	add_child(building)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.45, 0.9, 1.35)
	base.mesh = base_mesh
	base.position.y = 0.45
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("c78d52")
	base.material_override = wall_material
	building.add_child(base)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(1.7, 0.62, 1.62)
	roof.mesh = roof_mesh
	roof.position.y = 1.2
	roof.rotation_degrees.y = 90.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("91483e")
	roof.material_override = roof_material
	building.add_child(roof)

func _create_sawmill(position_on_board: Vector3) -> void:
	var building := Node3D.new()
	building.position = position_on_board
	add_child(building)
	var platform := MeshInstance3D.new()
	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(1.6, 0.25, 1.45)
	platform.mesh = platform_mesh
	platform.position.y = 0.13
	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color("af6f3b")
	platform.material_override = wood_material
	building.add_child(platform)
	var blade := MeshInstance3D.new()
	var blade_mesh := CylinderMesh.new()
	blade_mesh.top_radius = 0.42
	blade_mesh.bottom_radius = 0.42
	blade_mesh.height = 0.08
	blade.mesh = blade_mesh
	blade.position.y = 0.32
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color("b7c4c9")
	blade.material_override = blade_material
	building.add_child(blade)

func _create_farm(position_on_board: Vector3) -> void:
	var farm := Node3D.new()
	farm.position = position_on_board
	add_child(farm)
	for offset in [Vector3(-0.45, 0.18, -0.35), Vector3(0.15, 0.18, -0.35), Vector3(-0.15, 0.18, 0.35), Vector3(0.48, 0.18, 0.32)]:
		var crop := MeshInstance3D.new()
		var crop_mesh := CylinderMesh.new()
		crop_mesh.top_radius = 0.12
		crop_mesh.bottom_radius = 0.18
		crop_mesh.height = 0.36
		crop.mesh = crop_mesh
		crop.position = offset
		var crop_material := StandardMaterial3D.new()
		crop_material.albedo_color = Color("d2b744")
		crop.material_override = crop_material
		farm.add_child(crop)

func _create_house(position_on_board: Vector3) -> void:
	var house := Node3D.new()
	house.position = position_on_board
	house.set_meta("spawn_slots", 2)
	add_child(house)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.5, 1.0, 1.45)
	base.mesh = base_mesh
	base.position.y = 0.5
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("91a9bb")
	base.material_override = wall_material
	house.add_child(base)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(1.78, 0.7, 1.72)
	roof.mesh = roof_mesh
	roof.position.y = 1.32
	roof.rotation_degrees.y = 90.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("476573")
	roof.material_override = roof_material
	house.add_child(roof)
	var selector := Area3D.new()
	selector.add_to_group("house_selector")
	var selector_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.5, 1.6)
	selector_shape.shape = shape
	selector_shape.position.y = 0.75
	selector.add_child(selector_shape)
	house.add_child(selector)

func _update_workers() -> void:
	for index in citizens.size():
		var citizen := citizens[index]
		if citizen.is_player_controlled:
			continue
		if citizen.specialization == "courier":
			continue
		var role := _work_role_for(citizen)
		if role == "construction" and not construction_sites.is_empty():
			var site: Dictionary = construction_sites[index % construction_sites.size()]
			citizen.assign_construction(site.node)
		elif role == "forestry" and not warehouse_positions.is_empty() and not sawmill_positions.is_empty():
			citizen.assign_work("wood", tree_positions[index % tree_positions.size()], sawmill_positions[index % sawmill_positions.size()], warehouse_positions[index % warehouse_positions.size()], _has_courier())
		elif role == "farming" and not warehouse_positions.is_empty() and not farm_positions.is_empty():
			citizen.assign_work("food", farm_positions[index % farm_positions.size()], farm_positions[index % farm_positions.size()], warehouse_positions[index % warehouse_positions.size()], _has_courier())
		elif role == "excavation" and not dig_sites.is_empty() and not warehouse_positions.is_empty():
			var dig_site := citizen.assigned_dig_site
			if not is_instance_valid(dig_site):
				var site: Dictionary = dig_sites[index % dig_sites.size()]
				dig_site = site.node
			citizen.assign_excavation(dig_site)
		else:
			citizen.idle()

func _work_role_for(citizen: Citizen) -> String:
	if not citizen.manual_role.is_empty():
		return citizen.manual_role
	if citizen.specialization == "builder" and not construction_sites.is_empty():
		return "construction"
	if citizen.specialization == "forestry" and not sawmill_positions.is_empty():
		return "forestry"
	if citizen.specialization == "farming" and not farm_positions.is_empty():
		return "farming"
	if citizen.specialization == "excavation" and not dig_sites.is_empty():
		return "excavation"
	return ""

func _has_courier() -> bool:
	for citizen in citizens:
		if citizen.specialization == "courier":
			return true
	return false

func _update_couriers() -> void:
	if warehouse_positions.is_empty():
		return
	for courier in citizens:
		if courier.specialization != "courier" or courier.state != Citizen.State.IDLE:
			continue
		for worker in citizens:
			if worker != courier and worker.has_pending_resource():
				courier.assign_courier_pickup(worker, warehouse_positions[0])
				break

func _builder_count(site_node: Node3D) -> int:
	var count := 0
	for citizen in citizens:
		if citizen.is_building_site(site_node):
			count += 1
	return count

func _building_power(site_node: Node3D) -> float:
	var power := 0.0
	for citizen in citizens:
		if citizen.is_building_site(site_node):
			power += citizen.get_efficiency("construction")
	return power

func _on_resource_delivered(resource_type: String, amount: int) -> void:
	if resource_type == "food":
		food += amount
	elif resource_type == "soil":
		soil += amount
	elif resource_type == "clay":
		clay += amount
	else:
		wood += amount
	_update_interface("Workers delivered %d %s to the warehouse." % [amount, resource_type])

func _on_resource_ready(worker: Citizen, resource_type: String, amount: int) -> void:
	worker.register_pending_resource(resource_type, amount)

func _on_excavation_cycle(worker: Citizen, site_node: Node3D, efficiency: float) -> void:
	for index in range(dig_sites.size()):
		var site: Dictionary = dig_sites[index]
		if site.node != site_node:
			continue
		site.depth += 1
		if site.depth <= site.soil_limit:
			worker.deliver_excavation("soil", warehouse_positions[0])
			_update_interface("Digger is carrying soil to the warehouse.")
		elif site.depth <= site.clay_limit:
			worker.deliver_excavation("clay", warehouse_positions[0])
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("a96445")
			site.pit.material_override = pit_material
			_update_interface("Digger is carrying clay to the warehouse.")
		else:
			var rock_material := StandardMaterial3D.new()
			rock_material.albedo_color = Color("62676a")
			site.pit.material_override = rock_material
			dig_sites.remove_at(index)
			dig_cells.erase(site.cell)
			exhausted_dig_cells[site.cell] = true
			for citizen in citizens:
				if citizen.assigned_dig_site == site_node:
					citizen.assigned_dig_site = null
			_update_workers()
			_update_interface("Stone reached. This excavation is exhausted; choose another cell.")
			return
		dig_sites[index] = site
		return

func _apply_daily_needs() -> void:
	var beds := _house_count() * BED_CAPACITY
	if food >= citizens.size():
		food -= citizens.size()
		wellbeing = mini(100, wellbeing + 2)
	else:
		food = 0
		wellbeing = maxi(0, wellbeing - 14)
		_update_interface("Food shortage lowered wellbeing.")
	if beds < citizens.size():
		wellbeing = maxi(0, wellbeing - 7)
		_update_interface("Not enough housing lowered wellbeing.")
	else:
		wellbeing = mini(100, wellbeing + 1)
	_update_interface("Citizens consumed food. Next needs check in 10 seconds.")

func _house_count() -> int:
	return completed_house_count

func _building_cost() -> int:
	match build_mode:
		"warehouse": return WAREHOUSE_COST
		"sawmill": return SAWMILL_COST
		"farm": return FARM_COST
		_: return HOUSE_COST

func _update_camera(delta: float) -> void:
	var move_direction := Vector3.ZERO
	var yaw_radians := deg_to_rad(camera_yaw)
	var forward := Vector3(-sin(yaw_radians), 0.0, -cos(yaw_radians))
	var right := Vector3(cos(yaw_radians), 0.0, -sin(yaw_radians))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move_direction += forward
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move_direction -= forward
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_direction += right
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move_direction -= right
	if not move_direction.is_zero_approx():
		camera_target += move_direction.normalized() * 9.0 * delta
		camera_target.x = clampf(camera_target.x, -10.0, 10.0)
		camera_target.z = clampf(camera_target.z, -10.0, 10.0)
	_update_camera_position()

func _pan_camera(mouse_delta: Vector2) -> void:
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	camera_target -= right * mouse_delta.x * 0.035
	camera_target += forward * mouse_delta.y * 0.035
	camera_target.x = clampf(camera_target.x, -10.0, 10.0)
	camera_target.z = clampf(camera_target.z, -10.0, 10.0)
	_update_camera_position()

func _rotate_camera(mouse_delta: Vector2) -> void:
	camera_yaw -= mouse_delta.x * 0.35
	camera_pitch = clampf(camera_pitch - mouse_delta.y * 0.25, 25.0, 78.0)
	_update_camera_position()

func _update_camera_position() -> void:
	if camera == null: return
	var yaw_radians := deg_to_rad(camera_yaw)
	var pitch_radians := deg_to_rad(camera_pitch)
	var offset := Vector3(sin(yaw_radians) * cos(pitch_radians), sin(pitch_radians), cos(yaw_radians) * cos(pitch_radians)) * camera_distance
	camera.position = camera_target + offset
	camera.look_at(camera_target)

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)

func _update_interface(message: String) -> void:
	wood_label.text = "Wood: %d   Food: %d   Soil: %d   Clay: %d\nWellbeing: %d%%   Pocket: %d/%d" % [wood, food, soil, clay, wellbeing, pocket_wood, POCKET_WOOD_CAPACITY]
	status_label.text = message
	if is_first_person:
		camera_hint_label.text = "R: leave citizen  WASD/arrows: move  Mouse: look  F: interact"
	else:
		camera_hint_label.text = "Click a citizen, then R: first-person.  WASD/arrows: move camera  Right drag: rotate/tilt  Middle drag: pan  Wheel: zoom"
