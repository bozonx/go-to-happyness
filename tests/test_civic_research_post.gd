extends SceneTree


func _init() -> void:
	var scene := load("res://game/bootstrap/settlement_game.tscn") as PackedScene
	var simulation := scene.instantiate()
	root.add_child(simulation)
	await process_frame
	await physics_frame

	var researcher: Citizen = simulation.citizens[1]
	var civic_post := Node3D.new()
	civic_post.position = researcher.global_position
	civic_post.set_meta("service_position", researcher.global_position)
	simulation.add_child(civic_post)
	simulation.campfire_node = civic_post
	simulation.selected_campfire = civic_post
	simulation.selected_builder = researcher

	simulation._assign_daily_order(researcher, "researcher")
	assert(researcher.daily_order_role == "researcher")
	assert(researcher.permanent_role.is_empty())

	var kitchen := Node3D.new()
	kitchen.set_meta("accepting_workers", true)
	simulation.add_child(kitchen)
	simulation.canteen = kitchen
	simulation.selected_building = kitchen
	simulation.selected_builder = simulation.citizens[2]
	simulation._assign_daily_order(simulation.citizens[2], "cook")
	assert(simulation.citizens[2].daily_order_role == "cook")
	assert(simulation.citizens[2].permanent_role.is_empty())
	simulation.citizens[2].clear_daily_order()
	simulation.selected_builder = researcher

	# The native service order owns the movement. Simulate its completed arrival
	# here and verify that only a resident physically at the post can be promoted.
	researcher.global_position = simulation._employment_center_position()
	researcher.assign_research_work(researcher.global_position)
	assert(simulation._get_available_researcher("construction") == researcher)

	simulation.settlement.complete_research("official")
	simulation._handle_civic_post_assignment()
	assert(researcher.permanent_role == "official")
	assert(researcher.employment_workplace == civic_post)
	assert(researcher.daily_order_role.is_empty())

	var replacement: Citizen = simulation.citizens[2]
	simulation.selected_builder = replacement
	simulation._set_selected_work_role("official")
	assert(replacement.permanent_role == "official")
	assert(replacement.employment_workplace == civic_post)

	print("Civic research post tests passed.")
	quit(0)
