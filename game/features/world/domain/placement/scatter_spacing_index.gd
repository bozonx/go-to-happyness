class_name ScatterSpacingIndex
extends RefCounted

## Пространственный индекс минимального интервала массового наполнения.
## Интервал остаётся независимым для каждого архетипа, но измеряется по реальным
## XZ-позициям с учётом дробного смещения, а не квадратом клеток.

var _cell_size := 1.0
var _buckets: Dictionary = {}
var _maximum_spacing: Dictionary = {}
var _exclusive_cells: Dictionary = {}


func configure(cell_size: float) -> void:
	_cell_size = maxf(cell_size, 0.001)
	_buckets.clear()
	_maximum_spacing.clear()
	_exclusive_cells.clear()


func claim_exclusive_cell(cell: Vector2i) -> void:
	_exclusive_cells[cell] = true


func is_exclusive_cell_claimed(cell: Vector2i) -> bool:
	return _exclusive_cells.has(cell)


func add(
	archetype_id: StringName,
	record: MapScatterLayer.Record,
	minimum_metres := 0.0,
) -> void:
	var by_cell: Dictionary = _buckets.get(archetype_id, {})
	var key := _bucket_of(_position_of(record))
	var entries: Array = by_cell.get(key, [])
	entries.append({"position": _position_of(record), "spacing": maxf(minimum_metres, 0.0)})
	by_cell[key] = entries
	_buckets[archetype_id] = by_cell
	_maximum_spacing[archetype_id] = maxf(
		float(_maximum_spacing.get(archetype_id, 0.0)), minimum_metres)


func is_crowded(
	archetype_id: StringName,
	record: MapScatterLayer.Record,
	minimum_metres: float,
) -> bool:
	var by_cell: Dictionary = _buckets.get(archetype_id, {})
	if by_cell.is_empty():
		return false
	var position := _position_of(record)
	var search_metres := maxf(
		maxf(minimum_metres, 0.0), float(_maximum_spacing.get(archetype_id, 0.0)))
	var radius := maxi(0, int(ceilf(search_metres / _cell_size))) + 1
	var centre := _bucket_of(position)
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			for other: Dictionary in by_cell.get(centre + Vector2i(dx, dz), []):
				var required := maxf(minimum_metres, float(other.get("spacing", 0.0)))
				if position.distance_to(other.get("position", Vector2.ZERO)) < required - 0.0001:
					return true
	return false


func _position_of(record: MapScatterLayer.Record) -> Vector2:
	return (Vector2(record.cell) + record.offset) * _cell_size


func _bucket_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _cell_size), floori(position.y / _cell_size))
