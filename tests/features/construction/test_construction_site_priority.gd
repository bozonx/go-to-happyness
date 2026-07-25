extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")


func _init() -> void:
	var simulation := await SimHelper.setup_simulation(self)

	var warehouse_position := Vector3(12.0, 0.0, 12.0)
	var warehouse_blueprint := BuildingBlueprints.get_blueprint("straw_warehouse")
	simulation.building_registry.reserve(Vector2i(12, 12), warehouse_position, warehouse_blueprint.footprint)
	var waiting_site: ConstructionSite = SimHelper.create_construction_site(simulation, Vector2i(12, 12), "straw_warehouse", warehouse_position, 0, warehouse_blueprint, warehouse_blueprint.footprint)

	var tent_position := Vector3(16.0, 0.0, 12.0)
	var tent_blueprint := BuildingBlueprints.get_blueprint("tent")
	simulation.building_registry.reserve(Vector2i(16, 12), tent_position, tent_blueprint.footprint)
	var supplied_site: ConstructionSite = SimHelper.create_construction_site(simulation, Vector2i(16, 12), "tent", tent_position, 0, tent_blueprint, tent_blueprint.footprint)
	for resource_type in supplied_site.required_materials:
		var required := int(supplied_site.required_materials.get(resource_type, 0))
		if required > 0:
			supplied_site.delivered_materials[resource_type] = required

	assert(waiting_site.material_progress() == 0.0)
	assert(supplied_site.material_progress() > supplied_site.progress)
	assert(SimHelper.preferred_construction_site(simulation) == supplied_site, "Builders must not wait at an unsupplied higher-priority project while another site can advance")

	# A builder already standing at the blocked project must receive a new order,
	# rather than keeping the stale "in progress" assignment forever.
	var builder: Citizen = simulation.citizens[2]
	builder.global_position = supplied_site.node.global_position
	builder.route_reachability_query = func(_from: Vector3, _target: Vector3, _allow_house: bool) -> bool: return true
	builder.idle()
	builder.assign_construction(waiting_site.node)
	var helpers := FacadeTargetHelpers.new(simulation, RouteCandidateCache.new())
	var facts := ConstructionFactCollector.new().collect(
		FacadeContext.new(simulation, helpers, builder, builder.ai_id, true, true, "construction")
	)
	assert(not bool(facts[&"daily.construction.in_progress"]), "A material-blocked active site must not remain an in-progress order")
	assert(facts[&"daily.construction.position"] != Vector3.INF, "A supplied/free alternative must produce a replacement order")
	assert((facts[&"daily.construction.position"] as Vector3).distance_to(builder._reachable_construction_approach(supplied_site.node)) < 0.01, "Replacement order must target the buildable site")

	# Logistics has a different concern from builder selection: while the builder
	# advances the supplied tent, couriers must still publish deliveries for the
	# waiting strategic project.
	for resource_type in waiting_site.required_materials:
		simulation.settlement.add(str(resource_type), int(waiting_site.required_materials[resource_type]))
	SimHelper.update_couriers(simulation)
	var waiting_delivery_published := false
	for task: CourierTask in simulation.courier_dispatcher.available_tasks():
		if task.kind == CourierTask.Kind.CONSTRUCTION and task.payload.get("site") == waiting_site:
			waiting_delivery_published = true
			break
	assert(waiting_delivery_published, "Couriers must supply waiting projects while builders work elsewhere")

	SimHelper.cleanup_simulation(self, simulation)
	quit(0)
