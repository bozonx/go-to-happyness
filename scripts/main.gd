extends Node3D

const BOARD_CELLS := 12
const CELL_SIZE := 2.0
const STARTING_WOOD := 30
const WAREHOUSE_COST := 10

var wood := STARTING_WOOD
var selected_cell := Vector2i(0, 0)
var placed_buildings: Dictionary = {}
var camera: Camera3D
var selection_marker: MeshInstance3D
var wood_label: Label
var status_label: Label

func _ready() -> void:
	_create_world()
	_create_interface()
	_update_interface("Choose a cell to place a warehouse.")

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

func _create_interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.07, 0.09, 0.88)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(360, 116)
	ui.add_child(panel)

	wood_label = Label.new()
	wood_label.position = Vector2(18, 14)
	wood_label.add_theme_font_size_override("font_size", 24)
	panel.add_child(wood_label)

	status_label = Label.new()
	status_label.position = Vector2(18, 52)
	status_label.size = Vector2(324, 48)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)

	var controls := Label.new()
	controls.text = "Left click: place warehouse (10 wood)"
	controls.position = Vector2(20, 680)
	controls.add_theme_font_size_override("font_size", 16)
	ui.add_child(controls)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell: Variant = _cell_at_screen_position(event.position)
		if cell != null:
			_move_selection(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell: Variant = _cell_at_screen_position(event.position)
		if cell != null:
			_place_warehouse(cell)

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

func _place_warehouse(cell: Vector2i) -> void:
	if placed_buildings.has(cell):
		_update_interface("This cell is already occupied.")
		return
	if wood < WAREHOUSE_COST:
		_update_interface("Not enough wood to build a warehouse.")
		return
	wood -= WAREHOUSE_COST
	placed_buildings[cell] = "warehouse"
	_create_warehouse(_cell_center(cell))
	_update_interface("Warehouse built. It will store future production.")

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
	wall_material.roughness = 0.88
	base.material_override = wall_material
	building.add_child(base)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.left_to_right = 0.5
	roof_mesh.size = Vector3(1.7, 0.62, 1.62)
	roof.mesh = roof_mesh
	roof.position.y = 1.2
	roof.rotation_degrees.y = 90.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("91483e")
	roof.material_override = roof_material
	building.add_child(roof)

func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)

func _update_interface(message: String) -> void:
	wood_label.text = "Wood: %d    Warehouses: %d" % [wood, placed_buildings.size()]
	status_label.text = message
