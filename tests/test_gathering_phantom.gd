extends SceneTree


class FakeSettlement extends RefCounted:
	func construction_gloves_available() -> bool:
		return false


class FakeGatheringSimulation extends Node:
	var settlement := FakeSettlement.new()
	var grass_sources: Dictionary = {}
	var consumed_count := 0

	func fire_smoke_work_multiplier(_position_on_board: Vector3) -> float:
		return 1.0

	func _cell_from_position(position: Vector3) -> Vector2i:
		return Vector2i(floori(position.x), floori(position.z))

	func _consume_grass_source(position: Vector3) -> int:
		var cell := _cell_from_position(position)
		if not grass_sources.has(cell):
			return 0
		var source: Dictionary = grass_sources[cell]
		if int(source.get("remaining", 0)) <= 0:
			return 0
		consumed_count += 1
		source.remaining = int(source.remaining) - 1
		if int(source.remaining) == 0:
			grass_sources.erase(cell)
		else:
			grass_sources[cell] = source
		return 1


func _init() -> void:
	var simulation := FakeGatheringSimulation.new()
	var citizen := Citizen.new()
	citizen.ai_id = 30
	citizen.simulation = simulation
	root.add_child(citizen)
	root.add_child(simulation)
	await process_frame

	var source_pos := Vector3(2.0, 0.0, 0.0)
	simulation.grass_sources[simulation._cell_from_position(source_pos)] = {"remaining": 1}
	citizen.gather_resource_type = "grass"
	citizen.gather_source_position = source_pos
	citizen.active_role = "gather_grass"
	citizen.state = Citizen.State.GATHERING
	citizen._start_task(0.0)
	citizen._process_gathering(1.0)
	assert(citizen.state == Citizen.State.TO_WAREHOUSE)
	assert(citizen.carried_amount == 2)
	assert(simulation.consumed_count == 1)

	citizen.state = Citizen.State.GATHERING
	citizen.carried_amount = 0
	citizen._start_task(0.0)
	citizen._process_gathering(1.0)
	assert(citizen.state == Citizen.State.IDLE)
	assert(citizen.carried_amount == 0)
	assert(simulation.consumed_count == 1)

	root.remove_child(citizen)
	root.remove_child(simulation)
	citizen.free()
	simulation.free()
	quit(0)
