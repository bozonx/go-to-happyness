class_name NavigationObstaclePublisher
extends RefCounted

## Converts world-owned obstacle facts into the one blocked-cell set consumed by
## NavGrid. Bootstrap supplies facts; it no longer owns grid geometry policy.

var _grid: NavGrid


func configure(next_grid: NavGrid) -> void:
	_grid = next_grid


func publish(terrain_blocked: Dictionary, building_records: Array, service_pockets: Array, clearance_margin: float) -> Dictionary:
	var blocked := terrain_blocked.duplicate()
	for record in building_records:
		var center: Vector3 = record.center
		var footprint: Vector2i = record.footprint
		var min_x := floori(center.x - footprint.x * 0.5 - clearance_margin)
		var max_x := ceili(center.x + footprint.x * 0.5 + clearance_margin) - 1
		var min_z := floori(center.z - footprint.y * 0.5 - clearance_margin)
		var max_z := ceili(center.z + footprint.y * 0.5 + clearance_margin) - 1
		for x in range(min_x, max_x + 1):
			for z in range(min_z, max_z + 1):
				blocked[Vector2i(x, z)] = true
	for pocket in service_pockets:
		if is_instance_valid(pocket.node):
			blocked.erase(pocket.cell)
	if _grid != null:
		_grid.set_blocked_cells(blocked)
		_grid.refresh_connectivity()
	return blocked
