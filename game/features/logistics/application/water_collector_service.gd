class_name WaterCollectorService
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func _collectors() -> Array:
	if simulation.has_meta("water_collectors"):
		return simulation.get_meta("water_collectors")
	return simulation.water_collectors


func tick(delta: float) -> void:
	# Water stays in each basin until a resident carries it to storage.
	for collector in _collectors():
		collector.accum += delta * float(collector.rate)
		while collector.accum >= 1.0 and int(collector.stored) < int(collector.capacity):
			collector.accum -= 1.0
			collector.stored = int(collector.stored) + 1


func _service_position(node: Node3D) -> Vector3:
	if node.has_meta("service_position"):
		return node.get_meta("service_position")
	return node.global_position


func stored_at(position: Vector3) -> int:
	for collector in _collectors():
		var node: Node3D = collector.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		if _service_position(node).is_equal_approx(position):
			return int(collector.get("stored", 0))
	return 0


func collect_water(position: Vector3, max_amount: int) -> int:
	for collector in _collectors():
		var node: Node3D = collector.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		if not _service_position(node).is_equal_approx(position):
			continue
		var available: int = int(collector.stored)
		var taken: int = mini(available, maxi(max_amount, 0))
		if taken > 0:
			collector.stored = available - taken
		return taken
	return 0


func return_water(position: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	for collector in _collectors():
		var node: Node3D = collector.get("node") as Node3D
		if is_instance_valid(node) and _service_position(node).is_equal_approx(position):
			collector.stored = int(collector.get("stored", 0)) + amount
			return
