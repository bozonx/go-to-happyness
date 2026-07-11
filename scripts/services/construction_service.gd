class_name ConstructionService
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func start_site(cell: Vector2i, building_type: String, position: Vector3) -> void:
	var site := Node3D.new()
	site.position = position
	site.set_meta("building_type", building_type)
	simulation.add_child(site)
	var blueprint := BuildingBlueprints.get_blueprint(building_type)
	site.set_meta("footprint", blueprint.footprint)
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
	simulation._update_workers()


func tick(delta: float) -> void:
	for index in range(simulation.construction_sites.size() - 1, -1, -1):
		var site: Dictionary = simulation.construction_sites[index]
		var builder_power: float = simulation._building_power(site.node)
		var progress: float = minf(1.0, site.progress + delta / simulation.CONSTRUCTION_DURATION * builder_power)
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
