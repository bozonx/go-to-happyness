extends Node3D

const BOARD_CELLS := 12
const CELL_SIZE := 2.0
const STARTING_WOOD := 30
const WAREHOUSE_COST := 10
const SAWMILL_COST := 10
const POPULATION := 5

var wood := STARTING_WOOD
var selected_cell := Vector2i(0, 0)
var build_mode := "warehouse"
var placed_buildings: Dictionary = {}
var warehouse_positions: Array[Vector3] = []
var sawmill_positions: Array[Vector3] = []
var tree_positions: Array[Vector3] = []
var citizens: Array[Citizen] = []
var camera: Camera3D
var selection_marker: MeshInstance3D
var wood_label: Label
var status_label: Label
var controls_label: Label

func _ready() -> void:
	_create_world()
	_create_interface()
	_create_forest()
	_create_citizens()
	_update_interface("Build a warehouse and a sawmill to begin production.")

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
	camera.position = Vector3(16.0, 19.0, 18.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
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
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.79, 0.24, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_marker.material_override = material
	add_child(selection_marker)
	_move_selection(Vector2i(0, 0))

func _create_forest() -> void:
	var cells := [Vector2i(-5, -4), Vector2i(-4, -5), Vector2i(-5, 4), Vector2i(4, -5), Vector2i(5, 4), Vector2i(4, 5)]
	for cell in cells:
		var tree_position := _cell_center(cell)
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
		var citizen := Citizen.new()
		citizen.position = Vector3(-1.1 + (index % 3) * 1.1, 0.0, -0.8 + (index / 3) * 1.1)
		citizen.wood_delivered.connect(_on_wood_delivered)
		add_child(citizen)
		citizens.append(citizen)

func _create_interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.07, 0.09, 0.88)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(390, 132)
	ui.add_child(panel)
	wood_label = Label.new()
	wood_label.position = Vector2(18, 14)
	wood_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(wood_label)
	status_label = Label.new()
	status_label.position = Vector2(18, 50)
	status_label.size = Vector2(354, 66)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)
	controls_label = Label.new()
	controls_label.position = Vector2(20, 674)
	controls_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(controls_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			build_mode = "warehouse"
			_update_interface("Warehouse selected.")
		elif event.keycode == KEY_2:
			build_mode = "sawmill"
			_update_interface("Sawmill selected.")
	elif event is InputEventMouseMotion:
		var cell: Variant = _cell_at_screen_position(event.position)
		if cell != null:
			_move_selection(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell: Variant = _cell_at_screen_position(event.position)
		if cell != null:
			_place_building(cell)

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

func _place_building(cell: Vector2i) -> void:
	if placed_buildings.has(cell):
		_update_interface("This cell is already occupied.")
		return
	var cost := WAREHOUSE_COST if build_mode == "warehouse" else SAWMILL_COST
	if wood < cost:
		_update_interface("Not enough wood.")
		return
	wood -= cost
	placed_buildings[cell] = build_mode
	var position_on_board := _cell_center(cell)
	if build_mode == "warehouse":
		warehouse_positions.append(position_on_board)
		_create_warehouse(position_on_board)
	else:
		sawmill_positions.append(position_on_board)
		_create_sawmill(position_on_board)
	_update_workers()
	_update_interface("%s built." % ("Warehouse" if build_mode == "warehouse" else "Sawmill"))

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

func _update_workers() -> void:
	if warehouse_positions.is_empty() or sawmill_positions.is_empty():
		return
	for index in citizens.size():
		citizens[index].assign_work(tree_positions[index % tree_positions.size()], sawmill_positions[index % sawmill_positions.size()], warehouse_positions[index % warehouse_positions.size()])

func _on_wood_delivered() -> void:
	wood += 1
	_update_interface("Workers delivered processed wood to the warehouse.")

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)

func _update_interface(message: String) -> void:
	wood_label.text = "Wood: %d   Citizens: %d   Buildings: %d" % [wood, citizens.size(), placed_buildings.size()]
	status_label.text = message
	controls_label.text = "[1] Warehouse (10)   [2] Sawmill (10)   Selected: %s   Left click: build" % build_mode.capitalize()
