class_name WaterCollectorService
extends RefCounted

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func tick(delta: float) -> void:
	# Water stays in each basin until a resident carries it to storage.
	for collector in simulation.water_collectors:
		collector.accum += delta * float(collector.rate)
		while collector.accum >= 1.0 and int(collector.stored) < int(collector.capacity):
			collector.accum -= 1.0
			collector.stored = int(collector.stored) + 1


func reserve_dew_collector() -> Vector3:
	for collector in simulation.water_collectors:
		if int(collector.stored) <= 0:
			continue
		collector.stored = int(collector.stored) - 1
		var node: Node3D = collector.node
		return node.get_meta("service_position", node.global_position)
	return Vector3.INF


func has_collected_dew() -> bool:
	for collector in simulation.water_collectors:
		if int(collector.stored) > 0:
			return true
	return false
