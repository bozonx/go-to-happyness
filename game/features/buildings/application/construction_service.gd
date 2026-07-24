class_name ConstructionService
extends RefCounted

var site_scene: PackedScene = null
var entrance_post_scene: PackedScene = null
var runtime: ConstructionRuntime
var sites: Array[ConstructionSite] = []


const BuildingEntrancePositionsScript = preload("res://game/features/buildings/domain/building_entrance_positions.gd")
const SERVICE_PAD_OFFSET := 1.0


func configure(next_runtime: ConstructionRuntime) -> void:
	runtime = next_runtime


func configure_scenes(next_site_scene: PackedScene, next_entrance_post_scene: PackedScene) -> void:
	site_scene = next_site_scene
	entrance_post_scene = next_entrance_post_scene


func _get_site_scene() -> PackedScene:
	assert(site_scene != null, "ConstructionService.site_scene must be set before use")
	return site_scene


func _get_entrance_post_scene() -> PackedScene:
	assert(entrance_post_scene != null, "ConstructionService.entrance_post_scene must be set before use")
	return entrance_post_scene


func start_site(cell: Vector2i, building_type: String, position: Vector3, rotation_quarters := 0, supplied_blueprint: Dictionary = {}, occupied_footprint := Vector2i.ZERO) -> ConstructionSite:
	var site_node: Node3D = _get_site_scene().instantiate()
	site_node.position = position
	site_node.rotation.y = rotation_quarters * PI * 0.5
	site_node.set_meta("building_type", building_type)
	runtime.scene_root.add_child(site_node)
	var blueprint := supplied_blueprint if not supplied_blueprint.is_empty() else BuildingBlueprints.get_blueprint(building_type)
	if blueprint.has("blueprint_ref"):
		site_node.set_meta("blueprint_ref", blueprint["blueprint_ref"])
	if blueprint.has("work_zones"):
		site_node.set_meta("active_work_zones", blueprint["work_zones"])
	if blueprint.has("routing_anchors"):
		site_node.set_meta("routing_anchors", blueprint["routing_anchors"])
	site_node.set_meta("footprint", blueprint.footprint)
	site_node.set_meta("occupied_footprint", occupied_footprint if occupied_footprint != Vector2i.ZERO else blueprint.footprint)
	site_node.set_meta("service_positions", BuildingEntrancePositionsScript.positions(site_node, blueprint.footprint, SERVICE_PAD_OFFSET))

	var display_footprint: Vector2i = blueprint.footprint

	# Entrance posts and flags are positioned dynamically based on the building footprint.
	var entrance_parent := site_node.get_node("ConstructionEntrance") as Node3D
	for service_position: Vector3 in site_node.get_meta("service_positions"):
		var post := _get_entrance_post_scene().instantiate() as Node3D
		post.position = (service_position - site_node.position).rotated(Vector3.UP, -site_node.rotation.y)
		post.position.y = 0.0
		entrance_parent.add_child(post)

	# Territory mesh size depends on the building footprint.
	var territory := site_node.get_node("ConstructionTerritory") as MeshInstance3D
	var territory_mesh := BoxMesh.new()
	territory_mesh.size = Vector3(display_footprint.x, 0.035, display_footprint.y)
	territory.mesh = territory_mesh

	# Selector collision shape size depends on the building footprint.
	var selector := site_node.get_node("ConstructionSelector") as Area3D
	var selector_shape := selector.get_node("CollisionShape3D") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = Vector3(display_footprint.x, 2.5, display_footprint.y)
	selector_shape.shape = box

	var required: Dictionary = BuildingCatalog.definition_for(building_type).get("costs", {}).duplicate(true)
	var site := ConstructionSite.new(cell, building_type, position, site_node, blueprint, required)
	site.site_id = cell.x * 100000 + cell.y
	sites.append(site)
	# Commit any resources that are already in storage to this site so they cannot
	# be accidentally spent on research, trade, or another building.
	for resource_type in required:
		var needed := int(required.get(resource_type, 0))
		if needed > 0:
			runtime.settlement.reserve_for_construction(site.site_id, str(resource_type), needed)
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
		if runtime.update_supply_label.is_valid():
			runtime.update_supply_label.call(site)
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
		var fill := site.node.get_node_or_null("ConstructionProgressFill") as MeshInstance3D
		if is_instance_valid(fill):
			fill.scale.x = maxf(0.01, progress)
			fill.position.x = -0.725 + 0.725 * progress
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
	# Delivery is an event boundary. Publish buildability synchronously so builders
	# and presentation do not wait for the next general construction tick.
	site.node.set_meta("can_advance", site.material_progress() > site.progress + 0.0001)
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


func _cleanup_completed_site(site: ConstructionSite) -> void:
	# Construction-only visuals and hit area must not survive as UI on the
	# completed building. Blueprint modules are StaticBody3D children and remain.
	for child_name in ["ConstructionTerritory", "ConstructionProgressBack", "ConstructionProgressFill", "SupplyLabel", "ConstructionSelector", "ConstructionEntrance"]:
		var child := site.node.get_node_or_null(child_name)
		if child != null:
			child.queue_free()
