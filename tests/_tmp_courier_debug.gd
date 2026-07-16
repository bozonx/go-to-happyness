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
		var brain := simulation.citizen_ai._brains.get(courier.ai_id) as CitizenBrain
		var active_goal := brain.runner.active_goal_id() if brain != null else &""
		var has_active_task := brain.runner.active_task != null if brain != null else false
		if frames <= 50 or frames % 100 == 0:
			var work_time: bool = simulation._is_work_time()
			var hour := int(simulation.clock.minutes) / 60
			var builder_dist := builder.global_position.distance_to(builder.construction_position)
			var courier_is_daily := courier.is_daily_courier()
			var courier_can_logistics := courier.can_handle_entry_logistics()
			var has_pending := brain.runner.pending_task != null if brain != null else false
			var suspended_count := brain.runner.suspended_count() if brain != null else 0
			var cd_courier := brain.blackboard.is_on_cooldown(&"courier_delivery", simulation.runtime_seconds) if brain != null else false
			var order: CitizenOrder = simulation.citizen_ai.director.order_board.order_for(courier.ai_id, simulation.runtime_seconds)
			var order_kind := str(order.kind) if order != null else "null"
			var order_priority: float = order.priority if order != null else -1.0
			var order_target: Vector3 = order.target_position if order != null else Vector3.INF
			var snapshot_tasks := simulation.citizen_ai.latest_snapshot.settlement.value(&"work.courier.tasks", []) as Array
			var snap_courier: CitizenSnapshot = simulation.citizen_ai.latest_snapshot.citizen(courier.ai_id)
			var snap_available: bool = snap_courier.is_available if snap_courier != null else false
			var snap_pc: bool = snap_courier.is_player_controlled if snap_courier != null else false
			print("frame=%d hour=%d work=%s site_prog=%.3f delivered=%s reserved=%s builder_state=%s builder_dist=%.2f courier_state=%s courier_pos=%s daily_courier=%s can_logistics=%s tasks=%d snap_tasks=%d active_goal=%s has_task=%s has_pending=%s suspended=%d cd_courier=%s order_kind=%s order_prio=%.2f target=%s snap_avail=%s snap_pc=%s" % [
				frames,
				hour,
				work_time,
				site.progress,
				site.delivered_materials,
				site.reserved_materials,
				builder.state,
				builder_dist,
				courier.state,
				courier.global_position,
				courier_is_daily,
				courier_can_logistics,
				simulation.courier_dispatcher.available_tasks().size(),
				snapshot_tasks.size(),
				active_goal,
				has_active_task,
				has_pending,
				suspended_count,
				cd_courier,
				order_kind,
				order_priority,
				order_target,
				snap_available,
				snap_pc
			])

	print("done frames=%d" % frames)
	root.remove_child(simulation)
	simulation.free()
	quit(0)
