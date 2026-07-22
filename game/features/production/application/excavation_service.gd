class_name ExcavationService
extends RefCounted

## Manages excavation/dig site lifecycle: site creation, excavation cycles,
## tool/depth checks, resource discovery, pit visuals, and site exhaustion.

const DigSiteRecord = preload("res://game/features/production/domain/dig_site_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

var dig_site_scene: PackedScene = null
var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func set_dig_site_scene(scene: PackedScene) -> void:
	dig_site_scene = scene


func _get_dig_site_scene() -> PackedScene:
	if dig_site_scene == null:
		dig_site_scene = load("res://game/features/world/presentation/dig_site.tscn") as PackedScene
	return dig_site_scene


func on_excavation_cycle(worker: Citizen, site_node: Node3D, efficiency: float) -> void:
	for index in range(simulation.dig_sites.size()):
		var site: DigSiteRecord = simulation.dig_sites[index]
		if site.node != site_node:
			continue

		var next_depth: int = site.depth + 1
		var tool_id: String = tool_for_depth(site, next_depth)
		if tool_id != "" and not bool(simulation.settlement.tools.get(tool_id, false)):
			worker.assigned_dig_site = null
			worker.idle()
			simulation._update_interface("Excavation paused: missing tool '%s' for the next layer." % tool_id)
			simulation._update_workers()
			return

		site.depth += 1
		if site.depth <= site.grass_limit:
			worker.register_pending_resource(ResourceIds.GRASS, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("3e612c")
			site.pit.material_override = pit_material
			simulation._update_interface("Digger is carrying grass to the warehouse.")
		elif site.depth <= site.soil_limit:
			var res: String = ResourceIds.SOIL
			if worker.skills.get("excavation", 0.0) >= 1.0 and randf() < 0.10:
				res = ResourceIds.CLAY if randf() < 0.5 else ResourceIds.STONE
				simulation._update_interface("Deep Digger: Digger found rare %s in soil!" % res.capitalize())
			worker.register_pending_resource(res, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("78533b")
			site.pit.material_override = pit_material
			simulation._update_interface("Digger is carrying %s to the warehouse." % res)
		elif site.depth <= site.clay_limit:
			worker.register_pending_resource(ResourceIds.CLAY, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("a96445")
			site.pit.material_override = pit_material
			simulation._update_interface("Digger is carrying clay to the warehouse.")
		elif site.depth <= site.stone_limit:
			worker.register_pending_resource(ResourceIds.STONE, 1)
			var pit_material := StandardMaterial3D.new()
			pit_material.albedo_color = Color("62676a")
			site.pit.material_override = pit_material
			simulation._update_interface("Digger is carrying stone to the warehouse.")
		else:
			site_node.queue_free()
			simulation.dig_sites.remove_at(index)
			simulation.dig_cells.erase(site.cell)
			simulation.exhausted_dig_cells[site.cell] = true
			for citizen in simulation.citizens:
				if citizen.assigned_dig_site == site_node:
					citizen.assigned_dig_site = null
			simulation._update_workers()
			simulation._update_interface("Stone excavation is exhausted; choose another cell.")
			return
		simulation._request_courier_dispatch()
		return


func can_work_at_dig_site(site: DigSiteRecord) -> bool:
	var next_depth: int = site.depth + 1
	if next_depth > site.stone_limit:
		return false
	var tool_id: String = tool_for_depth(site, next_depth)
	if tool_id != "" and not bool(simulation.settlement.tools.get(tool_id, false)):
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
	for site in simulation.dig_sites:
		if can_work_at_dig_site(site):
			count += 1
	return count


func dig_site_for_node(site_node: Node3D) -> DigSiteRecord:
	for site in simulation.dig_sites:
		if site.node == site_node:
			return site
	return null


func start_dig_assignment() -> void:
	if simulation.selected_builder == null:
		return
	simulation.dig_mode = true
	simulation.build_mode = ""
	simulation.selection_marker.visible = true
	simulation._show_territory_overlay(false)
	simulation.selection_material.albedo_color = Color(0.65, 0.42, 0.2, 0.55)
	simulation._move_selection(simulation.selected_world_position)
	simulation._update_interface("Choose a clear point on the terrain for excavation.")


func place_dig_site(world_position: Vector3) -> void:
	var cell: Vector2i = simulation._placement_key(world_position)
	if not can_excavate(world_position):
		simulation._update_interface("Excavation is not allowed at this point.")
		return
	var site: DigSiteRecord = dig_site_at(cell)
	if site == null:
		site = create_dig_site(cell, world_position)
	simulation.selected_builder.assigned_dig_site = site.node
	if simulation.selected_builder.employment_state == Citizen.EmploymentState.NO_PERMANENT_WORK:
		simulation.selected_builder.begin_employment_processing(simulation._employment_center_position(), "excavation", site.node)
	simulation.dig_mode = false
	simulation.selection_marker.visible = false
	simulation._update_workers()
	simulation._show_selected_citizen_menu()
	simulation._update_interface("Excavation assigned. Grass, soil and clay will be exposed before stone.")


func can_excavate(world_position: Vector3) -> bool:
	var cell: Vector2i = simulation._placement_key(world_position)
	return not simulation.exhausted_dig_cells.has(cell) and simulation._is_clear_of_objects(world_position, 1.0)


func dig_site_at(cell: Vector2i) -> DigSiteRecord:
	for site in simulation.dig_sites:
		if site.cell == cell:
			return site
	return null


func create_dig_site(cell: Vector2i, world_position: Vector3) -> DigSiteRecord:
	var site_node: Node3D = _get_dig_site_scene().instantiate()
	site_node.position = world_position
	simulation.add_child(site_node)
	var pit: MeshInstance3D = site_node.get_node("Pit") as MeshInstance3D

	var grass_depth: int = simulation.random.randi_range(2, 4)
	var soil_depth: int = simulation.random.randi_range(3, 6)
	var clay_depth: int = simulation.random.randi_range(4, 8)
	var stone_depth: int = simulation.random.randi_range(5, 10)

	var grass_limit: int = grass_depth
	var soil_limit: int = grass_limit + soil_depth
	var clay_limit: int = soil_limit + clay_depth
	var stone_limit: int = clay_limit + stone_depth

	var site := DigSiteRecord.new(cell, site_node, pit, grass_limit, soil_limit, clay_limit, stone_limit, 0)
	simulation.dig_sites.append(site)
	simulation.dig_cells[cell] = true
	return site
