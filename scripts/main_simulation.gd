extends Node3D

const SETTLEMENT_RULES = preload("res://scripts/domain/settlement_rules.gd")


const BOARD_CELLS := 48
const CELL_SIZE := BuildingBlueprints.BLOCK_SIZE
const BUILDING_CLEARANCE_BLOCKS := 3.0
const TREE_BUILD_CLEARANCE_BLOCKS := 1.0
const NAVIGATION_CLEARANCE_MARGIN := 1.0
const SERVICE_PAD_OFFSET := 1.0
const MAX_BUILD_SLOPE := 0.35
const BRICK_RESEARCH_DURATION := 20.0
const POPULATION := 4
const WAREHOUSE_CAPACITY := 50
const HOUSE_CAPACITY := 4
const TENT_CAPACITY := 4
const CONSTRUCTION_DURATION := 4.0
const PLAYER_SPEED := 4.2
const PLAYER_SPRINT_MULTIPLIER := 1.8
const PLAYER_JUMP_VELOCITY := 6.5
const PLAYER_GRAVITY := 18.0
const PLAYER_EYE_HEIGHT := 1.65
const HARVEST_DURATION := 1.25
const INTERACTION_RANGE := 4.5
const POCKET_WOOD_CAPACITY := 8
const SAWMILL_PROCESS_DURATION := 4.0
const SAWMILL_WORKER_DELIVERY_THRESHOLD := 4
const COURIER_LATE_SECONDS := 12.0
const DIG_RADIUS := 2.2
const DIG_REACH := 6.0
const NAVIGATION_AGENT_RADIUS := 0.38

var settlement := SettlementState.new()
var wood: int:
	get: return settlement.wood
	set(value): settlement.wood = value
var food: int:
	get: return settlement.food
	set(value): settlement.food = value
var soil: int:
	get: return settlement.soil
	set(value): settlement.soil = value
var clay: int:
	get: return settlement.clay
	set(value): settlement.clay = value
var boards: int:
	get: return settlement.boards
	set(value): settlement.boards = value
var bricks: int:
	get: return settlement.bricks
	set(value): settlement.bricks = value
var branches: int:
	get: return settlement.branches
	set(value): settlement.branches = value
var grass: int:
	get: return settlement.grass
	set(value): settlement.grass = value
var water: int:
	get: return settlement.water
	set(value): settlement.water = value
var money: int:
	get: return settlement.money
	set(value): settlement.money = value
var wellbeing: int:
	get: return settlement.wellbeing
	set(value): settlement.wellbeing = value
var clock := SimulationClock.new()
var game_minutes: float:
	get: return clock.minutes
	set(value): clock.minutes = value
const GAME_DAY_REAL_SECONDS := 300.0
const GAME_MINUTES_PER_SECOND := 1440.0 / GAME_DAY_REAL_SECONDS
var time_multiplier := 1.0
var runtime_seconds := 0.0
var random := RandomNumberGenerator.new()
var active_meal_hour := -1
var selected_cell := Vector2i(0, 0)
var selected_world_position := Vector3.ZERO
var build_mode := ""
var placed_buildings: Dictionary = {}
var house_cells: Dictionary = {}
var tree_cells: Dictionary = {}
var warehouse_positions: Array[Vector3] = []
var sawmill_positions: Array[Vector3] = []
var sawmill_stocks: Dictionary = {}
var tree_reservations: Dictionary = {}
var farm_positions: Array[Vector3] = []
var school_positions: Array[Vector3] = []
var park_positions: Array[Vector3] = []
var leisure_positions: Array[Vector3] = []
var factories: Array[Node3D] = []
var brick_construction_unlocked: bool:
	get: return settlement.brick_construction_unlocked
	set(value): settlement.brick_construction_unlocked = value
var brick_research_progress := -1.0
var brick_research_factory: Node3D
var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary = {}
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
var right_mouse_dragged := false
var construction_sites: Array[Dictionary] = []
var completed_house_count := 0
var player_citizen: Citizen
var is_first_person := false
var player_yaw := 0.0
var player_pitch := -8.0
var pocket_wood := 0
var pocket_food := 0
var pocket_boards := 0
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
var entrance_stone: Node3D
var tent_cell := Vector2i(0, 0)
var canteen: Node3D
var canteen_position := Vector3.ZERO
var canteen_food := 0
var pending_canteen_delivery := false
var pending_canteen_carrier: Citizen
var pending_canteen_delivery_amount := 0
var clock_label: Label
var tent_dismantle_progress := -1.0
var voxel_terrain: VoxelLodTerrain
var voxel_tool: VoxelTool
var navigation_region: NavigationRegion3D
var building_positions: Array[Vector3] = []
var building_footprints: Array[Dictionary] = []
var service_pockets: Array[Dictionary] = []
var selected_school: Node3D
var school_menu: Panel
var school_menu_title: Label
var materials_factory_menu: Panel
var materials_factory_menu_title: Label
var selected_materials_factory: Node3D
var campfire_node: Node3D = null
var selected_campfire: Node3D = null
var campfire_menu: Panel
var campfire_menu_title: Label
var campfire_requirements_label: Label
var campfire_advance_button: Button
var selected_market: Node3D = null
var market_menu: Panel
var market_menu_title: Label
var house_lights: Array[Dictionary] = []
var house_light_update_minute := -1
var entrance_lights: Array[OmniLight3D] = []
var build_category := ""
var build_buttons: Array[Button] = []
var role_buttons: Array[Button] = []
var workforce: WorkforceCoordinator
var sawmills: SawmillService
var construction: ConstructionService


func _ready() -> void:
	workforce = WorkforceCoordinator.new()
	workforce.configure(self)
	add_child(workforce)
	sawmills = SawmillService.new()
	sawmills.configure(self)
	construction = ConstructionService.new()
	construction.configure(self)
	_create_world()
	_create_interface()
	_create_forest()
	_create_entrance_stone()
	_create_citizens()
	
	# Starting resources to place first campfire and tents
	settlement.money = 100
	settlement.branches = 30
	settlement.grass = 20
	settlement.water = 15
	settlement.food = 15
	
	_update_interface("Four volunteers wait. Gather branches and grass, and build the Campfire to start management.")

func _process(delta: float) -> void:
	runtime_seconds += delta
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
	_update_sawmills(delta)
	_update_brick_research(delta)
	if not _is_night():
		_update_couriers()
	if selected_builder != null and build_menu.visible:
		_show_selected_citizen_menu()

func _update_workers() -> void:
	workforce.update_workers()

func _can_assign_goap_work(citizen: Citizen) -> bool:
	return workforce.can_assign_work(citizen)

func _assign_goap_work(citizen: Citizen, index: int) -> void:
	workforce.assign_work(citizen, index)

func _work_role_for(citizen: Citizen) -> String:
	return workforce.work_role_for(citizen)

func _factory_for_role(role: String) -> Node3D:
	return workforce.factory_for_role(role)


func _is_factory_worker_active(citizen: Citizen, factory: Node3D) -> bool:
	return citizen.factory == factory and citizen.specialization == "factory_worker" and citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]

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
	var elapsed_minutes := clock.advance(delta, GAME_MINUTES_PER_SECOND)
	clock_label.text = "%s  %02d:%02d  x%d" % ["Night" if clock.is_night() else "Day", clock.hour(), clock.minute(), int(time_multiplier)]
	for clock_minute in elapsed_minutes:
		_handle_clock_minute(clock_minute)

func _handle_clock_minute(clock_minute: int) -> void:
	var hour := clock_minute / 60
	var minute := clock_minute % 60
	if minute == 0 and (hour == 13 or hour == 19) and active_meal_hour != hour:
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
	if minute == 0 and hour == 8:
		active_meal_hour = -1
		_update_workers()
		_update_interface("Morning: workers left their homes for their assignments.")
	if minute == 0 and hour == 12:
		for citizen in citizens:
			citizen.finish_school_day()
		_update_workers()
	if minute == 0 and hour == 6:
		_apply_daily_settlement_rules()

func _apply_daily_settlement_rules() -> void:
	var population := citizens.size()
	if population == 0:
		return
	var housing := _total_housing_slots()
	var change := SETTLEMENT_RULES.daily_wellbeing_change(housing >= population, float(food) / population, float(water) / population, settlement.workday_hours, settlement.night_shifts_allowed)
	wellbeing = clampi(wellbeing + change, 0, 100)
	settlement.low_wellbeing_days = settlement.low_wellbeing_days + 1 if wellbeing < SettlementRules.LOW_WELLBEING else 0
	if SETTLEMENT_RULES.should_volunteer_leave(settlement.low_wellbeing_days) and not citizens.is_empty():
		var departing: Citizen = citizens.pop_back()
		departing.queue_free()
		settlement.low_wellbeing_days = 0
		_update_interface("A volunteer left after several days of poor living conditions.")

func _update_house_lights() -> void:
	var hour := int(game_minutes) / 60
	var minute := int(game_minutes) % 60
	var clock_minute := int(game_minutes)
	if house_light_update_minute == clock_minute:
		return
	house_light_update_minute = clock_minute
	var minute_of_day := hour * 60 + minute
	for record in house_lights:
		var light: OmniLight3D = record.light
		if not is_instance_valid(light):
			continue
		var off_minute: int = record.off_minute
		# A home is lit only after someone moves in. It turns on with evening
		# twilight and each household chooses one stable
		# switch-off time between 22:00 and 02:00, including after midnight.
		var house: Node3D = record.house
		var occupied := _house_has_residents(house)
		light.visible = occupied and (minute_of_day >= 17 * 60 and minute_of_day < off_minute if off_minute >= 17 * 60 else minute_of_day >= 17 * 60 or minute_of_day < off_minute)
	for light in entrance_lights:
		if is_instance_valid(light):
			light.visible = minute_of_day >= 17 * 60 or minute_of_day < 7 * 60

func _house_has_residents(house: Node3D) -> bool:
	if not is_instance_valid(house):
		return false
	for citizen in citizens:
		if citizen.home == house:
			return true
	return false

func _is_night() -> bool:
	return clock.is_night()

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
			citizen.request_goap_meal()
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
	citizen.finish_goap_meal()
	if not served:
		_update_interface("Canteen ran out of food. A worker missed their meal.")
	if not _is_night():
		_update_workers()

func _update_canteen_delivery() -> void:
	if pending_canteen_delivery:
		if not is_instance_valid(pending_canteen_carrier) or pending_canteen_carrier.state not in [Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY]:
			_cancel_canteen_delivery()
		else:
			return
	if not is_instance_valid(canteen) or warehouse_positions.is_empty() or food <= 0 or canteen_food >= 12:
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
	pending_canteen_carrier = carrier
	pending_canteen_delivery_amount = amount
	carrier.deliver_food_to_canteen(warehouse_positions[0], canteen_position, amount)

func _cancel_canteen_delivery() -> void:
	food += pending_canteen_delivery_amount
	pending_canteen_delivery = false
	pending_canteen_carrier = null
	pending_canteen_delivery_amount = 0
	_update_interface("Canteen delivery was interrupted; food returned to the warehouse.")

func _on_canteen_delivery_finished(worker: Citizen, amount: int) -> void:
	if not pending_canteen_delivery or worker != pending_canteen_carrier or amount != pending_canteen_delivery_amount:
		return
	canteen_food += amount
	pending_canteen_delivery = false
	pending_canteen_carrier = null
	pending_canteen_delivery_amount = 0
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
			courier.courier_worker = null
		var sawmill_position := _sawmill_with_boards()
		if sawmill_position != Vector3.INF:
			courier.assign_sawmill_pickup(sawmill_position, warehouse_positions[0])
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
	var storage_amount := amount
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
	elif resource_type == "boards":
		boards += amount
	elif resource_type == "branches":
		branches += amount
	else:
		wood += amount
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
		if citizen.factory != factory or citizen.state not in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
			continue
		has_worker = has_worker or citizen.specialization == "factory_worker"
		has_builder = has_builder or citizen.specialization == "builder"
		has_engineer = has_engineer or citizen.specialization == "engineer"
	return has_worker and has_builder and has_engineer

func _on_resource_ready(worker: Citizen, resource_type: String, amount: int) -> void:
	worker.register_pending_resource(resource_type, amount)

func _sawmill_key(position_on_board: Vector3) -> Vector2i:
	return _cell_from_position(position_on_board)

func _sawmill_stock(position_on_board: Vector3) -> Dictionary:
	return sawmills.stock_at(position_on_board, runtime_seconds)

func _store_sawmill_stock(position_on_board: Vector3, stock: Dictionary) -> void:
	sawmills.store(position_on_board, stock)

func _on_logs_delivered(worker: Citizen, sawmill_position: Vector3, amount: int) -> void:
	sawmills.accept_logs(worker, sawmill_position, amount, runtime_seconds)

func _update_sawmills(delta: float) -> void:
	sawmills.tick(delta, runtime_seconds)

func _decide_forestry_delivery(worker: Citizen, sawmill_position: Vector3) -> void:
	sawmills.decide_delivery(worker, sawmill_position, runtime_seconds)

func _on_sawmill_boards_collected(courier: Citizen, sawmill_position: Vector3) -> void:
	sawmills.collect_boards(courier, sawmill_position, runtime_seconds)

func _sawmill_with_boards() -> Vector3:
	return sawmills.position_with_boards(runtime_seconds)

func _reserve_closest_tree_for_sawmill(worker: Citizen, sawmill_position: Vector3) -> Vector3:
	for cell in tree_reservations.keys():
		var reserved_worker: Citizen = tree_reservations[cell]
		if not is_instance_valid(reserved_worker) or reserved_worker.state not in [Citizen.State.TO_TREE, Citizen.State.CHOPPING]:
			tree_reservations.erase(cell)
	var closest_tree := Vector3.INF
	var closest_distance := INF
	for tree_position in tree_positions:
		var cell := _cell_from_position(tree_position)
		if tree_reservations.has(cell):
			continue
		var distance := sawmill_position.distance_squared_to(tree_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_tree = tree_position
	if closest_tree != Vector3.INF:
		tree_reservations[_cell_from_position(closest_tree)] = worker
	return closest_tree

func _assign_next_forestry_tree(worker: Citizen) -> void:
	var tree_position := _reserve_closest_tree_for_sawmill(worker, worker.workplace_position)
	if tree_position == Vector3.INF:
		worker.idle()
		return
	worker.assign_next_forestry_tree(tree_position)

func _on_forestry_tree_requested(worker: Citizen) -> void:
	_assign_next_forestry_tree(worker)

func _on_excavation_cycle(worker: Citizen, site_node: Node3D, efficiency: float) -> void:
	for index in range(dig_sites.size()):
		var site: Dictionary = dig_sites[index]
		if site.node != site_node:
			continue
		site.depth += 1
		var delivery_pos: Vector3 = Vector3.ZERO
		if not warehouse_positions.is_empty():
			delivery_pos = warehouse_positions[0]
		elif is_instance_valid(campfire_node):
			delivery_pos = campfire_node.global_position
		else:
			delivery_pos = entrance_stone.global_position
			
		if site.depth <= site.soil_limit:
			worker.deliver_excavation("soil", delivery_pos)
			_update_interface("Digger is carrying soil to the warehouse.")
		elif site.depth <= site.clay_limit:
			worker.deliver_excavation("clay", delivery_pos)
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
	return BuildingCatalog.cost_for(build_mode)

func _stored_resources() -> int:
	return settlement.total_stored_resources()

func _warehouse_capacity() -> int:
	# Starting supplies are kept at the tent until the first warehouse is built.
	return maxi(WAREHOUSE_CAPACITY, warehouse_positions.size() * WAREHOUSE_CAPACITY)

func _total_housing_slots() -> int:
	var count := 0
	for type in placed_buildings.values():
		if type in ["tent", "dugout", "earth_house", "clay_house", "house"]:
			count += HOUSE_CAPACITY
	return count

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
	wood_label.text = "Era: %s  Money: %d  Branches: %d  Grass: %d  Water: %d\nFood: %d  Logs: %d  Timber: %d  Boards: %d  Bricks: %d\nStorage: %d/%d  Population: %d  Wellbeing: %d" % [_era_name(), money, branches, grass, water, food, settlement.logs, wood, boards, bricks, _stored_resources(), _warehouse_capacity(), citizens.size(), wellbeing]
	status_label.text = message
	if is_first_person:
		camera_hint_label.text = "R: leave citizen  WASD/arrows: move  Space: jump  Shift: sprint  Mouse: look  LMB: interact  RMB: dig"
	else:
		camera_hint_label.text = "Click a citizen, then R: first-person. Build freely on voxel terrain. Right drag: rotate  Middle drag: pan  Wheel: zoom"

func _era_name() -> String:
	return ["Tent", "Earth", "Clay", "Wood", "Brick"][settlement.era]


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
	navigation_region.use_edge_connections = false
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
	var vertex_indices: Dictionary = {}
	var half_cells := BOARD_CELLS / 2
	for x in range(-half_cells, half_cells):
		for z in range(-half_cells, half_cells):
			if _is_navigation_cell_blocked(Vector2i(x, z)):
				continue
			var corners := [Vector2i(x, z), Vector2i(x, z + 1), Vector2i(x + 1, z + 1), Vector2i(x + 1, z)]
			var polygon := PackedInt32Array()
			for corner in corners:
				if not vertex_indices.has(corner):
					vertex_indices[corner] = vertices.size()
					vertices.append(Vector3(corner.x, 0.0, corner.y))
				polygon.append(int(vertex_indices[corner]))
			polygons.append(polygon)
	navigation_mesh.vertices = vertices
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = navigation_mesh
	if is_inside_tree():
		NavigationServer3D.map_force_update(get_world_3d().navigation_map)

func _is_navigation_cell_blocked(cell: Vector2i) -> bool:
	# Trees occupy a navigation cell even though their visual meshes do not need
	# physics bodies. Workers targeting a tree stop at the nearest navmesh edge.
	if tree_cells.has(cell):
		return true
	for record in building_footprints:
		var center: Vector3 = record.center
		var footprint: Vector2i = record.footprint
		var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
		var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
		var margin := ceili(NAVIGATION_CLEARANCE_MARGIN)
		if cell.x >= min_x - margin and cell.x < min_x + footprint.x + margin and cell.y >= min_z - margin and cell.y < min_z + footprint.y + margin:
			if _is_service_pocket(cell, record.get("node")):
				continue
			return true
	return false

func _is_service_pocket(cell: Vector2i, building: Variant) -> bool:
	for pocket in service_pockets:
		if pocket.cell == cell and (building == null or pocket.node == building):
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
	var cells := [Vector2i(-16, -15), Vector2i(-15, -18), Vector2i(-18, -12), Vector2i(-12, -19), Vector2i(16, -15), Vector2i(15, -18), Vector2i(18, -12), Vector2i(12, -19), Vector2i(-16, 15), Vector2i(-15, 18), Vector2i(-18, 12), Vector2i(-12, 19), Vector2i(16, 15), Vector2i(15, 18), Vector2i(18, 12), Vector2i(12, 19), Vector2i(-20, -5), Vector2i(-20, 5), Vector2i(20, -5), Vector2i(20, 5), Vector2i(-5, -20), Vector2i(5, -20), Vector2i(-5, 20), Vector2i(5, 20)]
	for cell in cells:
		var tree_position := _cell_center(cell)
		tree_cells[cell] = true
		tree_positions.append(tree_position)
		_create_tree(tree_position)
	_rebuild_navigation_mesh()

func _create_tree(position_on_board: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = position_on_board
	tree.set_meta("remaining_wood", random.randi_range(4, 7))
	tree_nodes[_cell_from_position(position_on_board)] = tree
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
		crown_material.albedo_color = Color("2d633b").lightened(random.randf_range(-0.06, 0.08))
		crown.material_override = crown_material
		tree.add_child(crown)

func _create_entrance_stone() -> void:
	entrance_stone = Node3D.new()
	entrance_stone.position = _cell_center(Vector2i(-2, 1))
	add_child(entrance_stone)

func _create_starting_tent() -> void:
	tent = Node3D.new()
	tent.position = _cell_center(tent_cell)
	building_positions.append(tent.position)
	building_footprints.append({"center": tent.position, "footprint": Vector2i(3, 3), "node": tent})
	_rebuild_navigation_mesh()
	tent.set_meta("is_tent", true)
	placed_buildings[tent_cell] = "tent"
	_register_navigation_footprint(tent.position, {"footprint": Vector2i(3, 3)})
	add_child(tent)
	_register_service_entrance(tent, Vector2i(3, 3), true)
	_rebuild_navigation_mesh()
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
	var spawn_anchor: Vector3 = entrance_stone.global_position + Vector3(0.0, 0.0, 2.0)
	for index in range(POPULATION):
		var spawn_position := spawn_anchor + Vector3(-0.55 + (index % 2) * 1.1, 0.0, (index / 2) * 0.85)
		var terrain_height := _terrain_height_at(spawn_position.x, spawn_position.z, 0.0)
		if not is_nan(terrain_height):
			spawn_position.y = terrain_height + 0.08
		_add_citizen(spawn_position)

func _add_citizen(spawn_position: Vector3, primary_specialization := "") -> void:
	var citizen := Citizen.new()
	citizen.position = spawn_position
	add_child(citizen)
	citizen.setup_specialization(primary_specialization if not primary_specialization.is_empty() else ["builder", "forestry", "farming"][citizens.size() % 3])
	citizen.setup_navigation(_find_path_around_houses)
	citizen.resource_delivered.connect(_on_resource_delivered)
	citizen.excavation_cycle.connect(_on_excavation_cycle)
	citizen.resource_ready.connect(_on_resource_ready)
	citizen.tree_harvested.connect(_on_tree_harvested)
	citizen.logs_delivered.connect(_on_logs_delivered)
	citizen.forestry_tree_requested.connect(_on_forestry_tree_requested)
	citizen.sawmill_boards_collected.connect(_on_sawmill_boards_collected)
	citizen.meal_finished.connect(_on_meal_finished)
	citizen.canteen_delivery_finished.connect(_on_canteen_delivery_finished)
	citizen.factory_cycle.connect(_on_factory_cycle)
	citizens.append(citizen)
	citizen.setup_goap(self, citizens.size() - 1)


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
	var build_toggle_btn := Button.new()
	build_toggle_btn.text = "Construction Panel"
	build_toggle_btn.position = Vector2(20, 210)
	build_toggle_btn.size = Vector2(180, 36)
	build_toggle_btn.pressed.connect(_toggle_global_build_menu)
	ui.add_child(build_toggle_btn)
	
	_create_build_menu(ui)
	_create_house_menu(ui)
	_create_school_menu(ui)
	_create_materials_factory_menu(ui)
	_create_campfire_menu(ui)
	_create_market_menu(ui)

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


func _set_workday_hours(hours: int) -> void:
	settlement.workday_hours = hours
	_update_interface("Workday set to %d hours." % hours)

func _set_night_shifts(enabled: bool) -> void:
	settlement.night_shifts_allowed = enabled
	_update_interface("Night shifts %s." % ("allowed" if enabled else "disabled"))

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
	_add_build_category_button("Tent era", "tent", 290)
	_add_build_category_button("Earth era", "earth", 324)
	_add_build_category_button("Clay era", "clay", 358)
	_add_build_category_button("Wooden era", "wood", 392)
	_add_build_category_button("Brick era", "brick", 426)
	_add_build_category_back_button()
	
	_add_build_button("Campfire - branches", "campfire", 330, "tent")
	_add_build_button("Tent - branches + grass", "tent", 364, "tent")
	_add_build_button("Forager tent", "forager_tent", 398, "tent")
	_add_build_button("Craft tent", "craft_tent", 432, "tent")
	_add_build_button("Water store", "water_store", 466, "tent")
	_add_build_button("Simple store", "warehouse", 500, "tent")
	_add_build_button("Trade tent", "trade_tent", 534, "tent")
	
	_add_build_button("Dugout", "dugout", 330, "earth")
	_add_build_button("Earth house", "earth_house", 364, "earth")
	_add_build_button("Smithy", "smithy", 398, "earth")
	_add_build_button("Hide workshop", "hide_worker", 432, "earth")
	_add_build_button("Earth market", "earth_market", 466, "earth")
	
	_add_build_button("Clay house", "clay_house", 330, "clay")
	_add_build_button("Clay workshop", "clay_workshop", 364, "clay")
	_add_build_button("Clay market", "clay_market", 398, "clay")
	
	_add_build_button("Sawmill - logs + kit", "sawmill", 330, "wood")
	_add_build_button("Farm", "farm", 364, "wood")
	_add_build_button("Canteen", "canteen", 398, "wood")
	_add_build_button("Wood house", "house", 432, "wood")
	_add_build_button("School", "school", 466, "wood")
	_add_build_button("Park", "park", 500, "wood")
	_add_build_button("Wood market", "wood_market", 534, "wood")
	
	_add_build_button("Brick kiln", "brick_factory", 330, "brick")
	_add_build_button("Materials factory", "materials_factory", 364, "brick")
	_add_build_button("Brick market", "brick_market", 398, "brick")
	
	_refresh_build_menu()

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
		materials_factory_menu_title.text = "Materials factory\nNeeds factory worker, builder and engineer.\nResearch cost: %d bricks, %d boards." % [BuildingCatalog.research_cost("brick_construction", "bricks"), BuildingCatalog.research_cost("brick_construction", "boards")]

func _start_brick_research() -> void:
	if selected_materials_factory == null or brick_construction_unlocked or brick_research_progress >= 0.0:
		return
	if not _materials_factory_staffed(selected_materials_factory):
		_update_interface("Research needs a factory worker, builder and engineer assigned to this factory.")
		return
	var brick_cost := BuildingCatalog.research_cost("brick_construction", "bricks")
	var board_cost := BuildingCatalog.research_cost("brick_construction", "boards")
	if not settlement.can_afford_research("brick_construction"):
		_update_interface("Research needs %d bricks and %d boards." % [brick_cost, board_cost])
		return
	settlement.pay_for_research("brick_construction")
	brick_research_progress = 0.0
	brick_research_factory = selected_materials_factory
	_show_materials_factory_menu()
	_update_interface("Brick construction research started.")

func _update_brick_research(delta: float) -> void:
	if brick_research_progress < 0.0 or brick_construction_unlocked:
		return
	if not is_instance_valid(brick_research_factory) or not _materials_factory_staffed(brick_research_factory):
		if materials_factory_menu != null and materials_factory_menu.visible:
			_show_materials_factory_menu()
		return
	brick_research_progress = minf(1.0, brick_research_progress + delta / BRICK_RESEARCH_DURATION)
	if brick_research_progress >= 1.0:
		brick_construction_unlocked = true
		brick_research_progress = -1.0
		brick_research_factory = null
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
	var entrance: Vector3 = selected_house.get_meta("entrance_position", selected_house.global_position + Vector3(0.0, 0.0, 3.5))
	var spawned := HOUSE_CAPACITY - slots
	_add_citizen(entrance + Vector3((spawned % 2) * 0.7 - 0.35, 0.0, 0.45 + (spawned / 2) * 0.45), specialization)
	citizens.back().assign_home(selected_house)
	citizens.back().remove_debuff("tent")
	selected_house.set_meta("spawn_slots", slots - 1)
	_update_workers()
	if citizens.back().state == Citizen.State.IDLE:
		var recreation := park_positions + leisure_positions
		if not recreation.is_empty():
			citizens.back().go_to_park(recreation[spawned % recreation.size()])
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

func _add_build_button(title: String, building_type: String, y_position: float, category: String) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 30)
	button.pressed.connect(_select_build_mode.bind(building_type))
	button.set_meta("category", category)
	build_menu.add_child(button)
	build_buttons.append(button)

func _add_build_category_button(title: String, category: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 30)
	button.pressed.connect(_open_build_category.bind(category))
	build_menu.add_child(button)
	build_buttons.append(button)
	button.set_meta("category_button", category)

func _add_build_category_back_button() -> void:
	var button := Button.new()
	button.text = "Back to categories"
	button.position = Vector2(16, 290)
	button.size = Vector2(272, 30)
	button.pressed.connect(_open_build_category.bind(""))
	button.set_meta("category_back", true)
	build_menu.add_child(button)
	build_buttons.append(button)

func _open_build_category(category: String) -> void:
	build_category = category
	_refresh_build_menu()
	if build_category.is_empty():
		_show_selected_citizen_menu()

func _refresh_build_menu() -> void:
	for button in build_buttons:
		var category_button: String = button.get_meta("category_button", "")
		if button.get_meta("category_back", false):
			button.visible = not build_category.is_empty()
		else:
			button.visible = build_category.is_empty() and not category_button.is_empty() or not build_category.is_empty() and button.get_meta("category", "") == build_category
	for button in role_buttons:
		button.visible = build_category.is_empty()
	if build_menu_title != null and not build_category.is_empty():
		build_menu_title.text = "%s buildings\nChoose a building to place." % build_category.capitalize()

func _add_role_button(title: String, role: String, y_position: float) -> void:
	var button := Button.new()
	button.text = title
	button.position = Vector2(16, y_position)
	button.size = Vector2(272, 28)
	button.pressed.connect(_set_manual_role.bind(role))
	build_menu.add_child(button)
	role_buttons.append(button)

func _set_manual_role(role: String) -> void:
	if selected_builder == null:
		return
	selected_builder.idle()
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
	var site := {"cell": cell, "node": site_node, "pit": pit, "soil_limit": random.randi_range(3, 6), "clay_limit": random.randi_range(7, 12), "depth": 0}
	dig_sites.append(site)
	dig_cells[cell] = true
	return site

func _select_build_mode(next_mode: String) -> void:
	if BuildingCatalog.era_for(next_mode) > settlement.era:
		_update_interface("This building belongs to a later era. Complete the current settlement requirements first.")
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

func _close_context_menus() -> void:
	build_mode = ""
	dig_mode = false
	selection_marker.visible = false
	is_rotating_camera = false
	house_menu.visible = false
	school_menu.visible = false
	materials_factory_menu.visible = false
	build_menu.visible = false
	campfire_menu.visible = false
	market_menu.visible = false
	selected_house = null
	selected_school = null
	selected_materials_factory = null
	selected_campfire = null
	selected_market = null
	selected_builder = null
	build_category = ""
	_refresh_build_menu()


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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_rotating_camera = true
			right_mouse_dragged = false
		else:
			is_rotating_camera = false
			if not right_mouse_dragged:
				_close_context_menus()
	elif event is InputEventMouseMotion:
		if is_rotating_camera:
			if event.relative.length_squared() > 0.0:
				right_mouse_dragged = true
			_rotate_camera(event.relative)
		elif is_panning_camera:
			_pan_camera(event.relative)
		elif not build_mode.is_empty() or (selected_builder != null and dig_mode):
			var terrain_point: Variant = _terrain_point_at_screen_position(event.position)
			if terrain_point != null:
				_move_selection(terrain_point)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_builder != null and dig_mode:
			var dig_point: Variant = _terrain_point_at_screen_position(event.position)
			if dig_point != null:
				_place_dig_site(dig_point)
		elif not build_mode.is_empty():
			var build_point: Variant = _terrain_point_at_screen_position(event.position)
			if build_point != null:
				_place_building(build_point)
		else:
			_select_citizen_at(event.position)

func _select_citizen_at(screen_position: Vector2) -> void:
	var visible_citizen := _citizen_at_screen_position(screen_position)
	if visible_citizen != null:
		_select_citizen(visible_citizen)
		return
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 4
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if hit.collider.is_in_group("campfire_selector"):
		selected_campfire = hit.collider.get_parent() as Node3D
		_show_campfire_menu()
		return
	if hit.collider.is_in_group("market_selector"):
		selected_market = hit.collider.get_parent() as Node3D
		_show_market_menu()
		return
	if hit.collider.is_in_group("house_selector"):
		selected_house = hit.collider.get_parent() as Node3D
		selected_builder = null
		build_menu.visible = false
		if tent != null and selected_house == tent:
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
	_select_citizen(hit.collider.get_parent() as Citizen)

func _citizen_at_screen_position(screen_position: Vector2) -> Citizen:
	var closest: Citizen
	var closest_distance := 22.0
	for citizen in citizens:
		if not is_instance_valid(citizen) or camera.is_position_behind(citizen.global_position):
			continue
		var distance := camera.unproject_position(citizen.global_position + Vector3.UP * 0.9).distance_to(screen_position)
		if distance < closest_distance:
			closest = citizen
			closest_distance = distance
	return closest

func _select_citizen(clicked_citizen: Citizen) -> void:
	if clicked_citizen == null:
		return
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
	build_category = ""
	selection_marker.visible = false
	build_menu.visible = true
	_refresh_build_menu()
	_show_selected_citizen_menu()
	_update_interface("Citizen selected. Choose a building in the lower-right menu.")

func _show_selected_citizen_menu() -> void:
	if selected_builder == null:
		build_menu_title.text = "Construction Panel\nChoose an era category below."
		build_menu_title.add_theme_color_override("font_color", Color("ffffff"))
		return
	var assignment := "Auto" if selected_builder.manual_role.is_empty() else selected_builder.manual_role.capitalize()
	if not selected_builder.training_role.is_empty():
		assignment = "Training %s %d/10" % [selected_builder.training_role.capitalize(), selected_builder.training_days_completed]
	var home_label := "Tent" if selected_builder.home == tent else "House"
	var effect_label := "Meal buff" if selected_builder.buffs.has("canteen_meal") else ("Tent debuff" if selected_builder.debuffs.has("tent") else "None")
	if build_category.is_empty():
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
	# Watching a citizen must not cancel their current AI task. Manual control
	# starts only after the player presses a movement key.
	player_citizen.set_player_controlled(false)
	is_first_person = true
	build_mode = ""
	selection_marker.visible = false
	build_menu.visible = false
	player_yaw = player_citizen.rotation.y
	player_pitch = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_interface("First-person control enabled. Gather resources, unload logs for processing, and deliver boards to storage.")

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
		var sawmill_position := _nearby_sawmill_position()
		var stock := _sawmill_stock(sawmill_position)
		stock.logs = int(stock.logs) + pocket_wood
		_store_sawmill_stock(sawmill_position, stock)
		var unloaded := pocket_wood
		pocket_wood = 0
		_update_interface("Unloaded %d logs at the sawmill. Boards will be ready after processing." % unloaded)
		_refresh_interaction_hint()
		return
	if _nearby_sawmill():
		var pickup_sawmill_position := _nearby_sawmill_position()
		var pickup_stock := _sawmill_stock(pickup_sawmill_position)
		var free_capacity := POCKET_WOOD_CAPACITY - pocket_wood - pocket_food - pocket_boards
		var amount := mini(int(pickup_stock.boards), free_capacity)
		if amount > 0:
			pickup_stock.boards = int(pickup_stock.boards) - amount
			_store_sawmill_stock(pickup_sawmill_position, pickup_stock)
			pocket_boards += amount
			_update_interface("Picked up %d boards from the sawmill." % amount)
		else:
			_update_interface("The sawmill has no ready boards, or your pocket is full.")
		_refresh_interaction_hint()
		return
	if _nearby_warehouse() and (pocket_food > 0 or pocket_boards > 0):
		var delivery := pocket_food + pocket_boards
		if _stored_resources() + delivery > _warehouse_capacity():
			_update_interface("Warehouse is full. Build another warehouse before unloading food.")
			return
		food += pocket_food
		boards += pocket_boards
		var delivered_food := pocket_food
		var delivered_boards := pocket_boards
		pocket_food = 0
		pocket_boards = 0
		_update_interface("Delivered %d food and %d boards to the warehouse." % [delivered_food, delivered_boards])
		_refresh_interaction_hint()
		return
	if _nearby_tree() or _nearby_farm():
		if pocket_wood + pocket_food + pocket_boards >= POCKET_WOOD_CAPACITY:
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
		_consume_tree_near_player() if interaction_resource == "wood" else null
		_update_interface("Resource gathered. Wood: %d, food: %d, boards: %d, pocket: %d/%d." % [pocket_wood, pocket_food, pocket_boards, pocket_wood + pocket_food + pocket_boards, POCKET_WOOD_CAPACITY])
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
	return _nearby_sawmill_position() != Vector3.INF

func _nearby_sawmill_position() -> Vector3:
	if player_citizen == null:
		return Vector3.INF
	for sawmill_position in sawmill_positions:
		if player_citizen.global_position.distance_to(sawmill_position) <= INTERACTION_RANGE:
			return sawmill_position
	return Vector3.INF

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
	elif _nearby_sawmill() and int(_sawmill_stock(_nearby_sawmill_position()).boards) > 0:
		interaction_hint_label.text = "LMB: take ready boards from sawmill"
	elif _nearby_warehouse() and (pocket_food > 0 or pocket_boards > 0):
		interaction_hint_label.text = "LMB: unload food %d / boards %d at warehouse" % [pocket_food, pocket_boards]
	elif _nearby_tree():
		interaction_hint_label.text = "LMB: gather wood (%d/%d in pocket)" % [pocket_wood + pocket_food + pocket_boards, POCKET_WOOD_CAPACITY]
	elif _nearby_farm():
		interaction_hint_label.text = "LMB: gather food (%d/%d in pocket)" % [pocket_wood + pocket_food + pocket_boards, POCKET_WOOD_CAPACITY]
	else:
		interaction_hint_label.text = "LMB: gather. Logs go to sawmill, boards and food go to warehouse."

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
	return settlement.can_afford_building(building_type)

func _pay_building_cost(building_type: String) -> void:
	settlement.pay_for_building(building_type)

func _is_footprint_clear(world_position: Vector3, footprint: Vector2i) -> bool:
	var half := Vector2(footprint.x, footprint.y) * 0.5
	for record in building_footprints:
		var other_center: Vector3 = record.center
		var other_footprint: Vector2i = record.footprint
		var other_half := Vector2(other_footprint.x, other_footprint.y) * 0.5
		if absf(world_position.x - other_center.x) < half.x + other_half.x + BUILDING_CLEARANCE_BLOCKS and absf(world_position.z - other_center.z) < half.y + other_half.y + BUILDING_CLEARANCE_BLOCKS:
			return false
	for tree_position in tree_positions:
		if absf(world_position.x - tree_position.x) < half.x + 0.5 + TREE_BUILD_CLEARANCE_BLOCKS and absf(world_position.z - tree_position.z) < half.y + 0.5 + TREE_BUILD_CLEARANCE_BLOCKS:
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
	construction.start_site(cell, building_type, position_on_board)

func _update_construction(delta: float) -> void:
	construction.tick(delta)

func _complete_building(cell: Vector2i, building_type: String, position_on_board: Vector3, building: Node3D, blueprint: Dictionary) -> void:
	_register_service_entrance(building, blueprint.footprint, false, building_type not in ["farm", "park"])
	var service_position: Vector3 = building.get_meta("service_position")
	match building_type:
		"warehouse":
			warehouse_positions.append(service_position)
		"sawmill":
			sawmill_positions.append(service_position)
			_sawmill_stock(service_position)
		"farm":
			farm_positions.append(service_position)
		"campfire":
			campfire_node = building
			_add_building_selector(building, "campfire_selector", blueprint.footprint)
			var fire_light := OmniLight3D.new()
			fire_light.position = Vector3(0.0, 0.5, 0.0)
			fire_light.light_color = Color("ff9d3b")
			fire_light.light_energy = 2.5
			fire_light.omni_range = 8.0
			building.add_child(fire_light)
		"tent", "dugout", "earth_house", "clay_house", "house":
			if building_type == "house":
				completed_house_count += 1
			building.set_meta("spawn_slots", HOUSE_CAPACITY)
			building.set_meta("entrance_position", service_position)
			_add_building_selector(building, "house_selector", blueprint.footprint)
			_add_house_light(building)
			if building_type == "tent":
				building.set_meta("is_tent", true)
		"trade_tent", "earth_market", "clay_market", "wood_market", "brick_market":
			_add_building_selector(building, "market_selector", blueprint.footprint)
		"canteen":
			canteen = building
			canteen_position = service_position
		"school":
			school_positions.append(service_position)
			_add_building_selector(building, "school_selector", blueprint.footprint)
		"park":
			park_positions.append(service_position)
		"leisure_center":
			leisure_positions.append(service_position)
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

func _register_service_entrance(building: Node3D, footprint: Vector2i, home_entrance := false, show_marker := true) -> void:
	var service_position := building.global_position + Vector3(0.0, 0.0, footprint.y * 0.5 + SERVICE_PAD_OFFSET)
	service_position.y = building.global_position.y
	building.set_meta("service_position", service_position)
	if home_entrance:
		building.set_meta("entrance_position", service_position)
	service_pockets.append({"cell": _cell_from_position(service_position), "node": building})
	if show_marker:
		_add_service_entrance_marker(building, footprint)

func _add_service_entrance_marker(building: Node3D, footprint: Vector2i) -> void:
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.72, 1.45, 0.12)
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 0.73, footprint.y * 0.5 + 0.08)
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("17191c")
	marker_material.roughness = 0.95
	marker.material_override = marker_material
	building.add_child(marker)
	var sign := Label3D.new()
	sign.text = "STAFF"
	sign.position = Vector3(0.0, 1.72, footprint.y * 0.5 + 0.16)
	sign.font_size = 24
	sign.modulate = Color("e5c86b")
	building.add_child(sign)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd58a")
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.shadow_enabled = true
	light.position = Vector3(0.0, 2.2, footprint.y * 0.5 + 0.45)
	light.visible = false
	building.add_child(light)
	entrance_lights.append(light)


func _unregister_navigation_footprint(center: Vector3, footprint: Vector2i) -> void:
	var min_x := roundi(center.x - (footprint.x - 1) * 0.5)
	var min_z := roundi(center.z - (footprint.y - 1) * 0.5)
	for x in range(footprint.x):
		for z in range(footprint.y):
			house_cells.erase(Vector2i(min_x + x, min_z + z))
	for index in range(service_pockets.size() - 1, -1, -1):
		var pocket: Dictionary = service_pockets[index]
		if is_instance_valid(pocket.node) and pocket.node.global_position == center:
			service_pockets.remove_at(index)

func _add_house_light(house: Node3D) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color("ffd58a")
	light.light_energy = 2.2
	light.omni_range = 5.5
	light.shadow_enabled = true
	var footprint: Vector2i = house.get_meta("footprint", Vector2i(5, 5))
	light.position = Vector3(0.0, 2.0, footprint.y * 0.5 + 0.35)
	light.visible = false
	house.add_child(light)
	house_lights.append({"light": light, "house": house, "off_minute": random.randi_range(22 * 60, 26 * 60) % (24 * 60)})

func _on_tree_harvested(worker: Citizen, position_on_board: Vector3) -> void:
	tree_reservations.erase(_cell_from_position(position_on_board))
	_fell_tree_at(position_on_board)

func _consume_tree_near_player() -> void:
	if player_citizen == null:
		return
	for position_on_board in tree_positions:
		if player_citizen.global_position.distance_to(position_on_board) <= INTERACTION_RANGE:
			var tree: Node3D = tree_nodes.get(_cell_from_position(position_on_board))
			if is_instance_valid(tree) and not bool(tree.get_meta("felled", false)):
				branches += 1
				_update_interface("Collected branches. The tree remains standing.")
				return

func _fell_tree_at(position_on_board: Vector3) -> void:
	var cell := _cell_from_position(position_on_board)
	var tree: Node3D = tree_nodes.get(cell)
	if not is_instance_valid(tree):
		return
	if bool(tree.get_meta("felled", false)):
		return
	tree.set_meta("felled", true)
	tree.rotation_degrees.z = 82.0
	settlement.logs += 1
	settlement.branches += 3
	_update_interface("A tree was felled. Its fallen trunk awaits manual processing; the living tree is no longer removed by branch gathering.")

func _tent_resident_count() -> int:
	if not is_instance_valid(tent):
		return 0
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
	_unregister_navigation_footprint(tent.global_position, Vector2i(3, 3))
	tent.queue_free()
	tent = null
	placed_buildings.erase(tent_cell)
	_rebuild_navigation_mesh()
	wood += 2
	tent_dismantle_progress = -1.0
	_update_workers()
	_update_interface("Builders dismantled the empty tent and recovered 2 wood.")


func _toggle_global_build_menu() -> void:
	_close_context_menus()
	build_menu.visible = not build_menu.visible
	if build_menu.visible:
		build_category = ""
		_refresh_build_menu()
		_show_selected_citizen_menu()


func _create_campfire_menu(ui: CanvasLayer) -> void:
	campfire_menu = Panel.new()
	campfire_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	campfire_menu.offset_left = -324.0
	campfire_menu.offset_top = -600.0
	campfire_menu.offset_right = -20.0
	campfire_menu.offset_bottom = -20.0
	campfire_menu.visible = false
	ui.add_child(campfire_menu)
	
	campfire_menu_title = Label.new()
	campfire_menu_title.position = Vector2(16, 14)
	campfire_menu_title.size = Vector2(272, 40)
	campfire_menu_title.add_theme_font_size_override("font_size", 17)
	campfire_menu.add_child(campfire_menu_title)
	
	campfire_requirements_label = Label.new()
	campfire_requirements_label.position = Vector2(16, 60)
	campfire_requirements_label.size = Vector2(272, 220)
	campfire_requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	campfire_requirements_label.add_theme_font_size_override("font_size", 13)
	campfire_menu.add_child(campfire_requirements_label)
	
	campfire_advance_button = Button.new()
	campfire_advance_button.text = "Advance Era"
	campfire_advance_button.position = Vector2(16, 290)
	campfire_advance_button.size = Vector2(272, 36)
	campfire_advance_button.pressed.connect(_on_campfire_advance_pressed)
	campfire_menu.add_child(campfire_advance_button)

	var labour_label := Label.new()
	labour_label.text = "Labor Policy:"
	labour_label.position = Vector2(16, 335)
	campfire_menu.add_child(labour_label)
	
	var labour_controls := HBoxContainer.new()
	labour_controls.position = Vector2(16, 360)
	campfire_menu.add_child(labour_controls)
	for hours in [6, 8, 10]:
		var day_button := Button.new()
		day_button.text = "%dh" % hours
		day_button.tooltip_text = "Set workday duration"
		day_button.pressed.connect(_set_workday_hours.bind(hours))
		labour_controls.add_child(day_button)
	var night_button := CheckButton.new()
	night_button.text = "Night shifts"
	night_button.tooltip_text = "Night shifts increase output and reduce wellbeing"
	night_button.toggled.connect(_set_night_shifts)
	labour_controls.add_child(night_button)
	
	var close_btn := Button.new()
	close_btn.text = "Close Menu"
	close_btn.position = Vector2(16, 405)
	close_btn.size = Vector2(272, 28)
	close_btn.pressed.connect(_close_context_menus)
	campfire_menu.add_child(close_btn)


func _show_campfire_menu() -> void:
	_close_context_menus()
	selected_builder = null
	campfire_menu.visible = true
	_refresh_campfire_menu()


func _refresh_campfire_menu() -> void:
	if selected_campfire == null:
		return
	var era_str := _era_name()
	campfire_menu_title.text = "Campfire (Era: %s)" % era_str
	
	var req_text := ""
	var next_era := SettlementState.Era.TENT
	var can_advance := false
	
	var housing_slots := _total_housing_slots()
	
	match settlement.era:
		SettlementState.Era.TENT:
			next_era = SettlementState.Era.EARTH
			var has_cf := settlement.has_building("campfire")
			var has_mkt := settlement.has_building("trade_tent")
			var has_ct := settlement.has_building("craft_tent")
			var pop_ok := housing_slots >= citizens.size()
			var food_ok := food >= citizens.size()
			var water_ok := water >= citizens.size()
			var trade_ok := settlement.trade_sales >= 1
			var tools_ok := settlement._has_tools(["axe", "hand_saw", "shovel", "bucket"])
			
			req_text = "Requirements for Earth Era:\n"
			req_text += "- Campfire built: %s\n" % ("Yes" if has_cf else "No")
			req_text += "- Trade tent built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Craft tent built: %s\n" % ("Yes" if has_ct else "No")
			req_text += "- Housing slots (needs %d): %d (%s)\n" % [citizens.size(), housing_slots, "OK" if pop_ok else "Need more"]
			req_text += "- Food (needs %d): %d (%s)\n" % [citizens.size(), food, "OK" if food_ok else "Need more"]
			req_text += "- Water (needs %d): %d (%s)\n" % [citizens.size(), water, "OK" if water_ok else "Need more"]
			req_text += "- Trade sales (needs 1): %d (%s)\n" % [settlement.trade_sales, "OK" if trade_ok else "No sales"]
			req_text += "- Tools (axe, saw, shovel, bucket): %s\n" % ("OK" if tools_ok else "Missing")
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
		
		SettlementState.Era.EARTH:
			next_era = SettlementState.Era.CLAY
			var has_smithy := settlement.has_building("smithy")
			var has_mkt := settlement.has_building("earth_market")
			var pop_ok := housing_slots >= citizens.size()
			var clay_ok := settlement.clay >= 5
			var money_ok := settlement.money >= 5
			var trade_ok := settlement.trade_sales >= 3
			var shovel_ok := settlement._has_tools(["shovel"])
			
			req_text = "Requirements for Clay Era:\n"
			req_text += "- Smithy built: %s\n" % ("Yes" if has_smithy else "No")
			req_text += "- Earth market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Housing slots (needs %d): %d (%s)\n" % [citizens.size(), housing_slots, "OK" if pop_ok else "Need more"]
			req_text += "- Clay (needs 5): %d (%s)\n" % [settlement.clay, "OK" if clay_ok else "Need more"]
			req_text += "- Money (needs 5): %d (%s)\n" % [settlement.money, "OK" if money_ok else "Need more"]
			req_text += "- Trade sales (needs 3): %d (%s)\n" % [settlement.trade_sales, "OK" if trade_ok else "Need more"]
			req_text += "- Tool Shovel owned: %s\n" % ("Yes" if shovel_ok else "No")
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
			
		SettlementState.Era.CLAY:
			next_era = SettlementState.Era.WOOD
			var has_mkt := settlement.has_building("clay_market")
			var water_ok := water >= citizens.size()
			var logs_ok := settlement.logs >= 10
			var money_ok := settlement.money >= 10
			var kit_ok := bool(settlement.tools.sawmill_kit)
			var has_sawmill := settlement.has_building("sawmill")
			
			req_text = "Requirements for Wood Era:\n"
			req_text += "- Clay market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Sawmill built: %s\n" % ("Yes" if has_sawmill else "No")
			req_text += "- Water (needs %d): %d (%s)\n" % [citizens.size(), water, "OK" if water_ok else "Need more"]
			req_text += "- Logs (needs 10): %d (%s)\n" % [settlement.logs, "OK" if logs_ok else "Need more"]
			req_text += "- Money (needs 10): %d (%s)\n" % [settlement.money, "OK" if money_ok else "Need more"]
			req_text += "- Sawmill kit owned: %s\n" % ("Yes" if kit_ok else "No")
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
			
		SettlementState.Era.WOOD:
			next_era = SettlementState.Era.BRICK
			var has_bf := settlement.has_building("brick_factory")
			var clay_ok := settlement.clay >= 20
			var has_mkt := settlement.has_building("wood_market")
			
			req_text = "Requirements for Brick Era:\n"
			req_text += "- Brick kiln built: %s\n" % ("Yes" if has_bf else "No")
			req_text += "- Wood market built: %s\n" % ("Yes" if has_mkt else "No")
			req_text += "- Clay (needs 20): %d (%s)\n" % [settlement.clay, "OK" if clay_ok else "Need more"]
			can_advance = settlement.can_advance_to(next_era, citizens.size(), housing_slots)
			
		SettlementState.Era.BRICK:
			req_text = "Maximum era reached! Your settlement is fully advanced."
			can_advance = false
			
	campfire_requirements_label.text = req_text
	campfire_advance_button.disabled = not can_advance


func _on_campfire_advance_pressed() -> void:
	if selected_campfire == null:
		return
	var housing_slots := _total_housing_slots()
	var next_era := SettlementState.Era.TENT
	match settlement.era:
		SettlementState.Era.TENT: next_era = SettlementState.Era.EARTH
		SettlementState.Era.EARTH: next_era = SettlementState.Era.CLAY
		SettlementState.Era.CLAY: next_era = SettlementState.Era.WOOD
		SettlementState.Era.WOOD: next_era = SettlementState.Era.BRICK
	
	if settlement.advance_era(next_era, citizens.size(), housing_slots):
		_update_interface("Advanced to the %s Era! New buildings unlocked." % _era_name())
		_refresh_campfire_menu()
		_refresh_build_menu()
	else:
		_update_interface("Failed to advance era. Double-check requirements.")


func _create_market_menu(ui: CanvasLayer) -> void:
	market_menu = Panel.new()
	market_menu.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	market_menu.offset_left = -324.0
	market_menu.offset_top = -650.0
	market_menu.offset_right = -20.0
	market_menu.offset_bottom = -20.0
	market_menu.visible = false
	ui.add_child(market_menu)
	
	market_menu_title = Label.new()
	market_menu_title.position = Vector2(16, 14)
	market_menu_title.size = Vector2(272, 70)
	market_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_menu.add_child(market_menu_title)


func _show_market_menu() -> void:
	_close_context_menus()
	selected_builder = null
	market_menu.visible = true
	_refresh_market_menu()


func _refresh_market_menu() -> void:
	if selected_market == null:
		return
	var market_type: String = selected_market.get_meta("building_type", "trade_tent")
	market_menu_title.text = "%s Menu\nMoney: %d coins\nTrade Sales: %d" % [market_type.capitalize().replace("_", " "), settlement.money, settlement.trade_sales]
	
	# Clear previous buttons except title
	for child in market_menu.get_children():
		if child != market_menu_title:
			child.queue_free()
			
	var y_offset := 80.0
	
	var sell_items := []
	var buy_items := []
	
	sell_items.append(["branches", 1])
	sell_items.append(["grass", 1])
	buy_items.append(["axe", 15])
	buy_items.append(["hand_saw", 15])
	
	if market_type in ["earth_market", "clay_market", "wood_market", "brick_market"]:
		sell_items.append(["soil", 1])
		buy_items.append(["shovel", 15])
		buy_items.append(["bucket", 15])
		
	if market_type in ["clay_market", "wood_market", "brick_market"]:
		sell_items.append(["clay", 2])
		
	if market_type in ["wood_market", "brick_market"]:
		sell_items.append(["wood", 2])
		sell_items.append(["boards", 3])
		buy_items.append(["sawmill_kit", 30])
		
	if market_type == "brick_market":
		sell_items.append(["bricks", 4])
		
	for item in sell_items:
		var res: String = item[0]
		var price: int = item[1]
		var btn := Button.new()
		btn.text = "Sell 5 %s (+%d Coins)" % [res, price * 5]
		btn.position = Vector2(16, y_offset)
		btn.size = Vector2(272, 28)
		btn.pressed.connect(_sell_resource.bind(res, 5, price))
		market_menu.add_child(btn)
		y_offset += 32.0
		
	y_offset += 10.0
	
	for item in buy_items:
		var tool_name: String = item[0]
		var price: int = item[1]
		var btn := Button.new()
		btn.text = "Buy %s (%d Coins)" % [tool_name.replace("_", " "), price]
		btn.position = Vector2(16, y_offset)
		btn.size = Vector2(272, 28)
		btn.pressed.connect(_buy_tool.bind(tool_name, price))
		market_menu.add_child(btn)
		y_offset += 32.0

	y_offset += 10.0
	
	var close_btn := Button.new()
	close_btn.text = "Close Menu"
	close_btn.position = Vector2(16, y_offset)
	close_btn.size = Vector2(272, 28)
	close_btn.pressed.connect(_close_context_menus)
	market_menu.add_child(close_btn)


func _sell_resource(resource_type: String, quantity: int, unit_price: int) -> void:
	if selected_market == null:
		return
	if settlement.sell(resource_type, quantity, unit_price):
		_update_interface("Sold %d %s for %d coins." % [quantity, resource_type, quantity * unit_price])
		_refresh_market_menu()
	else:
		_update_interface("Not enough %s to sell." % resource_type)


func _buy_tool(tool_id: String, price: int) -> void:
	if selected_market == null:
		return
	if settlement.buy_tool(tool_id, price):
		_update_interface("Bought %s for %d coins." % [tool_id.replace("_", " "), price])
		_refresh_market_menu()
	else:
		_update_interface("Cannot buy %s. Check money or check if already owned." % tool_id.replace("_", " "))
