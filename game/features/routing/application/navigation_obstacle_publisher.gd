class_name NavigationObstaclePublisher
extends RefCounted

## Converts world-owned obstacle facts into the one blocked-cell set consumed by
## NavGrid. Bootstrap supplies facts; it no longer owns grid geometry policy.

var _grid: NavGrid
var _base_obstacles: Callable


func configure(next_grid: NavGrid, base_obstacles := Callable()) -> void:
	_grid = next_grid
	_base_obstacles = base_obstacles


func publish(terrain_blocked: Dictionary, building_records: Array, service_pockets: Array, clearance_margin: float) -> Dictionary:
	var blocked: Dictionary[Vector2i, bool] = {}
	if _base_obstacles.is_valid():
		var base: Dictionary = _base_obstacles.call()
		for cell: Vector2i in base:
			blocked[cell] = true
	for cell: Vector2i in terrain_blocked:
		blocked[cell] = true
	for record in building_records:
		var center: Vector3 = record.center
		var footprint: Vector2i = record.footprint
		var cell_size := _grid.cell_size if _grid != null else 1.0
		var min_x := floori((center.x - footprint.x * cell_size * 0.5 - clearance_margin) / cell_size)
		var max_x := ceili((center.x + footprint.x * cell_size * 0.5 + clearance_margin) / cell_size) - 1
		var min_z := floori((center.z - footprint.y * cell_size * 0.5 - clearance_margin) / cell_size)
		var max_z := ceili((center.z + footprint.y * cell_size * 0.5 + clearance_margin) / cell_size) - 1
		for x in range(min_x, max_x + 1):
			for z in range(min_z, max_z + 1):
				blocked[Vector2i(x, z)] = true
	for pocket in service_pockets:
		# Accept legacy dictionaries at this public routing boundary while all
		# bootstrap-owned pockets use ServicePocketRecord.
		if pocket is ServicePocketRecord and is_instance_valid(pocket.node):
			blocked.erase(pocket.cell)
		elif pocket is Dictionary and pocket.has("cell") and pocket.has("node") and is_instance_valid(pocket.node):
			blocked.erase(pocket.cell)
	if _grid != null:
		_grid.set_blocked_cells(blocked)
		_grid.refresh_connectivity()
	return blocked
