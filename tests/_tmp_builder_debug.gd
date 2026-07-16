extends SceneTree

func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame
	for _f in range(10):
		await physics_frame

	# Create a warehouse construction site.
	var cell := Vector2i(12, 12)
	var pos := Vector3(12.0, 0.0, 12.0)
	var bp := BuildingBlueprints.get_blueprint("warehouse")
	simulation.building_registry.reserve(cell, pos, bp.footprint)
	simulation._create_construction_site(cell, "warehouse", pos, 0, bp, bp.footprint)

	# Supply the site so the builder can work.
	var site = simulation.construction_sites[0]
	for resource_type in site.required_materials:
		var required: int = int(site.required_materials.get(resource_type, 0))
		if required > 0:
			site.delivered_materials[resource_type] = required

	# Pick a non-hero citizen and assign daily construction.
	var builder: Citizen = simulation.citizens[2]
	builder.global_position = Vector3(10.0, 0.0, 10.0)
	builder.idle()
	simulation._assign_daily_order(builder, "construction")

	var frames := 0
	var max_frames := 1000
	var prev_state = builder.state
	var print_every := 100
	while frames < max_frames:
		await physics_frame
		frames += 1
		if simulation.construction_sites.is_empty():
			print("completed at frame %d" % frames)
			break
		site = simulation.construction_sites[0]
		var state_changed: bool = builder.state != prev_state
		if state_changed:
			print("frame=%d STATE %s -> %s pos=%s" % [frames, prev_state, builder.state, builder.global_position])
			prev_state = builder.state
		if frames % print_every == 0 or state_changed:
			var builder_power = simulation._building_power(site.node)
			var builder_count = simulation._builder_count(site.node)
			print("frame=%d builder_state=%s builder_pos=%s progress=%.3f delivered=%s reserved=%s power=%.2f count=%d tasks=%d" % [
				frames,
				builder.state,
				builder.global_position,
				site.progress,
				site.delivered_materials,
				site.reserved_materials,
				builder_power,
				builder_count,
				simulation.courier_dispatcher.available_tasks().size()
			])
			if builder.state == 56: # AI_MOVING
				print("  ai_target=%s ai_arrived=%s ai_failed=%s route_reachable=%s" % [builder.ai_move_target, builder.ai_move_arrived, builder.ai_move_failed, simulation._is_route_reachable(builder.global_position, builder.ai_move_target, false)])
			elif builder.state == 13: # CONSTRUCTING
				print("  construction_pos=%s dist_to_pos=%.3f" % [builder.construction_position, builder.global_position.distance_to(builder.construction_position)])

	print("done frames=%d" % frames)
	var key = StringName("construction:12:12")
	var target = simulation._ai_target_for_key(key)
	print("target_key=%s target_valid=%s" % [key, is_instance_valid(target)])
	builder.idle()
	var exec_ok = builder.execute_action(&"construction", target, null)
	print("manual execute_action result=%s state=%s" % [exec_ok, builder.state])
	root.remove_child(simulation)
	simulation.free()
	quit(0)
