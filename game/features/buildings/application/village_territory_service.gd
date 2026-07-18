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


func has_campfire() -> bool:
	return _territory.has_campfire()


func campfire_count() -> int:
	return _territory.campfire_count()


func campfire_limit() -> int:
	return VillageTerritoryScript.campfire_limit_for_era(_era)


func can_place(building_type: String, cell: Vector2i) -> bool:
	return placement_reason(building_type, cell) == REASON_OK


func placement_reason(building_type: String, cell: Vector2i) -> StringName:
	# Warehouse and campfire do not require existing territory.
	if BuildingCatalog.is_campfire(building_type):
		if _territory.campfire_count() >= campfire_limit():
			return REASON_CAMPFIRE_LIMIT
		# New campfire must be outside existing territory (new settlement).
		if _territory.is_inside(cell):
			return REASON_OUTSIDE_TERRITORY
		# New campfire must not overlap foreign territory.
		if _is_in_foreign_territory(cell):
			return REASON_FOREIGN_TERRITORY
		return REASON_OK

	if not BuildingCatalog.requires_village_area(building_type):
		# Warehouse: can be placed anywhere, but not in foreign territory.
		if _is_in_foreign_territory(cell):
			return REASON_FOREIGN_TERRITORY
		return REASON_OK

	# Buildings that require village area: must be inside territory.
	if not _territory.has_campfire():
		return REASON_NO_CAMPFIRE
	if not _territory.is_inside(cell):
		return REASON_OUTSIDE_TERRITORY
	if _is_in_foreign_territory(cell):
		return REASON_FOREIGN_TERRITORY
	return REASON_OK


func placement_message(reason: StringName) -> String:
	match reason:
		REASON_OUTSIDE_TERRITORY:
			return "Outside village territory."
		REASON_NO_CAMPFIRE:
			return "Build a campfire first."
		REASON_CAMPFIRE_LIMIT:
			return "Campfire limit reached for this era."
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
			_territory.add_anchor(record.cell, building_type)


## Called when a building is completed (node attached and metas set).
func on_building_added(cell: Vector2i, building_type: String) -> void:
	if BuildingCatalog.expands_village_area(building_type) or BuildingCatalog.is_campfire(building_type):
		_territory.add_anchor(cell, building_type)


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
