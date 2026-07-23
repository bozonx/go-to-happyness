class_name RoadNetworkService
extends RefCounted

## Owns completed constructed-road coverage. Construction may stage work in the
## buildings feature, but only this service publishes completed coverage to the
## routing grid. This gives roads one write-owner and one atomic nav update.

const RoadTypeScript = preload("res://game/features/routing/domain/road_type.gd")

var _grid: NavGrid
var _roads: Dictionary = {}


func configure(next_grid: NavGrid) -> void:
	_grid = next_grid
	_publish()


func complete_cells(cells: Array[Vector2i], road_type: StringName) -> bool:
	if not RoadTypeScript.is_known(road_type):
		return false
	var changed := false
	for cell in cells:
		if _roads.get(cell, StringName()) == road_type:
			continue
		_roads[cell] = road_type
		changed = true
	if changed:
		_publish()
	return changed


func remove_cells(cells: Array[Vector2i]) -> bool:
	var changed := false
	for cell in cells:
		if _roads.erase(cell):
			changed = true
	if changed:
		_publish()
	return changed


func road_type_at(cell: Vector2i) -> StringName:
	return _roads.get(cell, StringName())


func completed_roads() -> Dictionary:
	return _roads.duplicate()


func restore_completed_roads(next_roads: Dictionary) -> void:
	_roads.clear()
	for cell: Variant in next_roads:
		var road_type: Variant = next_roads[cell]
		if cell is Vector2i and road_type is StringName and RoadTypeScript.is_known(road_type):
			_roads[cell] = road_type
	_publish()


func _publish() -> void:
	if _grid == null:
		return
	var weights: Dictionary = {}
	for cell: Vector2i in _roads:
		weights[cell] = RoadTypeScript.traversal_weight(_roads[cell])
	_grid.set_road_cell_weights(weights)
