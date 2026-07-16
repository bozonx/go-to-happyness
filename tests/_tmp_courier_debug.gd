extends SceneTree

func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate() as Node
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _f in range(10):
		await physics_frame

	var cell := Vector2i(12, 12)
	var site_position := Vector3(12.0, 0.0, 12.0)
	var blueprint := BuildingBlueprints.get_blueprint("straw_warehouse")
	simulation.building_registry.reserve(cell, site_position, blueprint.footprint)
	simulation._create_construction_site(cell, "straw_warehouse", site_position, 0, blueprint, blueprint.footprint)

	for res in ["logs", "boards", "grass", "branches"]:
		simulation.settlement.add(res, 50)
	simulation.warehouse_positions.append(Vector3.ZERO)
	simulation.settlement.add_warehouse("warehouse")

	var builder: Citizen = simulation.citizens[2]
	builder.global_position = Vector3(10.0, 0.0, 10.0)
	builder.idle()
	simulation._assign_daily_order(builder, "construction")

	var courier: Citizen = simulation.citizens[3]
	courier.global_position = Vector3.ZERO
	courier.idle()
	simulation._assign_daily_order(courier, "courier")

	var frames := 0
	var max_frames := 3000
	while frames < max_frames:
		await physics_frame
		frames += 1
		if simulation.construction_sites.is_empty():
			print("completed at frame %d" % frames)
			break
		var site = simulation.construction_sites[0]
		if frames % 100 == 0:
			print("frame=%d site_progress=%.3f delivered=%s reserved=%s builder_state=%s builder_pos=%s courier_state=%s courier_pos=%s tasks=%d" % [
				frames,
				site.progress,
				site.delivered_materials,
				site.reserved_materials,
				builder.state,
				builder.global_position,
				courier.state,
				courier.global_position,
				simulation.courier_dispatcher.available_tasks().size()
			])

	print("done frames=%d" % frames)
	root.remove_child(simulation)
	simulation.free()
	quit(0)
