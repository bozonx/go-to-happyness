class_name ConstructionService
extends RefCounted

var runtime: ConstructionRuntime
var sites: Array[ConstructionSite] = []


const SERVICE_PAD_OFFSET := 1.0


func configure(next_runtime: ConstructionRuntime) -> void:
	runtime = next_runtime


func start_site(cell: Vector2i, building_type: String, position: Vector3, rotation_quarters := 0, supplied_blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> ConstructionSite:
	var site_node := Node3D.new()
	site_node.position = position
	site_node.rotation.y = rotation_quarters * PI * 0.5
	site_node.set_meta("building_type", building_type)
	runtime.scene_root.add_child(site_node)
	var blueprint := supplied_blueprint if not supplied_blueprint.is_empty() else BuildingBlueprints.get_blueprint(building_type)
	site_node.set_meta("footprint", blueprint.footprint)
	site_node.set_meta("occupied_footprint", occupied_footprint if occupied_footprint != Vector2i.ZERO else blueprint.footprint)
	site_node.set_meta("service_positions", BuildingEntrancePositions.positions(site_node, blueprint.footprint, SERVICE_PAD_OFFSET))

	var entrance_parent := Node3D.new()
	entrance_parent.name = "ConstructionEntrance"
	var entrance_material := StandardMaterial3D.new()
	entrance_material.albedo_color = Color("f0c45d")
	entrance_material.emission_enabled = true
	entrance_material.emission = Color("f0c45d")
	for service_position: Vector3 in site_node.get_meta("service_positions"):
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.07
		post_mesh.bottom_radius = 0.07
		post_mesh.height = 1.4
		post.mesh = post_mesh
		post.material_override = entrance_material
		post.position = (service_position - site_node.position).rotated(Vector3.UP, -site_node.rotation.y)
		post.position.y = 0.7
		entrance_parent.add_child(post)
		var flag := MeshInstance3D.new()
		var flag_mesh := BoxMesh.new()
		flag_mesh.size = Vector3(0.26, 0.16, 0.04)
		flag.mesh = flag_mesh
		flag.material_override = entrance_material
		flag.position = post.position + Vector3.UP * 0.7
		entrance_parent.add_child(flag)
	site_node.add_child(entrance_parent)

	var territory := MeshInstance3D.new()
	territory.name = "ConstructionTerritory"
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
	site_node.add_child(territory)

	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.45, 0.11, 0.12)
	var back := MeshInstance3D.new()
	back.name = "ConstructionProgressBack"
	back.mesh = bar_mesh
	back.position = Vector3(0.0, 2.15, 0.0)
	var back_material := StandardMaterial3D.new()
	back_material.albedo_color = Color("392d2e")
	back.material_override = back_material
	site_node.add_child(back)
	var fill := MeshInstance3D.new()
	fill.name = "ConstructionProgressFill"
	fill.mesh = bar_mesh
	fill.position = Vector3(-0.725, 2.17, -0.07)
	var fill_material := StandardMaterial3D.new()
	fill_material.albedo_color = Color("56bd58")
	fill.material_override = fill_material
	fill.scale.x = 0.01
	site_node.add_child(fill)
	var material_label := Label3D.new()
	material_label.name = "SupplyLabel"
	material_label.position = Vector3(0.0, 2.45, 0.0)
	material_label.font_size = 26
	material_label.outline_size = 5
	material_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	material_label.no_depth_test = true
	site_node.add_child(material_label)

	var required: Dictionary = BuildingCatalog.definition_for(building_type).get("costs", {}).duplicate(true)
	var site := ConstructionSite.new(cell, building_type, position, site_node, fill, blueprint, required)
	site.site_id = site_node.get_instance_id()
	sites.append(site)
	# Commit any resources that are already in storage to this site so they cannot
	# be accidentally spent on research, trade, or another building.
	for resource_type in required:
		var needed := int(required.get(resource_type, 0))
		if needed > 0:
			runtime.settlement.reserve_for_construction(site.site_id, str(resource_type), needed)
	_add_selector(site_node, display_footprint)
	runtime.workers_changed.call()
	return site


func tick(delta: float) -> void:
	for index in range(sites.size() - 1, -1, -1):
		var site := sites[index]
		if not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
			# The site node was freed externally (e.g. mid-delivery cancellation).
			# Return in-transit cargo to storage and release any remaining reservations.
			for resource_type in site.reserved_materials:
				runtime.settlement.add(resource_type, int(site.reserved_materials[resource_type]))
			runtime.settlement.release_site_construction_reservations(site.site_id)
			sites.remove_at(index)
			continue
		_update_supply_label(site)
		var material_progress: float = site.material_progress()
		if material_progress <= 0.0:
			site.node.set_meta("can_advance", false)
			continue
		site.node.set_meta("can_advance", material_progress > site.progress + 0.0001)
		var builder_power: float = runtime.builder_power.call(site.node)
		var progress := ConstructionProgress.advance(site.progress, delta, runtime.duration, builder_power)
		progress = minf(progress, material_progress)
		if index == 0:
			runtime.set_status.call("Building %s: %d builder(s), %.1fx speed." % [site.building_type, runtime.builder_count.call(site.node), builder_power])
		site.progress = progress
		var modules: Array = site.blueprint.modules
		var target_module_count := mini(modules.size(), floori(progress * modules.size()))
		while site.modules_built < target_module_count:
			site.node.add_child(BuildingBlueprints.create_module(modules[site.modules_built]))
			site.modules_built += 1
		if is_instance_valid(site.fill):
			site.fill.scale.x = maxf(0.01, progress)
			site.fill.position.x = -0.725 + 0.725 * progress
		if progress < 1.0:
			continue
		_cleanup_completed_site(site)
		sites.remove_at(index)
		for citizen in runtime.citizens:
			citizen.finish_construction(site.node)
		runtime.building_completed.call(site.cell, site.building_type, site.position, site.node, site.blueprint)


func accept_delivery(site_node: Node3D, resource_type: String, amount: int) -> bool:
	var site := site_for_node(site_node)
	if site == null or amount <= 0:
		return false
	var required := int(site.required_materials.get(resource_type, 0))
	var delivered := int(site.delivered_materials.get(resource_type, 0))
	# Reservations are made before a courier leaves the warehouse. A final guard
	# here keeps late or duplicated deliveries from overfilling a completed site.
	if required <= delivered or amount > required - delivered:
		return false
	site.delivered_materials[resource_type] = int(site.delivered_materials.get(resource_type, 0)) + amount
	site.reserved_materials[resource_type] = maxi(0, int(site.reserved_materials.get(resource_type, 0)) - amount)
	runtime.settlement.release_for_construction(site.site_id, resource_type, amount)
	return true


func has_site(node: Node3D) -> bool:
	return site_for_node(node) != null


func site_for_node(node: Node3D) -> ConstructionSite:
	for site in sites:
		if site.node == node:
			return site
	return null


func cancel_site(site_node: Node3D) -> bool:
	for index in range(sites.size() - 1, -1, -1):
		var site := sites[index]
		if site.node != site_node:
			continue
		# Delivered stock is returned at the normal cancellation rate. In-transit
		# cargo is returned in full so resources can never vanish.
		for resource_type in site.delivered_materials:
			var refund := maxi(1, floori(int(site.delivered_materials[resource_type]) * 0.5))
			runtime.settlement.add(resource_type, refund)
		for resource_type in site.reserved_materials:
			runtime.settlement.add(resource_type, int(site.reserved_materials[resource_type]))
		runtime.settlement.release_site_construction_reservations(site.site_id)
		for citizen in runtime.citizens:
			if citizen.construction_site == site_node and citizen.state in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]:
				citizen.carried_amount = 0
				citizen.construction_site = null
				citizen.idle()
		for citizen in runtime.citizens:
			citizen.finish_construction(site_node)
		var record := runtime.building_registry.record_at_cell(site.cell)
		if record != null and record.node == site_node:
			runtime.building_registry.remove_node(site_node)
		else:
			runtime.building_registry.cancel_reservation(site.cell)
		site_node.queue_free()
		sites.remove_at(index)
		runtime.navigation_changed.call()
		runtime.workers_changed.call()
		return true
	return false


func _update_supply_label(site: ConstructionSite) -> void:
	if not is_instance_valid(site.node) or site.node.is_queued_for_deletion():
		return
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


func _add_selector(site_node: Node3D, footprint: Vector2i) -> void:
	var selector := Area3D.new()
	selector.name = "ConstructionSelector"
	selector.add_to_group("construction_selector")
	selector.collision_layer = 4
	selector.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(footprint.x, 2.5, footprint.y)
	shape.shape = box
	shape.position = Vector3(0.0, 1.25, 0.0)
	selector.add_child(shape)
	site_node.add_child(selector)


func _cleanup_completed_site(site: ConstructionSite) -> void:
	# Construction-only visuals and hit area must not survive as UI on the
	# completed building. Blueprint modules are StaticBody3D children and remain.
	for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
		var child := site.node.get_node_or_null(child_name)
		if child != null:
			child.queue_free()
