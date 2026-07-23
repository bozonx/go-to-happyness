class_name ExcavationService
extends RefCounted

## Manages excavation/dig site lifecycle: site creation, excavation cycles,
## tool/depth checks, resource discovery, pit visuals, and site exhaustion.

const DigSiteRecord = preload("res://game/features/production/domain/dig_site_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var _settlement: SettlementState
var _citizens: Array = []
var _dig_sites: Array = []
var _dig_cells: Dictionary = {}
var _exhausted_dig_cells: Dictionary = {}
var _random: RandomNumberGenerator
var _update_interface: Callable
var _update_workers: Callable
var _request_courier_dispatch: Callable
var _placement_key: Callable
var _is_clear_of_objects: Callable
var _employment_center_position: Callable
var _show_territory_overlay: Callable
var _move_selection: Callable
var _show_selected_citizen_menu: Callable
var _selected_builder_getter: Callable
var _selected_world_position_getter: Callable
var _selection_marker_getter: Callable
var _selection_material_getter: Callable
var _set_dig_mode: Callable
var _set_build_mode: Callable
var _add_child: Callable


func configure(
	p_settlement: SettlementState,
	p_citizens: Array,
	p_dig_sites: Array,
	p_dig_cells: Dictionary,
	p_exhausted_dig_cells: Dictionary,
	p_random: RandomNumberGenerator,
	p_update_interface: Callable,
	p_update_workers: Callable,
	p_request_courier_dispatch: Callable,
	p_placement_key: Callable,
	p_is_clear_of_objects: Callable,
	p_employment_center_position: Callable,
	p_show_territory_overlay: Callable,
	p_move_selection: Callable,
	p_show_selected_citizen_menu: Callable,
	p_selected_builder_getter: Callable,
	p_selected_world_position_getter: Callable,
	p_selection_marker_getter: Callable,
	p_selection_material_getter: Callable,
	p_set_dig_mode: Callable,
	p_set_build_mode: Callable,
	p_add_child: Callable
) -> void:
	_settlement = p_settlement
	_citizens = p_citizens
	_dig_sites = p_dig_sites
	_dig_cells = p_dig_cells
	_exhausted_dig_cells = p_exhausted_dig_cells
	_random = p_random
	_update_interface = p_update_interface
	_update_workers = p_update_workers
	_request_courier_dispatch = p_request_courier_dispatch
	_placement_key = p_placement_key
	_is_clear_of_objects = p_is_clear_of_objects
	_employment_center_position = p_employment_center_position
	_show_territory_overlay = p_show_territory_overlay
	_move_selection = p_move_selection
	_show_selected_citizen_menu = p_show_selected_citizen_menu
	_selected_builder_getter = p_selected_builder_getter
	_selected_world_position_getter = p_selected_world_position_getter
	_selection_marker_getter = p_selection_marker_getter
	_selection_material_getter = p_selection_material_getter
	_set_dig_mode = p_set_dig_mode
	_set_build_mode = p_set_build_mode
	_add_child = p_add_child


var dig_site_scene: PackedScene = null


func set_dig_site_scene(scene: PackedScene) -> void:
	dig_site_scene = scene


func _get_dig_site_scene() -> PackedScene:
	if dig_site_scene == null:
		dig_site_scene = load("res://game/features/world/presentation/dig_site.tscn") as PackedScene
	return dig_site_scene


func on_excavation_cycle(worker: Citizen, site_node: Node3D, efficiency: float) -> void:
	for index in range(_dig_sites.size()):
		var site: DigSiteRecord = _dig_sites[index]
		if site.node != site_node:
			continue

		var next_depth: int = site.depth + 1
		var tool_id: String = tool_for_depth(site, next_depth)
		if tool_id != "" and not bool(_settlement.tools.get(tool_id, false)):
			worker.assigned_dig_site = null
			worker.idle()
			_update_interface.call("Excavation paused: missing tool '%s' for the next layer." % tool_id)
			_update_workers.call()
			return

		site.depth += 1
		if site.depth <= site.grass_limit:
			worker.register_pending_resource(ResourceIds.GRASS, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("3e612c")
			site.pit.material_override = pit_material
			_update_interface.call("Digger is carrying grass to the warehouse.")
		elif site.depth <= site.soil_limit:
			var res: String = ResourceIds.SOIL
			if worker.skills.get("excavation", 0.0) >= 1.0 and randf() < 0.10:
				res = ResourceIds.CLAY if randf() < 0.5 else ResourceIds.STONE
				_update_interface.call("Deep Digger: Digger found rare %s in soil!" % res.capitalize())
			worker.register_pending_resource(res, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("78533b")
			site.pit.material_override = pit_material
			_update_interface.call("Digger is carrying %s to the warehouse." % res)
		elif site.depth <= site.clay_limit:
			worker.register_pending_resource(ResourceIds.CLAY, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("a96445")
			site.pit.material_override = pit_material
			_update_interface.call("Digger is carrying clay to the warehouse.")
		elif site.depth <= site.stone_limit:
			worker.register_pending_resource(ResourceIds.STONE, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("62676a")
			site.pit.material_override = pit_material
			_update_interface.call("Digger is carrying stone to the warehouse.")
		else:
			site_node.queue_free()
			_dig_sites.remove_at(index)
			_dig_cells.erase(site.cell)
			_exhausted_dig_cells[site.cell] = true
			for citizen in _citizens:
				if citizen.assigned_dig_site == site_node:
					citizen.assigned_dig_site = null
			_update_workers.call()
			_update_interface.call("Stone excavation is exhausted; choose another cell.")
			return
		_request_courier_dispatch.call()
		return


func can_work_at_dig_site(site: DigSiteRecord) -> bool:
	var next_depth: int = site.depth + 1
	if next_depth > site.stone_limit:
		return false
	var tool_id: String = tool_for_depth(site, next_depth)
	if tool_id != "" and not bool(_settlement.tools.get(tool_id, false)):
		return false
	return true


func tool_for_depth(site: DigSiteRecord, depth: int) -> String:
	if depth <= site.grass_limit:
		return ""
	elif depth <= site.soil_limit:
		return "shovel"
	elif depth <= site.clay_limit:
		return "hoe"
	elif depth <= site.stone_limit:
		return "pickaxe"
	return ""


func resource_for_depth(site: DigSiteRecord, depth: int) -> String:
	if depth <= site.grass_limit:
		return ResourceIds.GRASS
	elif depth <= site.soil_limit:
		return ResourceIds.SOIL
	elif depth <= site.clay_limit:
		return ResourceIds.CLAY
	elif depth <= site.stone_limit:
		return ResourceIds.STONE
	return ResourceIds.SOIL


func count_valid_dig_sites() -> int:
	var count := 0
	for site in _dig_sites:
		if can_work_at_dig_site(site):
			count += 1
	return count


func dig_site_for_node(site_node: Node3D) -> DigSiteRecord:
	for site in _dig_sites:
		if site.node == site_node:
			return site
	return null


func start_dig_assignment() -> void:
	var selected_builder: Citizen = _selected_builder_getter.call()
	if selected_builder == null:
		return
	_set_dig_mode.call(true)
	_set_build_mode.call("")
	var selection_marker: Node3D = _selection_marker_getter.call()
	if selection_marker != null:
		selection_marker.visible = true
	_show_territory_overlay.call(false)
	var selection_material: StandardMaterial3D = _selection_material_getter.call()
	if selection_material != null:
		selection_material.albedo_color = Color(0.65, 0.42, 0.2, 0.55)
	_move_selection.call(_selected_world_position_getter.call())
	_update_interface.call("Choose a clear point on the terrain for excavation.")


func place_dig_site(world_position: Vector3) -> void:
	var cell: Vector2i = _placement_key.call(world_position)
	if not can_excavate(world_position):
		_update_interface.call("Excavation is not allowed at this point.")
		return
	var site: DigSiteRecord = dig_site_at(cell)
	if site == null:
		site = create_dig_site(cell, world_position)
	var selected_builder: Citizen = _selected_builder_getter.call()
	selected_builder.assigned_dig_site = site.node
	if selected_builder.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
		selected_builder.begin_employment_processing(_employment_center_position.call(), "excavation", site.node)
	_set_dig_mode.call(false)
	var selection_marker: Node3D = _selection_marker_getter.call()
	if selection_marker != null:
		selection_marker.visible = false
	_update_workers.call()
	_show_selected_citizen_menu.call()
	_update_interface.call("Excavation assigned. Grass, soil and clay will be exposed before stone.")


func can_excavate(world_position: Vector3) -> bool:
	var cell: Vector2i = _placement_key.call(world_position)
	return not _exhausted_dig_cells.has(cell) and _is_clear_of_objects.call(world_position, 1.0)


func dig_site_at(cell: Vector2i) -> DigSiteRecord:
	for site in _dig_sites:
		if site.cell == cell:
			return site
	return null


func create_dig_site(cell: Vector2i, world_position: Vector3) -> DigSiteRecord:
	var site_node: Node3D = _get_dig_site_scene().instantiate()
	site_node.position = world_position
	_add_child.call(site_node)
	var pit: MeshInstance3D = site_node.get_node("Pit") as MeshInstance3D

	var grass_depth: int = _random.randi_range(2, 4)
	var soil_depth: int = _random.randi_range(3, 6)
	var clay_depth: int = _random.randi_range(4, 8)
	var stone_depth: int = _random.randi_range(5, 10)

	var grass_limit: int = grass_depth
	var soil_limit: int = grass_limit + soil_depth
	var clay_limit: int = soil_limit + clay_depth
	var stone_limit: int = clay_limit + stone_depth

	var site := DigSiteRecord.new(cell, site_node, pit, grass_limit, soil_limit, clay_limit, stone_limit, 0)
	_dig_sites.append(site)
	_dig_cells[cell] = true
	return site
