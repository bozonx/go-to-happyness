class_name TerrainAnchorService
extends RefCounted

## Pins the ground under placed buildings against the cascade
## (design_docs/engine/grid_terrain_system.md §4.4).
##
## `IS_ANCHOR` is one half of an invariant. The cascade has always honoured its
## half — reaching an anchored column refuses the whole operation instead of
## letting the ground subside under what is standing on it — but nothing in the
## game ever WROTE an anchor, so the rule protected nothing. This is the writer.
##
## It listens to `BuildingRegistry`, which is the single place a footprint is
## claimed and released. That matters more than it looks: an anchor written when a
## site is placed and forgotten when construction is cancelled would leave the
## board covered in invisible columns no brush can ever move again, and the author
## would have no way to find out why.
##
## Every write goes through `TerrainService`, never into the grid, so an anchor is
## part of a transaction and undo can see it — an anchor set behind the service's
## back is an anchor undo silently drops (§14).
##
## Anchors are counted, not flagged. Two adjacent buildings whose footprints touch
## the same column must both have to release it before it moves again; a plain
## boolean would let demolishing either one unpin ground the other still stands on.

var _terrain: TerrainService = null
var _registry: BuildingRegistry = null
## cell -> how many footprints currently claim it.
var _claims: Dictionary = {}


func configure(terrain: TerrainService, registry: BuildingRegistry) -> void:
	_release_all()
	_disconnect()
	_terrain = terrain
	_registry = registry
	if _registry == null:
		return
	_registry.footprint_reserved.connect(_on_footprint_reserved)
	_registry.footprint_released.connect(_on_footprint_released)
	# A registry that already holds records — a loaded save, a test that placed
	# before wiring — has to be caught up, or its ground stays unpinned forever.
	for record: BuildingRecord in _registry.records():
		_on_footprint_reserved(record)


func anchored_cell_count() -> int:
	return _claims.size()


func is_anchored(cell: Vector2i) -> bool:
	return _claims.has(cell)


## The columns a footprint stands on. The record's `center` is the middle of the
## building and its `footprint` is a whole number of cells, so the block runs from
## the centre outwards by half of it in each direction.
static func footprint_cells(record: BuildingRecord) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if record == null:
		return cells
	var half_x := float(record.footprint.x) * 0.5
	var half_z := float(record.footprint.y) * 0.5
	var first := Vector2i(floori(record.center.x - half_x), floori(record.center.z - half_z))
	for offset_z in maxi(record.footprint.y, 1):
		for offset_x in maxi(record.footprint.x, 1):
			cells.append(first + Vector2i(offset_x, offset_z))
	return cells


func _on_footprint_reserved(record: BuildingRecord) -> void:
	var fresh: Array[Vector2i] = []
	for cell: Vector2i in footprint_cells(record):
		var claims := int(_claims.get(cell, 0))
		_claims[cell] = claims + 1
		if claims == 0:
			fresh.append(cell)
	if not fresh.is_empty() and _terrain != null:
		_terrain.set_anchor(fresh, true)


func _on_footprint_released(record: BuildingRecord) -> void:
	var freed: Array[Vector2i] = []
	for cell: Vector2i in footprint_cells(record):
		var claims := int(_claims.get(cell, 0))
		if claims <= 0:
			continue
		if claims == 1:
			_claims.erase(cell)
			freed.append(cell)
		else:
			_claims[cell] = claims - 1
	if not freed.is_empty() and _terrain != null:
		_terrain.set_anchor(freed, false)


func _release_all() -> void:
	if _claims.is_empty():
		return
	if _terrain != null:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in _claims:
			cells.append(cell)
		_terrain.set_anchor(cells, false)
	_claims.clear()


func _disconnect() -> void:
	if _registry == null:
		return
	if _registry.footprint_reserved.is_connected(_on_footprint_reserved):
		_registry.footprint_reserved.disconnect(_on_footprint_reserved)
	if _registry.footprint_released.is_connected(_on_footprint_released):
		_registry.footprint_released.disconnect(_on_footprint_released)
