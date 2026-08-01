class_name RoadNetworkService
extends RefCounted

## Owns completed constructed-road coverage. Construction may stage work in the
## buildings feature, but only this service publishes completed coverage to the
## routing grid. This gives roads one write-owner and one atomic nav update.
##
## What each surface costs and who may use it is a record in `CoverageCatalog`,
## never a branch here: this service knows that a cell has coverage, not what
## paving is made of. In a session the map seeds it once through
## `CoverageNavigationPublisher` (map_editor.md §5.2.3).
##
## Ids are normalised on entry, so a save written when coverage was `RoadType`
## (`stone`) and one written since (`core:stone`) name the same surface and
## compare equal.

## Emitted after the authoritative runtime state changed. World owns the visual
## CoverageLayer and mirrors only these cells; routing stays independent of the
## world feature and publishes the same transaction to NavGrid first.
signal coverage_changed(cells: Array[Vector2i])

const DEFAULT_DETAIL := 0

var _grid: NavGrid
var _roads: Dictionary = {}
var _details: Dictionary = {}


func configure(next_grid: NavGrid) -> void:
	_grid = next_grid
	_publish()


func complete_cells(
	cells: Array[Vector2i],
	road_type: StringName,
	current_era := -1,
	detail := DEFAULT_DETAIL,
) -> bool:
	var canonical := _canonical(road_type)
	if canonical == CoverageCatalog.NONE_ID \
			or (current_era >= 0 and current_era < CoverageCatalog.minimum_era(canonical)):
		return false
	var changed := false
	var changed_cells: Array[Vector2i] = []
	var next_detail := clampi(detail, 0, 255)
	for cell in cells:
		if _roads.get(cell, StringName()) == canonical and int(_details.get(cell, DEFAULT_DETAIL)) == next_detail:
			continue
		_roads[cell] = canonical
		_details[cell] = next_detail
		changed_cells.append(cell)
		changed = true
	if changed:
		_publish()
		coverage_changed.emit(changed_cells)
	return changed


func remove_cells(cells: Array[Vector2i]) -> bool:
	var changed := false
	var changed_cells: Array[Vector2i] = []
	for cell in cells:
		if _roads.erase(cell):
			_details.erase(cell)
			changed_cells.append(cell)
			changed = true
	if changed:
		_publish()
		coverage_changed.emit(changed_cells)
	return changed


func road_type_at(cell: Vector2i) -> StringName:
	return _roads.get(cell, StringName())


func road_detail_at(cell: Vector2i) -> int:
	return int(_details.get(cell, DEFAULT_DETAIL))


func road_weight_for_profile(cell: Vector2i, profile: StringName) -> float:
	var type := road_type_at(cell)
	if type.is_empty() or not CoverageCatalog.supports_profile(type, profile):
		return INF
	return CoverageCatalog.weight_of_id(type)


func completed_roads() -> Dictionary:
	return _roads.duplicate()


func export_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _roads:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell: Vector2i in cells:
		result.append({
			"x": cell.x,
			"y": cell.y,
			"type": str(_roads[cell]),
			"detail": road_detail_at(cell),
		})
	return result


func restore_state(entries: Array) -> void:
	var restored: Dictionary = {}
	var restored_details: Dictionary = {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var type := _canonical(StringName(str(entry.get("type", ""))))
		if type != CoverageCatalog.NONE_ID:
			var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
			restored[cell] = type
			restored_details[cell] = clampi(int(entry.get("detail", DEFAULT_DETAIL)), 0, 255)
	restore_completed_roads(restored, restored_details)


func restore_completed_roads(next_roads: Dictionary, next_details: Dictionary = {}) -> void:
	var previous_cells := _roads.keys()
	_roads.clear()
	_details.clear()
	for cell: Variant in next_roads:
		var road_type: Variant = next_roads[cell]
		if not (cell is Vector2i and road_type is StringName):
			continue
		var canonical := _canonical(road_type)
		if canonical != CoverageCatalog.NONE_ID:
			_roads[cell] = canonical
			_details[cell] = clampi(int(next_details.get(cell, DEFAULT_DETAIL)), 0, 255)
	_publish()
	var changed_set: Dictionary = {}
	for cell: Variant in previous_cells:
		if cell is Vector2i:
			changed_set[cell] = true
	for cell: Vector2i in _roads:
		changed_set[cell] = true
	var changed_cells: Array[Vector2i] = []
	for cell: Vector2i in changed_set:
		changed_cells.append(cell)
	changed_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	coverage_changed.emit(changed_cells)


func _publish() -> void:
	if _grid == null:
		return
	var weights_by_profile: Dictionary = {}
	var road_cells: Dictionary = {}
	for cell: Vector2i in _roads:
		var road_type: StringName = _roads[cell]
		road_cells[cell] = true
		for profile: TravelerProfile in TravelerProfile.registered_profiles():
			if not CoverageCatalog.supports_profile(road_type, profile.profile_id):
				continue
			var weights: Dictionary = weights_by_profile.get(profile.profile_id, {})
			weights[cell] = CoverageCatalog.weight_of_id(road_type)
			weights_by_profile[profile.profile_id] = weights
	_grid.set_road_profile_weights(weights_by_profile, road_cells)


## The catalog id a name resolves to, or `NONE_ID` when this build has no such
## surface — an uninstalled pack surface, or a typo in a hand-edited save.
static func _canonical(road_type: StringName) -> StringName:
	var index := CoverageCatalog.index_of_id(road_type)
	return CoverageCatalog.id_of_index(index)
