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
	var material_label := Label3D.new()
	material_label.name = "SupplyLabel"
	material_label.position = Vector3(0.0, 2.45, 0.0)
	material_label.font_size = 26
	material_label.outline_size = 5
	material_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	material_label.no_depth_test = true
	site.add_child(material_label)
	var required: Dictionary = BuildingCatalog.definition_for(building_type).get("costs", {}).duplicate(true)
	simulation.construction_sites.append({"cell": cell, "type": building_type, "position": position, "node": site, "fill": fill, "progress": 0.0, "blueprint": blueprint, "modules_built": 0, "required_materials": required, "delivered_materials": {}})
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
		if not _is_supplied(site):
			_update_supply_label(site)
			simulation.construction_sites[index] = site
			continue
		_update_supply_label(site)
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

func _is_supplied(site: Dictionary) -> bool:
	for resource_type in site.required_materials:
		if int(site.delivered_materials.get(resource_type, 0)) < int(site.required_materials[resource_type]):
			return false
	return true

func _update_supply_label(site: Dictionary) -> void:
	var label := site.node.get_node_or_null("SupplyLabel") as Label3D
	if label == null:
		return
	var delivered := 0
	var required := 0
	for resource_type in site.required_materials:
		delivered += int(site.delivered_materials.get(resource_type, 0))
		required += int(site.required_materials[resource_type])
	label.text = "MATERIALS %d/%d" % [delivered, required]
	label.modulate = Color("f0c45d") if delivered < required else Color("56bd58")


func cancel_site(site_node: Node3D) -> void:
	for index in range(simulation.construction_sites.size() - 1, -1, -1):
		var site: Dictionary = simulation.construction_sites[index]
		if site.node != site_node:
			continue
		# Delivered stock is returned at the normal cancellation rate. In-transit
		# reservations are returned in full so cargo can never vanish.
		for resource_type in site.delivered_materials:
			var refund := maxi(1, floori(int(site.delivered_materials[resource_type]) * 0.5))
			simulation.settlement.add(resource_type, refund)
		for resource_type in site.get("reserved_materials", {}):
			simulation.settlement.add(resource_type, int(site.reserved_materials[resource_type]))
		for citizen in simulation.citizens:
			if citizen.construction_site == site_node and citizen.state in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]:
				citizen.carried_amount = 0
				citizen.construction_site = null
				citizen.idle()
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
