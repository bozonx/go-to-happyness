class_name WaterCollectorService
extends RefCounted

const WaterCollectorRecord = preload("res://game/features/logistics/domain/water_collector_record.gd")

var _collectors_array: Array[WaterCollectorRecord] = []


func configure(collectors: Array[WaterCollectorRecord]) -> void:
	_collectors_array = collectors


func _collectors() -> Array[WaterCollectorRecord]:
	return _collectors_array


func tick(delta: float) -> void:
	# Water stays in each basin until a resident carries it to storage.
	for collector in _collectors():
		collector.accum += delta * collector.rate
		while collector.accum >= 1.0 and collector.stored < collector.capacity:
			collector.accum -= 1.0
			collector.stored += 1


func _service_position(node: Node3D) -> Vector3:
	if node.has_meta("service_position"):
		return node.get_meta("service_position")
	return node.global_position


func stored_at(position: Vector3) -> int:
	for collector in _collectors():
		if not is_instance_valid(collector.node):
			continue
		if _service_position(collector.node).is_equal_approx(position):
			return collector.stored
	return 0


func collect_water(position: Vector3, max_amount: int) -> int:
	for collector in _collectors():
		if not is_instance_valid(collector.node):
			continue
		if not _service_position(collector.node).is_equal_approx(position):
			continue
		var taken: int = mini(collector.stored, maxi(max_amount, 0))
		if taken > 0:
			collector.stored -= taken
		return taken
	return 0


func return_water(position: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	for collector in _collectors():
		if is_instance_valid(collector.node) and _service_position(collector.node).is_equal_approx(position):
			collector.stored += amount
			return
