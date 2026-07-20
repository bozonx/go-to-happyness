extends SceneTree

const TestDomainEconomyScript = preload("res://tests/domain/test_domain_economy.gd")
const TestDomainRoutingScript = preload("res://tests/domain/test_domain_routing.gd")
const TestDomainConstructionScript = preload("res://tests/domain/test_domain_construction.gd")
const TestDomainLogisticsScript = preload("res://tests/domain/test_domain_logistics.gd")


const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")


func _init() -> void:
	TestDomainEconomyScript.run_all()
	TestDomainRoutingScript.run_all()
	TestDomainConstructionScript.run_all()
	TestDomainLogisticsScript.run_all()
	_test_building_queue_multiple_entrances()
	_test_building_queue_keeps_assigned_entrance()
	_test_building_queue_keeps_ai_citizens()
	_test_construction_site_uses_building_entrance()
	quit(0)


func _test_building_queue_multiple_entrances() -> void:
	var registry := BuildingRegistry.new()
	var building := Node3D.new()
	building.position = Vector3(1.5, 0.0, 1.5)
	root.add_child(building)
	var first_entrance := Vector3(2.5, 0.0, 1.5)
	var second_entrance := Vector3(0.5, 0.0, 1.5)
	building.set_meta("service_positions", [first_entrance, second_entrance])
	building.set_meta("service_position", first_entrance)
	registry.reserve(Vector2i(1, 1), building.position, Vector2i.ONE)
	registry.attach_node(Vector2i(1, 1), building)
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var queues = BuildingQueueServiceScript.new()
	queues.configure(registry, grid)

	var alpha := Node3D.new()
	var beta := Node3D.new()
	root.add_child(alpha)
	root.add_child(beta)
	var alpha_result := queues.resolve(alpha, first_entrance)
	var beta_result := queues.resolve(beta, first_entrance)
	# Both wanted the same entrance; the second citizen should be balanced to the other.
	assert(alpha_result.is_head)
	assert(beta_result.position.is_equal_approx(second_entrance), "Second citizen should queue at the less loaded entrance")
	assert(beta_result.is_head, "The first arrival at an empty entrance should be its head")

	queues.release(alpha)
	queues.release(beta)
	alpha.free()
	beta.free()
	root.remove_child(building)
	building.free()


func _test_building_queue_keeps_assigned_entrance() -> void:
	var registry := BuildingRegistry.new()
	var building := Node3D.new()
	building.position = Vector3(1.5, 0.0, 1.5)
	root.add_child(building)
	var first_entrance := Vector3(2.5, 0.0, 1.5)
	var second_entrance := Vector3(0.5, 0.0, 1.5)
	building.set_meta("service_positions", [first_entrance, second_entrance])
	building.set_meta("service_position", first_entrance)
	registry.reserve(Vector2i(1, 1), building.position, Vector2i.ONE)
	registry.attach_node(Vector2i(1, 1), building)
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var queues = BuildingQueueServiceScript.new()
	queues.configure(registry, grid)

	var alpha := Node3D.new()
	var beta := Node3D.new()
	root.add_child(alpha)
	root.add_child(beta)
	queues.resolve(alpha, first_entrance)
	queues.resolve(beta, second_entrance)
	# Re-resolve should keep each citizen at their original entrance.
	var alpha_result := queues.resolve(alpha, first_entrance)
	var beta_result := queues.resolve(beta, second_entrance)
	assert(alpha_result.position.is_equal_approx(first_entrance))
	assert(beta_result.position.is_equal_approx(second_entrance))

	queues.release(alpha)
	queues.release(beta)
	alpha.free()
	beta.free()
	root.remove_child(building)
	building.free()


func _test_building_queue_keeps_ai_citizens() -> void:
	var registry := BuildingRegistry.new()
	var building := Node3D.new()
	building.position = Vector3(1.5, 0.0, 1.5)
	root.add_child(building)
	var entrance := Vector3(2.5, 0.0, 1.5)
	building.set_meta("service_position", entrance)
	registry.reserve(Vector2i(1, 1), building.position, Vector2i.ONE)
	registry.attach_node(Vector2i(1, 1), building)
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var queues = BuildingQueueServiceScript.new()
	queues.configure(registry, grid)

	var alive_ids: Array[int] = [1]
	queues.set_citizen_alive_checker(func(citizen_id: int) -> bool: return citizen_id in alive_ids)

	var citizen := Node3D.new()
	citizen.set_meta("ai_id", 1)
	root.add_child(citizen)
	var result: Dictionary = queues.resolve(citizen, entrance)
	assert(result.is_head, "AI citizen with small ai_id should be treated as a valid queue member")
	queues.release(citizen)
	citizen.free()
	root.remove_child(building)
	building.free()


func _test_construction_site_uses_building_entrance() -> void:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.workers_changed = func() -> void: pass
	runtime.navigation_changed = func() -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)

	var cell := Vector2i(2, 3)
	runtime.building_registry.reserve(cell, Vector3(2.0, 0.0, 3.0), Vector2i(5, 5))
	var site := service.start_site(cell, "campfire", Vector3(2.0, 0.0, 3.0))
	var expected_offsets := BuildingBlueprints.worker_entrance_offsets("campfire")
	assert(not expected_offsets.is_empty())
	var positions: Array = site.node.get_meta("service_positions")
	assert(positions.size() == expected_offsets.size(), "Construction site should expose the future building's worker entrances")
	# The service position should sit one cell outside the footprint, not inside it.
	for position in positions:
		assert(position is Vector3)
		var cell_position := Vector2i(floori(position.x), floori(position.z))
		assert(cell_position != cell, "Service position must be outside the building footprint")

	service.cancel_site(site.node)
	root.remove_child(scene_root)
	scene_root.free()
