extends SceneTree


class FakeToiletSimulation extends Node:
	var nav_grid := NavGrid.new()
	var tree_positions: Array[Vector3] = []
	var grass_sources: Dictionary = {}
	var toilets: Array[Node3D] = []

	func _init() -> void:
		nav_grid.configure(1.0, 100)
		nav_grid.set_blocked_cells({})

	func get_toilets() -> Array[Node3D]:
		var valid: Array[Node3D] = []
		for toilet in toilets:
			if is_instance_valid(toilet):
				valid.append(toilet)
		return valid


func _test_toilet_candidates_prefer_toilets() -> void:
	var simulation := FakeToiletSimulation.new()
	root.add_child(simulation)
	await process_frame
	var toilet := Node3D.new()
	toilet.position = Vector3(5.0, 0.0, 5.0)
	toilet.set_meta("building_type", "toilet_earth")
	toilet.set_meta("service_position", Vector3(5.0, 0.0, 5.0))
	simulation.add_child(toilet)
	simulation.toilets.append(toilet)
	simulation.tree_positions.append(Vector3(10.0, 0.0, 0.0))
	var grass_node := Node3D.new()
	grass_node.position = Vector3.ZERO
	simulation.add_child(grass_node)
	simulation.grass_sources[Vector2i(0, 0)] = {"node": grass_node}
	var citizen := Citizen.new()
	citizen.ai_id = 1
	citizen.gender = "male"
	citizen.position = Vector3.ZERO
	simulation.add_child(citizen)
	var service := CitizenNeedsService.new()
	service.configure(simulation)
	var candidates := service.relief_candidates_for(citizen)
	assert(candidates.size() == 2)
	assert(candidates[0].get(&"kind") == &"toilet")
	root.remove_child(simulation)
	simulation.free()


func _test_toilet_candidates_by_gender() -> void:
	var simulation := FakeToiletSimulation.new()
	root.add_child(simulation)
	await process_frame
	simulation.tree_positions.append(Vector3(10.0, 0.0, 0.0))
	var grass_node := Node3D.new()
	grass_node.position = Vector3(-10.0, 0.0, 0.0)
	simulation.add_child(grass_node)
	simulation.grass_sources[Vector2i(-10, 0)] = {"node": grass_node}
	var service := CitizenNeedsService.new()
	service.configure(simulation)
	var male := Citizen.new()
	male.ai_id = 1
	male.gender = "male"
	male.position = Vector3.ZERO
	simulation.add_child(male)
	var male_candidates := service.relief_candidates_for(male)
	assert(male_candidates.size() == 2)
	assert(male_candidates[0].get(&"kind") == &"tree")
	assert(male_candidates[1].get(&"kind") == &"grass")
	var female := Citizen.new()
	female.ai_id = 2
	female.gender = "female"
	female.position = Vector3.ZERO
	simulation.add_child(female)
	var female_candidates := service.relief_candidates_for(female)
	assert(female_candidates.size() == 2)
	assert(female_candidates[0].get(&"kind") == &"grass")
	assert(female_candidates[1].get(&"kind") == &"tree")
	root.remove_child(simulation)
	simulation.free()


func _test_toilet_candidates_fall_back_after_demolition() -> void:
	var simulation := FakeToiletSimulation.new()
	root.add_child(simulation)
	await process_frame
	simulation.tree_positions.append(Vector3(10.0, 0.0, 0.0))
	var grass_node := Node3D.new()
	grass_node.position = Vector3(-10.0, 0.0, 0.0)
	simulation.add_child(grass_node)
	simulation.grass_sources[Vector2i(-10, 0)] = {"node": grass_node}
	var toilet := Node3D.new()
	toilet.position = Vector3(5.0, 0.0, 5.0)
	toilet.set_meta("building_type", "toilet_earth")
	toilet.set_meta("service_position", Vector3(5.0, 0.0, 5.0))
	simulation.add_child(toilet)
	simulation.toilets.append(toilet)
	var service := CitizenNeedsService.new()
	service.configure(simulation)
	var citizen := Citizen.new()
	citizen.ai_id = 1
	citizen.gender = "male"
	citizen.position = Vector3.ZERO
	simulation.add_child(citizen)
	var with_toilet := service.relief_candidates_for(citizen)
	assert(with_toilet.size() == 2)
	assert(with_toilet[0].get(&"kind") == &"toilet")
	# Demolish the toilet and invalidate the candidate cache.
	simulation.toilets.clear()
	simulation.nav_grid.set_blocked_cells({Vector2i(99, 99): true})
	simulation.nav_grid.set_blocked_cells({})
	var without_toilet := service.relief_candidates_for(citizen)
	assert(without_toilet.size() == 2)
	assert(without_toilet[0].get(&"kind") != &"toilet")
	assert(without_toilet[1].get(&"kind") != &"toilet")
	root.remove_child(simulation)
	simulation.free()


func _init() -> void:
	await _test_toilet_candidates_prefer_toilets()
	await _test_toilet_candidates_by_gender()
	await _test_toilet_candidates_fall_back_after_demolition()
	quit(0)
