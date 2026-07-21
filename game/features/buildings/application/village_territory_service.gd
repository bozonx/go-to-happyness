class_name VillageTerritoryService
extends RefCounted

## Application service that owns the village territory model and enforces
## placement rules based on territory membership.
##
## The service reads BuildingRegistry to track built campfires, houses and
## boundary posts, recalculates the territory on build/demolish, and provides
## can_place / placement_reason for the UI and placement pipeline.

const VillageTerritoryScript = preload("res://game/features/buildings/domain/village_territory.gd")

const REASON_OK := &"ok"
const REASON_OUTSIDE_TERRITORY := &"outside_territory"
const REASON_NO_FLAG := &"no_flag"
const REASON_NO_CAMPFIRE := &"no_campfire"
const REASON_CAMPFIRE_LIMIT := &"campfire_limit"
const REASON_FOREIGN_TERRITORY := &"foreign_territory"

var _territory: RefCounted = VillageTerritoryScript.new()
var _foreign_territories: Array[RefCounted] = []
var _building_registry: BuildingRegistry
var _era: int = 0


func configure(building_registry: BuildingRegistry, era: int) -> void:
	_building_registry = building_registry
	_era = era
	recalculate()


func set_era(era: int) -> void:
	_era = era


func territory() -> RefCounted:
	return _territory


func has_flag() -> bool:
	if _territory.has_flag():
		return true
	if _building_registry != null:
		for record in _building_registry.records():
			if is_instance_valid(record.node):
				var b_type := str(record.node.get_meta("building_type", ""))
				if BuildingCatalog.is_flag(b_type):
					return true
	return false


func has_campfire() -> bool:
	return _territory.has_campfire()


func campfire_count() -> int:
	return _territory.campfire_count()


func campfire_limit() -> int:
	return VillageTerritoryScript.campfire_limit_for_era(_era)


func can_place(building_type: String, cell: Vector2i, footprint := Vector2i.ONE) -> bool:
	return placement_reason(building_type, cell, footprint) == REASON_OK


func placement_reason(building_type: String, cell: Vector2i, footprint := Vector2i.ONE) -> StringName:
	if _footprint_overlaps_foreign(cell, footprint):
		return REASON_FOREIGN_TERRITORY

	if BuildingCatalog.is_flag(building_type):
		if has_flag():
			return REASON_CAMPFIRE_LIMIT
		if _anchor_overlaps_foreign(cell, building_type):
			return REASON_FOREIGN_TERRITORY
		return REASON_OK

	if BuildingCatalog.is_campfire(building_type):
		if _territory.campfire_count() >= campfire_limit():
			return REASON_CAMPFIRE_LIMIT
		if _territory.has_flag() and not _territory.has_campfire():
			if not _footprint_is_inside_territory(cell, footprint):
				return REASON_OUTSIDE_TERRITORY
			return REASON_OK
		if _territory.is_inside(cell):
			return REASON_OUTSIDE_TERRITORY
		if _anchor_overlaps_foreign(cell, building_type):
			return REASON_FOREIGN_TERRITORY
		return REASON_OK

	if building_type == "warehouse":
		if not _territory.has_campfire():
			if not _territory.has_flag():
				return REASON_NO_FLAG
			if not _footprint_is_inside_territory(cell, footprint):
				return REASON_OUTSIDE_TERRITORY
			return REASON_OK
		return REASON_OK

	if not BuildingCatalog.requires_village_area(building_type):
		return REASON_OK

	if not _territory.has_flag():
		return REASON_NO_FLAG
	if not _territory.has_campfire():
		return REASON_NO_CAMPFIRE
	if not _footprint_is_inside_territory(cell, footprint):
		return REASON_OUTSIDE_TERRITORY
	if BuildingCatalog.expands_village_area(building_type) and _anchor_overlaps_foreign(cell, building_type):
		return REASON_FOREIGN_TERRITORY
	return REASON_OK


func placement_message(reason: StringName) -> String:
	match reason:
		REASON_OUTSIDE_TERRITORY:
			return "Outside village territory."
		REASON_NO_FLAG:
			return "Build a settlement flag first."
		REASON_NO_CAMPFIRE:
			return "Build a campfire first."
		REASON_CAMPFIRE_LIMIT:
			return "Limit reached for this era."
		REASON_FOREIGN_TERRITORY:
			return "Foreign settlement territory."
		_:
			return ""


## Full recalculation from the building registry.
func recalculate() -> void:
	_territory.clear()
	if _building_registry == null:
		return
	for record in _building_registry.records():
		var building_type := str(record.node.get_meta("building_type", "")) if is_instance_valid(record.node) else ""
		if building_type.is_empty():
			continue
		if BuildingCatalog.expands_village_area(building_type) or BuildingCatalog.is_campfire(building_type):
			_territory.add_anchor(record.cell, building_type, record.footprint)


## Called when a building is completed (node attached and metas set).
func on_building_added(cell: Vector2i, building_type: String) -> void:
	if BuildingCatalog.expands_village_area(building_type) or BuildingCatalog.is_campfire(building_type):
		var record := _building_registry.record_at_cell(cell) if _building_registry != null else null
		var footprint := record.footprint if record != null else Vector2i.ONE
		_territory.add_anchor(cell, building_type, footprint)


## Called when a building is demolished.
func on_building_removed(cell: Vector2i) -> void:
	_territory.remove_anchor(cell)


func add_foreign_territory(territory: RefCounted) -> void:
	_foreign_territories.append(territory)


func clear_foreign_territories() -> void:
	_foreign_territories.clear()


func _is_in_foreign_territory(cell: Vector2i) -> bool:
	for foreign in _foreign_territories:
		if foreign.is_inside(cell):
			return true
	return false


func _anchor_overlaps_foreign(cell: Vector2i, building_type: String) -> bool:
	for foreign in _foreign_territories:
		if _territory.anchor_overlaps_cells(cell, building_type, foreign.cells()):
			return true
	return false


func _footprint_overlaps_foreign(center_cell: Vector2i, footprint: Vector2i) -> bool:
	for cell in _footprint_cells(center_cell, footprint):
		if _is_in_foreign_territory(cell):
			return true
	return false


func _footprint_is_inside_territory(center_cell: Vector2i, footprint: Vector2i) -> bool:
	for cell in _footprint_cells(center_cell, footprint):
		if not _territory.is_inside(cell):
			return false
	return true


func _footprint_cells(center_cell: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var min_x := center_cell.x - floori((footprint.x - 1) * 0.5)
	var min_y := center_cell.y - floori((footprint.y - 1) * 0.5)
	for x in range(min_x, min_x + footprint.x):
		for y in range(min_y, min_y + footprint.y):
			result.append(Vector2i(x, y))
	return result
