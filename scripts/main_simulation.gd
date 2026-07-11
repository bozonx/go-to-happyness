extends Node3D


const BOARD_CELLS := 48
const CELL_SIZE := BuildingBlueprints.BLOCK_SIZE
const BUILDING_CLEARANCE_BLOCKS := 3.0
const MAX_BUILD_SLOPE := 0.35
const STARTING_WOOD := 30
const WAREHOUSE_COST := 10
const SAWMILL_COST := 10
const HOUSE_COST := 12
const FARM_COST := 12
const CANTEEN_COST := 16
const SCHOOL_COST := 18
const PARK_COST := 14
const BRICK_FACTORY_COST := 24
const MATERIALS_FACTORY_COST := 28
const BRICK_RESEARCH_COST := 15
const BOARD_RESEARCH_COST := 10
const BRICK_RESEARCH_DURATION := 20.0
const POPULATION := 5
const WAREHOUSE_CAPACITY := 50
const HOUSE_CAPACITY := 2
const TENT_CAPACITY := 5
const CONSTRUCTION_DURATION := 4.0
const PLAYER_SPEED := 4.2
const PLAYER_SPRINT_MULTIPLIER := 1.8
const PLAYER_JUMP_VELOCITY := 6.5
const PLAYER_GRAVITY := 18.0
const PLAYER_EYE_HEIGHT := 1.65
const HARVEST_DURATION := 1.25
const INTERACTION_RANGE := 2.25
const POCKET_WOOD_CAPACITY := 8
const DIG_RADIUS := 2.2
const DIG_REACH := 6.0
const NAVIGATION_AGENT_RADIUS := 0.38

var wood := STARTING_WOOD
var food := 20
var soil := 0
var clay := 0
var boards := 0
var bricks := 0
var wellbeing := 75
var game_minutes: float = 7.0 * 60.0
const GAME_DAY_REAL_SECONDS := 300.0
const GAME_MINUTES_PER_SECOND := 1440.0 / GAME_DAY_REAL_SECONDS
var time_multiplier := 1.0
var previous_clock_minute := -1
var active_meal_hour := -1
var selected_cell := Vector2i(0, 0)
var selected_world_position := Vector3.ZERO
var build_mode := ""
var placed_buildings: Dictionary = {}
var house_cells: Dictionary = {}
var tree_cells: Dictionary = {}
var warehouse_positions: Array[Vector3] = []
var sawmill_positions: Array[Vector3] = []
var farm_positions: Array[Vector3] = []
var school_positions: Array[Vector3] = []
var park_positions: Array[Vector3] = []
var factories: Array[Node3D] = []
var brick_construction_unlocked := false
var brick_research_progress := -1.0
var tree_positions: Array[Vector3] = []
var citizens: Array[Citizen] = []
var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: Environment
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
var pocket_food := 0
var interaction_time := 0.0
var interaction_action := ""
var interaction_resource := ""
var interaction_hint_label: Label
var interaction_progress: ProgressBar
var dig_sites: Array[Dictionary] = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}
var dig_mode := false
var house_menu: Panel
var house_menu_title: Label
var selected_house: Node3D
var tent: Node3D
var tent_cell := Vector2i(0, 0)
var canteen: Node3D
var canteen_position := Vector3.ZERO
var canteen_food := 0
var pending_canteen_delivery := false
var clock_label: Label
var tent_dismantle_progress := -1.0
var voxel_terrain: VoxelLodTerrain
var voxel_tool: VoxelTool
var navigation_region: NavigationRegion3D
var building_positions: Array[Vector3] = []
var building_footprints: Array[Dictionary] = []
var selected_school: Node3D
var school_menu: Panel
var school_menu_title: Label
var materials_factory_menu: Panel
var materials_factory_menu_title: Label
var selected_materials_factory: Node3D
var house_lights: Array[Dictionary] = []
var house_light_update_minute := -1


func _ready() -> void:
	_create_world()
	_create_interface()
	_create_forest()
	_create_starting_tent()
	_create_citizens()
	_update_interface("All five starting workers live in the tent. Resettle them into houses to remove the housing debuff.")

func _process(delta: float) -> void:
	if is_first_person:
		_update_player_control(delta)
		_update_interaction(delta)
	else:
		_update_camera(delta)
	_update_construction(delta)
	_update_tent_dismantle(delta)
	_update_clock(delta)
	_update_daylight()
	_update_house_lights()
	_update_canteen_delivery()
	_update_brick_research(delta)
	if not _is_night():
		_update_couriers()
	if selected_builder != null and build_menu.visible:
		_show_selected_citizen_menu()

func _update_workers() -> void:
	if _is_night():
		for citizen in citizens:
			citizen.go_home()
		return
	for index in citizens.size():
		var citizen := citizens[index]
		if citizen.is_player_controlled:
			continue
		if citizen.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY, Citizen.State.COURIER_TO_WORKER, Citizen.State.COURIER_TO_WAREHOUSE, Citizen.State.WAITING_COURIER]:
			continue
		if citizen.blocked_by_storage:
			if _stored_resources() >= _warehouse_capacity():
				continue
			citizen.blocked_by_storage = false
		if citizen.specialization == "cook":
			if is_instance_valid(canteen):
				citizen.assign_canteen_work(canteen_position)
			continue
		if citizen.specialization == "teacher":
			if not school_positions.is_empty():
				citizen.assign_teacher_work(school_positions[0])
			continue
		if citizen.specialization == "courier":
			continue
		if citizen.specialization == "factory_worker":
			var factory := _factory_for_role("factory_worker")
			if factory != null:
				citizen.assign_factory_work(factory, "factory_work")
			continue
		if citizen.specialization == "builder" and construction_sites.is_empty():
			var materials_plant := _factory_for_role("engineer")
			if materials_plant != null:
				citizen.assign_factory_work(materials_plant, "construction")
				continue
		if citizen.specialization == "engineer":
			var materials_factory := _factory_for_role("engineer")
			if materials_factory != null:
				citizen.assign_factory_work(materials_factory, "engineering")
			continue
		if not citizen.training_role.is_empty() and citizen.training_days_completed < 10 and int(game_minutes) / 60 < 12:
			citizen.attend_school()
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

func _factory_for_role(role: String) -> Node3D:
	if role == "factory_worker":
		for type in ["materials_factory", "brick_factory", "recycling_factory", "metal_factory"]:
			for factory in factories:
				if factory.get_meta("building_type", "") != type:
					continue
				var assigned_workers := 0
				for citizen in citizens:
					assigned_workers += 1 if citizen.factory == factory and citizen.specialization == "factory_worker" else 0
				if assigned_workers < int(factory.get_meta("required_factory_workers", 1)):
					return factory
	for factory in factories:
		if not is_instance_valid(factory):
			continue
		var type: String = factory.get_meta("building_type", "")
		if role == "factory_worker" and type in ["brick_factory", "materials_factory", "recycling_factory", "metal_factory"]:
			return factory
		if role == "engineer" and type == "materials_factory":
			return factory
	return null

func _has_courier() -> bool:
	for citizen in citizens:
		if citizen.specialization == "courier":
			return true
	return false

func _has_cook() -> bool:
	for citizen in citizens:
		if citizen.specialization == "cook" and not citizen.is_player_controlled and is_instance_valid(canteen) and citizen.global_position.distance_to(canteen_position) <= 2.2:
			return true
	return false

func _update_daylight() -> void:
	if sun == null or world_environment == null:
		return
	var hour := game_minutes / 60.0
	var solar_height := sin((hour - 6.0) / 12.0 * PI)
	var direct_light := smoothstep(0.0, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.0, 0.28, absf(solar_height))
	var night_color := Color("101a2b")
	var twilight_color := Color("d87850")
	var day_color := Color("78a9c5")
	if solar_height <= 0.0:
		world_environment.background_color = night_color.lerp(twilight_color, twilight)
	else:
		world_environment.background_color = twilight_color.lerp(day_color, direct_light)
	world_environment.ambient_light_color = Color("4b5872").lerp(Color("d7ebef"), maxf(direct_light, twilight * 0.35))
	world_environment.ambient_light_energy = lerpf(0.18, 0.65, maxf(direct_light, twilight * 0.3))
	sun.rotation_degrees = Vector3(-90.0 + (hour - 12.0) * 15.0, -32.0, 0.0)
	sun.light_color = Color("f08a5d").lerp(Color("fff2d1"), direct_light)
	sun.light_energy = lerpf(0.0, 1.2, direct_light)
	sun.shadow_enabled = direct_light > 0.05

func _update_clock(delta: float) -> void:
	game_minutes = fposmod(game_minutes + delta * GAME_MINUTES_PER_SECOND, 24.0 * 60.0)
	var current_minute := int(game_minutes)
	var hour := current_minute / 60
	var minute := current_minute % 60
	clock_label.text = "%s  %02d:%02d  x%d" % ["Night" if _is_night() else "Day", hour, minute, int(time_multiplier)]
	if previous_clock_minute == current_minute:
		return
	if previous_clock_minute < 0:
		previous_clock_minute = current_minute
		return
	var minute_to_process := posmod(previous_clock_minute + 1, 24 * 60)
	while minute_to_process != posmod(current_minute + 1, 24 * 60):
		_handle_clock_minute(minute_to_process)
		minute_to_process = posmod(minute_to_process + 1, 24 * 60)
	previous_clock_minute = current_minute

func _handle_clock_minute(clock_minute: int) -> void:
	var hour := clock_minute / 60
	var minute := clock_minute % 60
	if minute == 0 and (hour == 8 or hour == 13 or hour == 19) and active_meal_hour != hour:
		active_meal_hour = hour
		_start_meal(hour)
	if minute == 0 and hour == 14:
		_start_park_rest(false)
	if minute == 0 and hour == 16:
		_start_park_rest(true)
	if minute == 0 and hour == 18:
		_start_park_rest(false)
	if minute == 0 and hour == 21:
		_update_workers()
		_update_interface("Nightfall: workers are returning to their assigned homes.")
	if minute == 0 and hour == 6:
		active_meal_hour = -1
		_update_workers()
		_update_interface("Morning: workers left their homes for their assignments.")
	if minute == 0 and hour == 12:
		for citizen in citizens:
			citizen.finish_school_day()
		_update_workers()

func _update_house_lights() -> void:
	var hour := int(game_minutes) / 60
	var minute := int(game_minutes) % 60
	var clock_minute := int(game_minutes)
	if house_light_update_minute == clock_minute:
		return
	house_light_update_minute = clock_minute
	var evening := hour >= 20 or hour < 2
	var late_night := hour >= 22 or hour < 2
	for record in house_lights:
		var light: OmniLight3D = record.light
		if not is_instance_valid(light):
			continue
		if not evening:
			light.visible = false
		elif not late_night:
			light.visible = true
		elif minute % 15 == 0:
			light.visible = randf() > 0.35

func _is_night() -> bool:
	var hour := int(game_minutes) / 60
	return hour >= 21 or hour < 6

func _start_meal(hour: int) -> void:
	if not is_instance_valid(canteen):
		for citizen in citizens:
			if not citizen.is_player_controlled:
				citizen.receive_meal(false)
		_update_interface("%02d:00 meal missed: no canteen." % hour)
		return
	if not _has_cook():
		for citizen in citizens:
			if not citizen.is_player_controlled:
				citizen.receive_meal(false)
		_update_interface("%02d:00 meal missed: the canteen needs a cook." % hour)
		return
	for citizen in citizens:
		# The cook keeps the canteen staffed during the lunch service and receives
		# their park break after the rush.
		if citizen.specialization == "cook" and hour == 13:
			continue
		if citizen.is_available_for_schedule():
			citizen.go_to_canteen(canteen_position)
	_update_interface("%02d:00 meal service started. Residents are heading to the canteen." % hour)

func _start_park_rest(cooks_only: bool) -> void:
	if park_positions.is_empty():
		return
	var sent := 0
	for citizen in citizens:
		if citizen.is_player_controlled or not citizen.is_available_for_schedule():
			continue
		if (citizen.specialization == "cook") != cooks_only:
			continue
		citizen.go_to_park(park_positions[sent % park_positions.size()])
		sent += 1
	if sent > 0:
		_update_interface("%02d:00 park break: %d residents are resting." % [int(game_minutes) / 60, sent])

func _on_meal_finished(citizen: Citizen) -> void:
	var served := is_instance_valid(canteen) and _has_cook() and canteen_food > 0
	if served:
		canteen_food -= 1
	citizen.receive_meal(served)
	if not served:
		_update_interface("Canteen ran out of food. A worker missed their meal.")
	if not _is_night():
		_update_workers()

func _update_canteen_delivery() -> void:
	if not is_instance_valid(canteen) or warehouse_positions.is_empty() or food <= 0 or canteen_food >= 12 or pending_canteen_delivery:
		return
	var carrier: Citizen
	for citizen in citizens:
		if citizen.specialization == "courier" and citizen.state == Citizen.State.IDLE:
			carrier = citizen
			break
	if carrier == null:
		for citizen in citizens:
			if citizen.specialization == "cook" and citizen.state == Citizen.State.IDLE:
				carrier = citizen
				break
	if carrier == null:
		return
	var amount := mini(4, food)
	food -= amount
	pending_canteen_delivery = true
	carrier.deliver_food_to_canteen(warehouse_positions[0], canteen_position, amount)

func _on_canteen_delivery_finished(worker: Citizen, amount: int) -> void:
	canteen_food += amount
	pending_canteen_delivery = false
	if worker.specialization == "cook":
		worker.assign_canteen_work(canteen_position)
	_update_interface("Canteen received %d food. Stock: %d." % [amount, canteen_food])

func _update_couriers() -> void:
	if warehouse_positions.is_empty():
		return
	for courier in citizens:
		if courier.specialization != "courier" or courier.state != Citizen.State.IDLE:
			continue
		if is_instance_valid(courier.courier_worker):
			if courier.courier_worker.has_pending_resource():
				courier.assign_courier_pickup(courier.courier_worker, warehouse_positions[0])
			continue
		for worker in citizens:
			if worker != courier and worker.has_pending_resource():
				courier.courier_worker = worker
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

func _on_resource_delivered(worker: Citizen, resource_type: String, amount: int) -> void:
	var storage_amount := amount * 2 if resource_type == "wood" else amount
	if _stored_resources() + storage_amount > _warehouse_capacity():
		worker.storage_delivery_result(false)
		_update_interface("Warehouse is full. Build another warehouse; the worker went home.")
		return
	if resource_type == "food":
		food += amount
	elif resource_type == "soil":
		soil += amount
	elif resource_type == "clay":
		clay += amount
	else:
		wood += amount
		boards += amount
	worker.storage_delivery_result(true)
	_update_interface("Workers delivered %d %s to the warehouse." % [amount, resource_type])

func _on_factory_cycle(worker: Citizen, factory: Node3D) -> void:
	if not is_instance_valid(factory):
		return
	var type: String = factory.get_meta("building_type", "")
	if type == "brick_factory":
		if clay < 1:
			return
		clay -= 1
		bricks += 1
		_update_interface("Brick factory produced 1 brick.")

func _materials_factory_staffed(factory: Node3D) -> bool:
	var has_worker := false
	var has_builder := false
	var has_engineer := false
	for citizen in citizens:
		if citizen.factory != factory:
			continue
		has_worker = has_worker or citizen.specialization == "factory_worker"
		has_builder = has_builder or citizen.specialization == "builder"
		has_engineer = has_engineer or citizen.specialization == "engineer"
	return has_worker and has_builder and has_engineer

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

func _building_cost() -> int:
	match build_mode:
		"warehouse": return WAREHOUSE_COST
		"sawmill": return SAWMILL_COST
		"farm": return FARM_COST
		"canteen": return CANTEEN_COST
		"school": return SCHOOL_COST
		"park": return PARK_COST
		"brick_factory": return BRICK_FACTORY_COST
		"materials_factory": return MATERIALS_FACTORY_COST
		_: return HOUSE_COST

func _stored_resources() -> int:
	return wood + food + soil + clay + boards + bricks

func _warehouse_capacity() -> int:
	# Starting supplies are kept at the tent until the first warehouse is built.
	return maxi(WAREHOUSE_CAPACITY, warehouse_positions.size() * WAREHOUSE_CAPACITY)

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

func _cell_from_position(position_on_board: Vector3) -> Vector2i:
	return Vector2i(floori(position_on_board.x / CELL_SIZE), floori(position_on_board.z / CELL_SIZE))

func _is_board_cell(cell: Vector2i) -> bool:
	var half_cells := BOARD_CELLS / 2
	return cell.x >= -half_cells and cell.x < half_cells and cell.y >= -half_cells and cell.y < half_cells

func _find_path_around_houses(from: Vector3, destination: Vector3, may_enter_destination_house: bool) -> Array[Vector3]:
	var start := _cell_from_position(from)
	var goal := _cell_from_position(destination)
	if not _is_board_cell(start) or not _is_board_cell(goal):
		return [destination]
	var final_destination := destination
	if house_cells.has(goal) and not may_enter_destination_house:
		var closest_accessible_cell: Variant = null
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var adjacent: Vector2i = goal + direction
			if not _is_board_cell(adjacent) or house_cells.has(adjacent):
				continue
			if closest_accessible_cell == null or _cell_center(adjacent).distance_squared_to(from) < _cell_center(closest_accessible_cell).distance_squared_to(from):
				closest_accessible_cell = adjacent
		if closest_accessible_cell == null:
			return []
		goal = closest_accessible_cell
		final_destination = _cell_center(goal)
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal:
			break
		for direction in directions:
			var next: Vector2i = current + direction
			if not _is_board_cell(next) or came_from.has(next):
				continue
			if house_cells.has(next) and next != start and (next != goal or not may_enter_destination_house):
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return [destination]
	var cells: Array[Vector2i] = []
	var step := goal
	while step != start:
		cells.push_front(step)
		step = came_from[step]
	var path: Array[Vector3] = []
	for cell in cells:
		path.append(final_destination if cell == goal else _cell_center(cell))
	return path

func _update_interface(message: String) -> void:
	wood_label.text = "Wood: %d  Boards: %d  Bricks: %d\nFood: %d  Canteen: %d  Soil: %d  Clay: %d\nStorage: %d/%d  Tent: %d/%d  Population: %d" % [wood, boards, bricks, food, canteen_food, soil, clay, _stored_resources(), _warehouse_capacity(), _tent_resident_count(), TENT_CAPACITY, citizens.size()]
	status_label.text = message
	if is_first_person:
		camera_hint_label.text = "R: leave citizen  WASD/arrows: move  Space: jump  Shift: sprint  Mouse: look  LMB: interact  RMB: dig"
	else:
		camera_hint_label.text = "Click a citizen, then R: first-person. Build freely on voxel terrain. Right drag: rotate  Middle drag: pan  Wheel: zoom"


func _create_world() -> void:
	var environment := WorldEnvironment.new()
	world_environment = Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("78a9c5")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("d7ebef")
	world_environment.ambient_light_energy = 0.65
	world_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = world_environment
	add_child(environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	_update_daylight()

	camera = Camera3D.new()
	add_child(camera)
	_update_camera_position()
	_create_voxel_terrain()
	_create_navigation_region()
	_create_selection_marker()

func _create_voxel_terrain() -> void:
	voxel_terrain = VoxelLodTerrain.new()
	voxel_terrain.mesher = VoxelMesherTransvoxel.new()
	var generator := VoxelGeneratorNoise2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.025
	generator.noise = noise
	generator.channel = VoxelBuffer.CHANNEL_SDF
	generator.height_start = -0.15
	generator.height_range = 0.3
	voxel_terrain.generator = generator
	voxel_terrain.generate_collisions = true
	voxel_terrain.view_distance = 192
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5f8953")
	material.roughness = 0.95
	voxel_terrain.material = material
	add_child(voxel_terrain)
	# Стример подгружает воксели вокруг камеры (нужно и для отрисовки, и для копания).
	camera.add_child(VoxelViewer.new())
	voxel_tool = voxel_terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_SDF

func _create_navigation_region() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.use_edge_connections = true
	add_child(navigation_region)
	_rebuild_navigation_mesh()

func _rebuild_navigation_mesh() -> void:
	if navigation_region == null:
		return
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = NAVIGATION_AGENT_RADIUS
	navigation_mesh.agent_height = 1.75
	navigation_mesh.agent_max_climb = 0.45
	navigation_mesh.agent_max_slope = 52.0
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	var half_cells := BOARD_CELLS / 2
	for x in range(-half_cells, half_cells):
		for z in range(-half_cells, half_cells):
			if _is_navigation_cell_blocked(Vector2i(x, z)):
				continue
			var vertex_index := vertices.size()
			vertices.append(Vector3(x, 0.0, z))
			vertices.append(Vector3(x + 1.0, 0.0, z))
			vertices.append(Vector3(x + 1.0, 0.0, z + 1.0))
			vertices.append(Vector3(x, 0.0, z + 1.0))
			polygons.append(PackedInt32Array([vertex_index, vertex_index + 2, vertex_index + 1]))
			polygons.append(PackedInt32Array([vertex_index, vertex_index + 3, vertex_index + 2]))
	navigation_mesh.vertices = vertices
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = navigation_mesh
	if is_inside_tree():
		NavigationServer3D.map_force_update(get_world_3d().navigation_map)

func _is_navigation_cell_blocked(cell: Vector2i) -> bool:
	for record in building_footprints:
		var center: Vector3 = record.center
		var footprint: Vector2i = record.footprint
		var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
		var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
		if cell.x >= min_x and cell.x < min_x + footprint.x and cell.y >= min_z and cell.y < min_z + footprint.y:
			return true
	return false

func _create_selection_marker() -> void:
	selection_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(1.0, 0.04, 1.0)
	selection_marker.mesh = marker_mesh
	selection_material = StandardMaterial3D.new()
	selection_material.albedo_color = Color(0.95, 0.79, 0.24, 0.55)
	selection_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_marker.material_override = selection_material
	selection_marker.visible = false
	add_child(selection_marker)
	_move_selection(Vector3.ZERO)

func _create_forest() -> void:
	var cells := [Vector2i(-11, -10), Vector2i(-8, -12), Vector2i(-5, -9), Vector2i(-2, -12), Vector2i(3, -11), Vector2i(7, -9), Vector2i(11, -12), Vector2i(13, -7), Vector2i(-13, -5), Vector2i(-9, -4), Vector2i(-6, -2), Vector2i(7, -3), Vector2i(11, -1), Vector2i(14, 3), Vector2i(-14, 4), Vector2i(-10, 7), Vector2i(-6, 10), Vector2i(-2, 13), Vector2i(3, 10), Vector2i(7, 13), Vector2i(11, 8), Vector2i(14, 12), Vector2i(-12, 13), Vector2i(5, 5)]
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
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.27
	trunk_mesh.height = 3.6
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.8
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color("684630")
	trunk.material_override = trunk_material
	tree.add_child(trunk)
	for crown_data in [[Vector3(-0.35, 3.75, 0.0), 1.05], [Vector3(0.38, 4.05, 0.1), 1.16], [Vector3(0.0, 4.72, 0.0), 0.96]]:
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = crown_data[1]
		crown_mesh.height = crown_data[1] * 1.35
		crown.mesh = crown_mesh
		crown.position = crown_data[0]
		var crown_material := StandardMaterial3D.new()
		crown_material.albedo_color = Color("2d633b").lightened(randf_range(-0.06, 0.08))
		crown.material_override = crown_material
		tree.add_child(crown)

func _create_starting_tent() -> void:
	tent = Node3D.new()
	tent.position = _cell_center(tent_cell)
	building_positions.append(tent.position)
	building_footprints.append({"center": tent.position, "footprint": Vector2i(3, 3), "node": tent})
	_rebuild_navigation_mesh()
	tent.set_meta("is_tent", true)
	placed_buildings[tent_cell] = "tent"
	house_cells[tent_cell] = true
	add_child(tent)
	var base := MeshInstance3D.new()
	var base_mesh := PrismMesh.new()
	base_mesh.size = Vector3(3.0, 2.2, 3.0)
	base.mesh = base_mesh
	base.position.y = 1.1
	base.rotation_degrees.y = 90.0
	var tent_material := StandardMaterial3D.new()
	tent_material.albedo_color = Color("c7a96a")
	base.material_override = tent_material
	tent.add_child(base)
	var selector := Area3D.new()
	selector.add_to_group("house_selector")
	selector.collision_layer = 4
	selector.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.2, 3.0)
	shape.shape = box
	shape.position.y = 1.1
	selector.add_child(shape)
	tent.add_child(selector)

func _create_citizens() -> void:
	for index in range(POPULATION):
		_add_citizen(Vector3(-1.1 + (index % 3) * 1.1, 0.0, -0.8 + (index / 3) * 1.1))

func _add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	var citizen := Citizen.new()
	citizen.position = spawn_position
	add_child(citizen)
	citizen.setup_specialization(primary_specialization if not primary_specialization.is_empty() else ["builder", "forestry", "farming"][citizens.size() % 3])
	citizen.setup_navigation(_find_path_around_houses)
	citizen.resource_delivered.connect(_on_resource_delivered)
	citizen.excavation_cycle.connect(_on_excavation_cycle)
	citizen.resource_ready.connect(_on_resource_ready)
	citizen.meal_finished.connect(_on_meal_finished)
	citizen.canteen_delivery_finished.connect(_on_canteen_delivery_finished)
	citizens.append(citizen)
	if is_instance_valid(tent):
		citizen.assign_home(tent)
		citizen.add_debuff("tent", 25.0)


func _create_interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.07, 0.09, 0.88)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(500, 176)
	ui.add_child(panel)
	wood_label = Label.new()
	wood_label.position = Vector2(18, 14)
	wood_label.size = Vector2(464, 64)
	wood_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(wood_label)
	status_label = Label.new()
	status_label.position = Vector2(18, 84)
	status_label.size = Vector2(464, 76)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(status_label)
	camera_hint_label = Label.new()
	camera_hint_label.position = Vector2(20, 682)
	camera_hint_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(camera_hint_label)
	clock_label = Label.new()
	clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -220
	clock_label.offset_top = 22
	clock_label.offset_right = -22
	clock_label.offset_bottom = 52
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(clock_label)
	_create_time_controls(ui)
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
	_create_school_menu(ui)
	_create_materials_factory_menu(ui)

func _create_time_controls(ui: CanvasLayer) -> void:
	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_left = -220
	controls.offset_top = 58
	controls.offset_right = -22
	controls.offset_bottom = 90
	controls.alignment = BoxContainer.ALIGNMENT_END
	ui.add_child(controls)
	for multiplier in [1.0, 2.0, 4.0]:
		var button := Button.new()
		button.text = "x%d" % int(multiplier)
		button.tooltip_text = "Simulation speed x%d" % int(multiplier)
		button.custom_minimum_size = Vector2(56, 30)
		button.pressed.connect(_set_time_multiplier.bind(multiplier))
		controls.add_child(button)

func _set_time_multiplier(multiplier: float) -> void:
	time_multiplier = multiplier
	Engine.time_scale = multiplier
	_update_interface("Simulation speed set to x%d." % int(multiplier))

func _create_build_menu(ui: CanvasLayer) -> void:
	build_menu = Panel.new()
	build_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_menu.offset_left = -324.0
	build_menu.offset_top = -780.0
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
	_add_build_button("Canteen - 16 wood", "canteen", 398)
	_add_build_button("House - 12 wood", "house", 434)
	_add_build_button("School - 18 wood", "school", 470)
	_add_build_button("Park - 14 wood", "park", 506)
	_add_build_button("Brick factory - 24 wood", "brick_factory", 542)
	_add_build_button("Materials factory - 28 wood", "materials_factory", 578)
	_add_build_button("Recycling factory - bricks", "recycling_factory", 614)
	_add_build_button("Metal factory - bricks", "metal_factory", 650)
	_add_build_button("City hall - bricks", "city_hall", 686)
	_add_build_button("Leisure center - bricks", "leisure_center", 722)

func _create_school_menu(ui: CanvasLayer) -> void:
	school_menu = Panel.new()
	school_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	school_menu.offset_left = -324.0
	school_menu.offset_top = -360.0
	school_menu.offset_right = -20.0
	school_menu.offset_bottom = -20.0
	school_menu.visible = false
	ui.add_child(school_menu)
	school_menu_title = Label.new()
	school_menu_title.position = Vector2(16, 14)
	school_menu_title.size = Vector2(272, 72)
	school_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	school_menu.add_child(school_menu_title)
	var roles := [["Construction", "construction"], ["Forestry", "forestry"], ["Farming", "farming"], ["Excavation", "excavation"], ["Factory worker", "factory_worker"], ["Engineer", "engineer"]]
	school_menu.offset_top = -430.0
	for index in range(roles.size()):
		var button := Button.new()
		button.text = "Train: %s" % roles[index][0]
		button.position = Vector2(16, 94 + index * 32)
		button.size = Vector2(272, 28)
		button.pressed.connect(_start_school_training.bind(roles[index][1]))
		school_menu.add_child(button)

func _start_school_training(role: String) -> void:
	if selected_builder == null or selected_school == null:
		return
	selected_builder.start_training(role, selected_school.global_position)
	school_menu.visible = false
	_update_interface("Training started: 10 mornings in school, then regular work.")

func _create_house_menu(ui: CanvasLayer) -> void:
	house_menu = Panel.new()
	house_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	house_menu.offset_left = -324.0
	house_menu.offset_top = -378.0
	house_menu.offset_right = -20.0
	house_menu.offset_bottom = -20.0
	house_menu.visible = false
	ui.add_child(house_menu)
	house_menu_title = Label.new()
	house_menu_title.position = Vector2(16, 14)
	house_menu_title.size = Vector2(272, 42)
	house_menu_title.add_theme_font_size_override("font_size", 17)
	house_menu.add_child(house_menu_title)
	_add_house_resettle_button()
	_add_house_spawn_button("Spawn Builder", "builder", 102)
	_add_house_spawn_button("Spawn Forester", "forestry", 136)
	_add_house_spawn_button("Spawn Farmer", "farming", 170)
	_add_house_spawn_button("Spawn Digger", "excavation", 204)
	_add_house_spawn_button("Spawn Courier", "courier", 238)
	_add_house_spawn_button("Spawn Cook", "cook", 272)
	_add_house_spawn_button("Spawn Teacher", "teacher", 306)
	_add_house_spawn_button("Spawn Factory worker", "factory_worker", 340)
	_add_house_spawn_button("Spawn Engineer", "engineer", 374)
	house_menu.offset_top = -450.0

func _create_materials_factory_menu(ui: CanvasLayer) -> void:
	materials_factory_menu = Panel.new()
	materials_factory_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	materials_factory_menu.offset_left = -324.0
	materials_factory_menu.offset_top = -260.0
	materials_factory_menu.offset_right = -20.0
	materials_factory_menu.offset_bottom = -20.0
	materials_factory_menu.visible = false
	ui.add_child(materials_factory_menu)
	materials_factory_menu_title = Label.new()
	materials_factory_menu_title.position = Vector2(16, 14)
	materials_factory_menu_title.size = Vector2(272, 94)
	materials_factory_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	materials_factory_menu.add_child(materials_factory_menu_title)
	var research_button := Button.new()
	research_button.text = "Research brick construction"
	research_button.position = Vector2(16, 120)
	research_button.size = Vector2(272, 32)
	research_button.pressed.connect(_start_brick_research)
	materials_factory_menu.add_child(research_button)

func _show_materials_factory_menu() -> void:
	if selected_materials_factory == null:
		return
	materials_factory_menu.visible = true
	if brick_construction_unlocked:
		materials_factory_menu_title.text = "Materials factory\nBrick construction unlocked."
	elif brick_research_progress >= 0.0:
		materials_factory_menu_title.text = "Materials factory\nResearch: %d%%" % roundi(brick_research_progress * 100.0)
	else:
		materials_factory_menu_title.text = "Materials factory\nNeeds factory worker, builder and engineer.\nResearch cost: %d bricks, %d boards." % [BRICK_RESEARCH_COST, BOARD_RESEARCH_COST]

func _start_brick_research() -> void:
	if selected_materials_factory == null or brick_construction_unlocked or brick_research_progress >= 0.0:
		return
	if not _materials_factory_staffed(selected_materials_factory):
		_update_interface("Research needs a factory worker, builder and engineer assigned to this factory.")
		return
	if bricks < BRICK_RESEARCH_COST or boards < BOARD_RESEARCH_COST:
		_update_interface("Research needs %d bricks and %d boards." % [BRICK_RESEARCH_COST, BOARD_RESEARCH_COST])
		return
	bricks -= BRICK_RESEARCH_COST
	boards -= BOARD_RESEARCH_COST
	brick_research_progress = 0.0
	_show_materials_factory_menu()
	_update_interface("Brick construction research started.")

func _update_brick_research(delta: float) -> void:
	if brick_research_progress < 0.0 or brick_construction_unlocked:
		return
	brick_research_progress = minf(1.0, brick_research_progress + delta / BRICK_RESEARCH_DURATION)
	if brick_research_progress >= 1.0:
		brick_construction_unlocked = true
		brick_research_progress = -1.0
		_update_interface("Brick construction unlocked: recycling, metal, city hall and leisure center are available.")
	if materials_factory_menu != null and materials_factory_menu.visible:
		_show_materials_factory_menu()

func _add_house_resettle_button() -> void:
	var button := Button.new()
	button.text = "Resettle tent resident"
	button.position = Vector2(16, 64)
	button.size = Vector2(272, 30)
	button.pressed.connect(_resettle_tent_resident)
	house_menu.add_child(button)

func _resettle_tent_resident() -> void:
	if selected_house == null or int(selected_house.get_meta("spawn_slots", 0)) <= 0:
		return
	for citizen in citizens:
		if citizen.home == tent:
			citizen.assign_home(selected_house)
			citizen.remove_debuff("tent")
			selected_house.set_meta("spawn_slots", int(selected_house.get_meta("spawn_slots", 0)) - 1)
			_show_house_menu()
			_update_interface("A resident moved out of the tent. Their maximum satisfaction increased.")
			_check_tent_dismantle()
			return
	_update_interface("No residents remain in the tent.")

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
	citizens.back().assign_home(selected_house)
	citizens.back().remove_debuff("tent")
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
	house_menu_title.text = "House residents\nFree beds: %d/%d" % [slots, HOUSE_CAPACITY]

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
	_move_selection(selected_world_position)
	_update_interface("Choose a clear point on the voxel terrain for excavation.")

func _place_dig_site(world_position: Vector3) -> void:
	var cell := _placement_key(world_position)
	if not _can_excavate(world_position):
		_update_interface("Excavation is not allowed at this point.")
		return
	var site := _dig_site_at(cell)
	if site.is_empty():
		site = _create_dig_site(cell, world_position)
	selected_builder.assigned_dig_site = site.node
	selected_builder.manual_role = "excavation"
	dig_mode = false
	selection_marker.visible = false
	_update_workers()
	_show_selected_citizen_menu()
	_update_interface("Excavation assigned. Soil and clay will be exposed before stone.")

func _can_excavate(world_position: Vector3) -> bool:
	var cell := _placement_key(world_position)
	return not exhausted_dig_cells.has(cell) and _is_clear_of_objects(world_position, 1.0)

func _dig_site_at(cell: Vector2i) -> Dictionary:
	for site in dig_sites:
		if site.cell == cell:
			return site
	return {}

func _create_dig_site(cell: Vector2i, world_position: Vector3) -> Dictionary:
	var site_node := Node3D.new()
	site_node.position = world_position
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
	if next_mode in ["recycling_factory", "metal_factory", "city_hall", "leisure_center"] and not brick_construction_unlocked:
		_update_interface("This brick building is locked. Research brick construction at a materials factory.")
		return
	build_mode = next_mode
	selection_marker.visible = true
	_move_selection(selected_world_position)
	_update_interface("%s selected. Choose a clear point on the voxel terrain." % build_mode.capitalize())

func _cancel_build_action() -> void:
	build_mode = ""
	dig_mode = false
	selection_marker.visible = false
	build_menu.visible = false
	selected_builder = null
	_update_interface("Construction mode cancelled.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		_toggle_first_person()
		get_viewport().set_input_as_handled()
		return
	if is_first_person:
		if event is InputEventMouseMotion:
			player_yaw -= event.relative.x * 0.0035
			player_pitch = clampf(player_pitch - event.relative.y * 0.003, deg_to_rad(-70.0), deg_to_rad(65.0))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_interaction()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_dig_voxel_at_crosshair()
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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (not build_mode.is_empty() or dig_mode):
		_cancel_build_action()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rotating_camera = event.pressed
	elif event is InputEventMouseMotion:
		if is_rotating_camera:
			_rotate_camera(event.relative)
		elif is_panning_camera:
			_pan_camera(event.relative)
		elif selected_builder != null and (not build_mode.is_empty() or dig_mode):
			var terrain_point: Variant = _terrain_point_at_screen_position(event.position)
			if terrain_point != null:
				_move_selection(terrain_point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_builder != null and dig_mode:
			var dig_point: Variant = _terrain_point_at_screen_position(event.position)
			if dig_point != null:
				_place_dig_site(dig_point)
		elif selected_builder != null and not build_mode.is_empty():
			var build_point: Variant = _terrain_point_at_screen_position(event.position)
			if build_point != null:
				_place_building(build_point)
		else:
			_select_citizen_at(event.position)

func _select_citizen_at(screen_position: Vector2) -> void:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if hit.collider.is_in_group("house_selector"):
		selected_house = hit.collider.get_parent() as Node3D
		selected_builder = null
		build_menu.visible = false
		if selected_house == tent:
			house_menu.visible = false
			_update_interface("Starting tent: %d/%d residents. It cannot recruit new people." % [_tent_resident_count(), TENT_CAPACITY])
		else:
			_show_house_menu()
			_update_interface("House selected. Resettle a tent resident or recruit a new worker.")
		return
	if hit.collider.is_in_group("school_selector"):
		selected_school = hit.collider.get_parent() as Node3D
		house_menu.visible = false
		build_menu.visible = false
		if selected_builder == null:
			school_menu.visible = false
			_update_interface("Select a citizen first, then click the school to choose training.")
			return
		school_menu_title.text = "Student: %s\nChoose a profession. Study takes 10 mornings." % selected_builder.role_label()
		school_menu.visible = true
		_update_interface("Choose the profession for this student.")
		return
	if hit.collider.is_in_group("materials_factory_selector"):
		selected_materials_factory = hit.collider.get_parent() as Node3D
		selected_house = null
		selected_school = null
		house_menu.visible = false
		school_menu.visible = false
		build_menu.visible = false
		_show_materials_factory_menu()
		_update_interface("Materials factory selected. Start brick construction research here.")
		return
	if not hit.collider.is_in_group("citizen_selector"):
		return
	var clicked_citizen := hit.collider.get_parent() as Citizen
	if selected_builder != null and selected_builder.specialization == "courier" and clicked_citizen != selected_builder:
		selected_builder.courier_worker = clicked_citizen
		_update_interface("Courier assigned to this worker. Click another worker to reassign.")
		return
	selected_builder = clicked_citizen
	selected_house = null
	selected_school = null
	house_menu.visible = false
	school_menu.visible = false
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = true
	_show_selected_citizen_menu()
	_update_interface("Citizen selected. Choose a building in the lower-right menu.")

func _show_selected_citizen_menu() -> void:
	if selected_builder == null:
		return
	var assignment := "Auto" if selected_builder.manual_role.is_empty() else selected_builder.manual_role.capitalize()
	if not selected_builder.training_role.is_empty():
		assignment = "Training %s %d/10" % [selected_builder.training_role.capitalize(), selected_builder.training_days_completed]
	var home_label := "Tent" if selected_builder.home == tent else "House"
	var effect_label := "Meal buff" if selected_builder.buffs.has("canteen_meal") else ("Tent debuff" if selected_builder.debuffs.has("tent") else "None")
	build_menu_title.text = "%s  Sat: %d/%d%%  Food: %d%%\nHome: %s  Effect: %s  Task: %s\nBuild %.1f Wood %.1f Farm %.1f Dig %.1f" % [selected_builder.role_label(), roundi(selected_builder.satisfaction), roundi(selected_builder.get_satisfaction_cap()), roundi(selected_builder.hunger), home_label, effect_label, assignment, float(selected_builder.skills.construction), float(selected_builder.skills.forestry), float(selected_builder.skills.farming), float(selected_builder.skills.excavation)]
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
	is_first_person = true
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = false
	player_yaw = player_citizen.rotation.y
	player_pitch = 0.0
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
	if not player_citizen.is_player_controlled:
		if move_direction.is_zero_approx():
			camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
			camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
			_refresh_interaction_hint()
			return
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
	camera.global_position = player_citizen.global_position + Vector3(0.0, PLAYER_EYE_HEIGHT, 0.0)
	camera.rotation = Vector3(player_pitch, player_yaw, 0.0)
	_refresh_interaction_hint()

func _start_interaction() -> void:
	if not interaction_action.is_empty():
		return
	if _nearby_sawmill() and pocket_wood > 0:
		if _stored_resources() + pocket_wood > _warehouse_capacity():
			_update_interface("Warehouse is full. Build another warehouse before unloading wood.")
			return
		wood += pocket_wood
		var delivered := pocket_wood
		pocket_wood = 0
		_update_interface("Delivered %d wood to the sawmill." % delivered)
		_refresh_interaction_hint()
		return
	if _nearby_warehouse() and pocket_food > 0:
		if _stored_resources() + pocket_food > _warehouse_capacity():
			_update_interface("Warehouse is full. Build another warehouse before unloading food.")
			return
		food += pocket_food
		var delivered_food := pocket_food
		pocket_food = 0
		_update_interface("Delivered %d food to the warehouse." % delivered_food)
		_refresh_interaction_hint()
		return
	if _nearby_tree() or _nearby_farm():
		if pocket_wood + pocket_food >= POCKET_WOOD_CAPACITY:
			_update_interface("Pocket is full. Take wood to the sawmill or food to the warehouse.")
			_refresh_interaction_hint()
			return
		interaction_resource = "wood" if _nearby_tree() else "food"
		interaction_action = "harvesting"
		interaction_time = 0.0
		interaction_progress.visible = true
		interaction_hint_label.text = "Gathering %s..." % interaction_resource
		return
	if _nearby_warehouse():
		_update_interface("Food pocket is empty. Wood must go to a sawmill first.")
	else:
		_update_interface("Move closer to a tree, farm, warehouse or sawmill.")

func _dig_voxel_at_crosshair() -> void:
	if voxel_tool == null:
		return
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var hit := voxel_tool.raycast(origin, direction, DIG_REACH)
	if hit == null:
		return
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.do_sphere(hit.position, DIG_RADIUS)

func _update_interaction(delta: float) -> void:
	if interaction_action.is_empty():
		return
	if (interaction_resource == "wood" and not _nearby_tree()) or (interaction_resource == "food" and not _nearby_farm()):
		interaction_action = ""
		interaction_progress.visible = false
		_update_interface("Gathering cancelled: you moved away from the resource.")
		return
	interaction_time += delta
	interaction_progress.value = interaction_time / HARVEST_DURATION * 100.0
	interaction_hint_label.text = "Gathering %s: %d%%" % [interaction_resource, roundi(interaction_progress.value)]
	if interaction_time >= HARVEST_DURATION:
		interaction_action = ""
		if interaction_resource == "wood":
			pocket_wood += 1
		else:
			pocket_food += 1
		interaction_progress.visible = false
		_update_interface("Resource gathered. Wood: %d, food: %d, pocket: %d/%d." % [pocket_wood, pocket_food, pocket_wood + pocket_food, POCKET_WOOD_CAPACITY])
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

func _nearby_sawmill() -> bool:
	if player_citizen == null:
		return false
	for sawmill_position in sawmill_positions:
		if player_citizen.global_position.distance_to(sawmill_position) <= INTERACTION_RANGE:
			return true
	return false

func _nearby_farm() -> bool:
	if player_citizen == null:
		return false
	for farm_position in farm_positions:
		if player_citizen.global_position.distance_to(farm_position) <= INTERACTION_RANGE:
			return true
	return false

func _refresh_interaction_hint() -> void:
	if not is_first_person or not interaction_action.is_empty():
		return
	interaction_hint_label.visible = true
	if _nearby_sawmill() and pocket_wood > 0:
		interaction_hint_label.text = "LMB: unload wood at sawmill (%d wood)" % pocket_wood
	elif _nearby_warehouse() and pocket_food > 0:
		interaction_hint_label.text = "LMB: unload food at warehouse (%d food)" % pocket_food
	elif _nearby_tree():
		interaction_hint_label.text = "LMB: gather wood (%d/%d in pocket)" % [pocket_wood + pocket_food, POCKET_WOOD_CAPACITY]
	elif _nearby_farm():
		interaction_hint_label.text = "LMB: gather food (%d/%d in pocket)" % [pocket_wood + pocket_food, POCKET_WOOD_CAPACITY]
	else:
		interaction_hint_label.text = "LMB gathers resources. Wood goes to a sawmill; food goes to a warehouse."

func _terrain_point_at_screen_position(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position as Vector3

func _move_selection(world_position: Vector3) -> void:
	selected_world_position = _snapped_build_position(world_position) if not build_mode.is_empty() else world_position
	selected_cell = _placement_key(selected_world_position)
	selection_marker.position = selected_world_position + Vector3(0.0, 0.04, 0.0)
	if not build_mode.is_empty():
		var footprint: Vector2i = BuildingBlueprints.get_blueprint(build_mode).footprint
		(selection_marker.mesh as BoxMesh).size = Vector3(footprint.x, 0.04, footprint.y)
	if selected_builder != null and not build_mode.is_empty():
		selection_material.albedo_color = Color(0.25, 0.85, 0.37, 0.55) if _can_place(selected_world_position) else Color(0.9, 0.2, 0.18, 0.6)


func _place_building(world_position: Vector3) -> void:
	world_position = _snapped_build_position(world_position)
	if not _can_place(world_position):
		_update_interface("Construction is not allowed at this point.")
		return
	var cell := _placement_key(world_position)
	if not _can_pay_building_cost(build_mode):
		_update_interface("Not enough resources for this building.")
		return
	_pay_building_cost(build_mode)
	placed_buildings[cell] = build_mode
	building_positions.append(world_position)
	var blueprint := BuildingBlueprints.get_blueprint(build_mode)
	building_footprints.append({"center": world_position, "footprint": blueprint.footprint, "node": null})
	_rebuild_navigation_mesh()
	_create_construction_site(cell, build_mode, world_position)
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = false
	selected_builder = null
	_update_interface("Construction started. The progress bar shows completion.")

func _can_place(world_position: Vector3) -> bool:
	if build_mode.is_empty():
		return false
	var footprint: Vector2i = BuildingBlueprints.get_blueprint(build_mode).footprint
	return _is_footprint_level(world_position, footprint) and _is_footprint_clear(world_position, footprint)

func _can_pay_building_cost(building_type: String) -> bool:
	if building_type in ["recycling_factory", "metal_factory"]:
		return bricks >= 25
	if building_type == "city_hall":
		return bricks >= 35
	if building_type == "leisure_center":
		return bricks >= 30
	return wood >= _building_cost()

func _pay_building_cost(building_type: String) -> void:
	if building_type in ["recycling_factory", "metal_factory"]:
		bricks -= 25
	elif building_type == "city_hall":
		bricks -= 35
	elif building_type == "leisure_center":
		bricks -= 30
	else:
		wood -= _building_cost()

func _is_footprint_clear(world_position: Vector3, footprint: Vector2i) -> bool:
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for record in building_footprints:
		var other_center: Vector3 = record.center
		var other_footprint: Vector2i = record.footprint
		var other_half := Vector2(other_footprint.x, other_footprint.y) * 0.5
		if absf(world_position.x - other_center.x) < half.x + other_half.x + BUILDING_CLEARANCE_BLOCKS and absf(world_position.z - other_center.z) < half.y + other_half.y + BUILDING_CLEARANCE_BLOCKS:
			return false
	for tree_position in tree_positions:
		if absf(world_position.x - tree_position.x) < half.x + 0.5 and absf(world_position.z - tree_position.z) < half.y + 0.5:
			return false
	for site in dig_sites:
		if absf(world_position.x - site.node.global_position.x) < half.x + 1.0 and absf(world_position.z - site.node.global_position.z) < half.y + 1.0:
			return false
	return true

func _is_footprint_level(world_position: Vector3, footprint: Vector2i) -> bool:
	var heights: Array[float] = []
	var half_x := footprint.x * 0.5 - 0.25
	var half_z := footprint.y * 0.5 - 0.25
	for offset in [Vector2(-half_x, -half_z), Vector2(half_x, -half_z), Vector2(-half_x, half_z), Vector2(half_x, half_z), Vector2.ZERO]:
		var height := _terrain_height_at(world_position.x + offset.x, world_position.z + offset.y, world_position.y)
		if is_nan(height):
			return false
		heights.append(height)
	return heights.max() - heights.min() <= MAX_BUILD_SLOPE

func _terrain_height_at(x: float, z: float, near_y: float) -> float:
	var from := Vector3(x, near_y + 12.0, z)
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(x, near_y - 12.0, z))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else float(hit.position.y)

func _snapped_build_position(world_position: Vector3) -> Vector3:
	var snapped := Vector3(roundf(world_position.x), world_position.y, roundf(world_position.z))
	var ground_height := _terrain_height_at(snapped.x, snapped.z, world_position.y)
	if not is_nan(ground_height):
		snapped.y = ground_height
	return snapped

func _is_clear_of_objects(world_position: Vector3, minimum_distance: float) -> bool:
	for occupied_position in building_positions + tree_positions:
		if Vector2(occupied_position.x, occupied_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	for site in dig_sites:
		if Vector2(site.node.global_position.x, site.node.global_position.z).distance_to(Vector2(world_position.x, world_position.z)) < minimum_distance:
			return false
	return true

func _placement_key(world_position: Vector3) -> Vector2i:
	return Vector2i(roundi(world_position.x), roundi(world_position.z))

func _create_construction_site(cell: Vector2i, building_type: String, position_on_board: Vector3) -> void:
	var site := Node3D.new()
	site.position = position_on_board
	site.set_meta("building_type", building_type)
	add_child(site)
	var blueprint := BuildingBlueprints.get_blueprint(building_type)
	site.set_meta("footprint", blueprint.footprint)
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
	construction_sites.append({"cell": cell, "type": building_type, "position": position_on_board, "node": site, "fill": fill, "progress": 0.0, "blueprint": blueprint, "modules_built": 0})
	_update_workers()

func _update_construction(delta: float) -> void:
	for index in range(construction_sites.size() - 1, -1, -1):
		var site: Dictionary = construction_sites[index]
		var builder_power := _building_power(site.node)
		var progress: float = minf(1.0, site.progress + delta / CONSTRUCTION_DURATION * builder_power)
		if index == 0:
			status_label.text = "Building %s: %d builder(s), %.1fx speed." % [site.type, _builder_count(site.node), builder_power]
		site.progress = progress
		var modules: Array = site.blueprint.modules
		var target_module_count := mini(modules.size(), floori(progress * modules.size()))
		while site.modules_built < target_module_count:
			site.node.add_child(BuildingBlueprints.create_module(modules[site.modules_built]))
			site.modules_built += 1
		var fill: MeshInstance3D = site.fill
		fill.scale.x = maxf(0.01, progress)
		fill.position.x = -0.725 + 0.725 * progress
		construction_sites[index] = site
		if progress >= 1.0:
			if is_instance_valid(fill):
				fill.get_parent().remove_child(fill)
				fill.queue_free()
			for child in site.node.get_children():
				if child is MeshInstance3D and child != fill:
					child.queue_free()
			construction_sites.remove_at(index)
			_complete_building(site.cell, site.type, site.position, site.node, site.blueprint)

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	match building_type:
		"warehouse":
			warehouse_positions.append(position_on_board)
		"sawmill":
			sawmill_positions.append(position_on_board)
		"farm":
			farm_positions.append(position_on_board)
		"house":
			completed_house_count += 1
			building.set_meta("spawn_slots", 2)
			_add_building_selector(building, "house_selector", blueprint.footprint)
			_add_house_light(building)
		"canteen":
			canteen = building
			canteen_position = position_on_board
		"school":
			school_positions.append(position_on_board)
			_add_building_selector(building, "school_selector", blueprint.footprint)
		"park":
			park_positions.append(position_on_board)
		"brick_factory", "materials_factory", "recycling_factory", "metal_factory":
			building.set_meta("required_factory_workers", 3 if building_type in ["recycling_factory", "metal_factory"] else 1)
			factories.append(building)
			if building_type == "materials_factory":
				_add_building_selector(building, "materials_factory_selector", blueprint.footprint)
	for record in building_footprints:
		if record.center == position_on_board and record.node == null:
			record.node = building
			break
		_register_navigation_footprint(position_on_board, blueprint)
	_rebuild_navigation_mesh()
	_update_workers()
	var completion_message := "%s construction completed." % building_type.capitalize()
	if building_type in ["recycling_factory", "metal_factory"]:
		completion_message += " It requires 3 factory workers."
	_update_interface(completion_message)

func _add_building_selector(building: Node3D, group_name: String, footprint: Vector2i) -> void:
	var selector := Area3D.new()
	selector.add_to_group(group_name)
	selector.collision_layer = 4
	selector.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x + 0.25, 4.5, footprint.y + 0.25)
	collision.shape = shape
	collision.position.y = 2.0
	selector.add_child(collision)
	building.add_child(selector)

func _register_navigation_footprint(center: Vector3, blueprint: Dictionary) -> void:
	var footprint: Vector2i = blueprint.footprint
	var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
	var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
	for x in range(footprint.x):
		for z in range(footprint.y):
			house_cells[Vector2i(min_x + x, min_z + z)] = true

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
	selector.collision_layer = 4
	selector.collision_mask = 0
	var selector_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.5, 1.6)
	selector_shape.shape = shape
	selector_shape.position.y = 0.75
	selector.add_child(selector_shape)
	house.add_child(selector)
	_add_house_light(house)

func _add_house_light(house: Node3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffd58a")
	light.light_energy = 2.2
	light.omni_range = 5.5
	light.shadow_enabled = true
	light.position = Vector3(0.0, 2.0, 0.0)
	light.visible = false
	house.add_child(light)
	house_lights.append({"light": light})

func _create_canteen(position_on_board: Vector3) -> void:
	canteen = Node3D.new()
	canteen.position = position_on_board
	canteen_position = position_on_board
	add_child(canteen)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.7, 0.9, 1.65)
	base.mesh = base_mesh
	base.position.y = 0.45
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("d4a64f")
	base.material_override = wall_material
	canteen.add_child(base)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(1.95, 0.75, 1.9)
	roof.mesh = roof_mesh
	roof.position.y = 1.25
	roof.rotation_degrees.y = 90.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("a54e38")
	roof.material_override = roof_material
	canteen.add_child(roof)
	var sign := Label3D.new()
	sign.text = "CANTEEN"
	sign.position = Vector3(0, 1.3, -0.88)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 42
	canteen.add_child(sign)

func _create_school(position_on_board: Vector3) -> void:
	var school := Node3D.new()
	school.position = position_on_board
	add_child(school)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.8, 1.05, 1.7)
	base.mesh = base_mesh
	base.position.y = 0.52
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("8d7fc0")
	base.material_override = wall_material
	school.add_child(base)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(2.05, 0.76, 1.95)
	roof.mesh = roof_mesh
	roof.position.y = 1.4
	roof.rotation_degrees.y = 90.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("4f477b")
	roof.material_override = roof_material
	school.add_child(roof)
	var selector := Area3D.new()
	selector.add_to_group("school_selector")
	var selector_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.65, 1.8)
	selector_shape.shape = shape
	selector_shape.position.y = 0.82
	selector.add_child(selector_shape)
	school.add_child(selector)
	var sign := Label3D.new()
	sign.text = "SCHOOL"
	sign.position = Vector3(0, 1.35, -0.98)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 40
	school.add_child(sign)

func _tent_resident_count() -> int:
	var count := 0
	for citizen in citizens:
		if citizen.home == tent:
			count += 1
	return count

func _check_tent_dismantle() -> void:
	if not is_instance_valid(tent) or _tent_resident_count() > 0 or tent_dismantle_progress >= 0.0:
		return
	for citizen in citizens:
		if citizen.specialization == "builder":
			citizen.assign_construction(tent)
	tent_dismantle_progress = 0.0
	_update_interface("The tent is empty. Builders are walking over to dismantle it.")

func _update_tent_dismantle(delta: float) -> void:
	if tent_dismantle_progress < 0.0 or not is_instance_valid(tent):
		return
	var dismantlers := 0
	for citizen in citizens:
		if citizen.specialization == "builder" and citizen.is_building_site(tent):
			dismantlers += 1
	if dismantlers <= 0:
		return
	tent_dismantle_progress += delta * dismantlers
	if tent_dismantle_progress < 2.0:
		return
	building_positions.erase(tent.global_position)
	for index in range(building_footprints.size() - 1, -1, -1):
		if building_footprints[index].node == tent:
			building_footprints.remove_at(index)
	tent.queue_free()
	tent = null
	placed_buildings.erase(tent_cell)
	house_cells.erase(tent_cell)
	_rebuild_navigation_mesh()
	wood += 2
	tent_dismantle_progress = -1.0
	_update_workers()
	_update_interface("Builders dismantled the empty tent and recovered 2 wood.")
