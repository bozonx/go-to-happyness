class_name ConstructionService
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func start_site(cell: Vector2i, building_type: String, position: Vector3, rotation_quarters := 0, supplied_blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> void:
	var site := Node3D.new()
	site.position = position
	site.rotation.y = rotation_quarters * PI * 0.5
	site.set_meta("building_type", building_type)
	simulation.add_child(site)
	var blueprint := supplied_blueprint if not supplied_blueprint.is_empty() else BuildingBlueprints.get_blueprint(building_type)
	site.set_meta("footprint", blueprint.footprint)
	site.set_meta("occupied_footprint", occupied_footprint if occupied_footprint != Vector2i.ZERO else blueprint.footprint)
	var territory := MeshInstance3D.new()
	var territory_mesh := BoxMesh.new()
	var display_footprint: Vector2i = blueprint.footprint
	territory_mesh.size = Vector3(display_footprint.x, 0.035, display_footprint.y)
	territory.mesh = territory_mesh
	territory.position.y = 0.025
	var territory_material := StandardMaterial3D.new()
	territory_material.albedo_color = Color(0.22, 0.72, 0.43, 0.35)
	territory_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	territory_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	territory.material_override = territory_material
	site.add_child(territory)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.45, 0.11, 0.12)
	var back := MeshInstance3D.new()
	back.mesh = bar_mesh
	back.position = Vector3(0.0, 2.15, 0.0)
	var back_material := StandardMaterial3D.new()
	back_material.albedo_color = Color("392d2e")
	back.material_override = back_material
	site.add_child(back)
	var fill := MeshInstance3D.new()
	fill.mesh = bar_mesh
	fill.position = Vector3(-0.725, 2.17, -0.07)
	var fill_material := StandardMaterial3D.new()
	fill_material.albedo_color = Color("56bd58")
	fill.material_override = fill_material
	fill.scale.x = 0.01
	site.add_child(fill)
	simulation.construction_sites.append({"cell": cell, "type": building_type, "position": position, "node": site, "fill": fill, "progress": 0.0, "blueprint": blueprint, "modules_built": 0})
	# Clickable selector so players can open the construction menu
	var selector := Area3D.new()
	selector.add_to_group("construction_selector")
	selector.collision_layer = 4
	selector.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(display_footprint.x, 2.5, display_footprint.y)
	shape.shape = box
	shape.position = Vector3(0.0, 1.25, 0.0)
	selector.add_child(shape)
	site.add_child(selector)
	simulation._update_workers()


func tick(delta: float) -> void:
	for index in range(simulation.construction_sites.size() - 1, -1, -1):
		var site: Dictionary = simulation.construction_sites[index]
		var builder_power: float = simulation._building_power(site.node)
		var progress: float = ConstructionProgress.advance(site.progress, delta, simulation.CONSTRUCTION_DURATION, builder_power)
		if index == 0:
			simulation.status_label.text = "Building %s: %d builder(s), %.1fx speed." % [site.type, simulation._builder_count(site.node), builder_power]
		site.progress = progress
		var modules: Array = site.blueprint.modules
		var target_module_count := mini(modules.size(), floori(progress * modules.size()))
		while site.modules_built < target_module_count:
			site.node.add_child(BuildingBlueprints.create_module(modules[site.modules_built]))
			site.modules_built += 1
		var fill: MeshInstance3D = site.fill
		fill.scale.x = maxf(0.01, progress)
		fill.position.x = -0.725 + 0.725 * progress
		simulation.construction_sites[index] = site
		if progress < 1.0:
			continue
		if is_instance_valid(fill):
			fill.get_parent().remove_child(fill)
			fill.queue_free()
		for child in site.node.get_children():
			if child is MeshInstance3D and child != fill:
				child.queue_free()
		simulation.construction_sites.remove_at(index)
		for citizen in simulation.citizens:
			citizen.finish_construction(site.node)
		simulation._complete_building(site.cell, site.type, site.position, site.node, site.blueprint)


func cancel_site(site_node: Node3D) -> void:
	for index in range(simulation.construction_sites.size() - 1, -1, -1):
		var site: Dictionary = simulation.construction_sites[index]
		if site.node != site_node:
			continue
		# Refund ~50% of building costs
		var costs: Dictionary = BuildingCatalog.definition_for(site.type).get("costs", {})
		for resource_type in costs:
			var refund := maxi(1, floori(int(costs[resource_type]) * 0.5))
			simulation.settlement.add(resource_type, refund)
		# Release builders working on this site
		for citizen in simulation.citizens:
			citizen.finish_construction(site_node)
		# Remove the footprint reservation
		for fp_idx in range(simulation.building_footprints.size() - 1, -1, -1):
			var record: Dictionary = simulation.building_footprints[fp_idx]
			if record.center == site.position and record.node == null:
				simulation.building_footprints.remove_at(fp_idx)
				break
		# Remove position from building_positions
		var pos_idx: int = simulation.building_positions.find(site.position)
		if pos_idx >= 0:
			simulation.building_positions.remove_at(pos_idx)
		# Remove placed_buildings entry
		simulation.placed_buildings.erase(site.cell)
		# Clean up scene node
		site_node.queue_free()
		simulation.construction_sites.remove_at(index)
		simulation._rebuild_navigation_mesh()
		simulation._update_workers()
		return
