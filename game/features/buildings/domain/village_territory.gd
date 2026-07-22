class_name VillageTerritory
extends RefCounted

## Deterministic village territory model.
##
## A territory is the union of circular areas around anchors (campfire, houses,
## boundary posts). The territory is stored as a set of grid cells. All
## placement checks go through this model — there is no longer a simple
## fixed radius from the campfire.

const BUILDING_RADIUS := 16.0

const FLAG_TYPES: Array[String] = ["settlement_flag"]

const CAMPFIRE_TYPES: Array[String] = BuildingTypes.CIVIC_TYPES

const HOUSING_TYPES: Array[String] = BuildingTypes.HOUSING_TYPES

## Era-indexed campfire (settlement) limits.
# Era enum: TENT=0, EARTH=1, CLAY=2, WOOD=3, STONE=4, BRICK=5
const CAMPFIRE_LIMITS: Array[int] = [1, 2, 3, 4, 5, 6]


## A single anchor contributing a circular area to the territory.
class TerritoryAnchor:
	var cell: Vector2i
	var radius: float
	var building_type: String
	var footprint: Vector2i

	func _init(p_cell: Vector2i, p_radius: float, p_building_type: String, p_footprint := Vector2i.ONE) -> void:
		cell = p_cell
		radius = p_radius
		building_type = p_building_type
		footprint = p_footprint


var _anchors: Array[TerritoryAnchor] = []
var _cells: Dictionary = {}


static func campfire_radius_for(_building_type: String) -> float:
	return BUILDING_RADIUS


static func campfire_limit_for_era(era: int) -> int:
	if era < 0 or era >= CAMPFIRE_LIMITS.size():
		return 1
	return CAMPFIRE_LIMITS[era]


static func is_flag_type(building_type: String) -> bool:
	return building_type in FLAG_TYPES


static func is_campfire_type(building_type: String) -> bool:
	return building_type in CAMPFIRE_TYPES


static func is_housing_type(building_type: String) -> bool:
	return building_type in HOUSING_TYPES


static func is_boundary_post_type(building_type: String) -> bool:
	return building_type == "boundary_post"


static func anchor_radius_for(building_type: String) -> float:
	if is_flag_type(building_type) or is_campfire_type(building_type) or is_housing_type(building_type) or is_boundary_post_type(building_type):
		return BUILDING_RADIUS
	return 0.0


func add_anchor(cell: Vector2i, building_type: String, footprint := Vector2i.ONE) -> void:
	var radius := anchor_radius_for(building_type)
	if radius <= 0.0:
		return
	_anchors.append(TerritoryAnchor.new(cell, radius, building_type, footprint))
	_recalculate()


func remove_anchor(cell: Vector2i) -> void:
	for i in range(_anchors.size() - 1, -1, -1):
		if _anchors[i].cell == cell:
			_anchors.remove_at(i)
	_recalculate()


func clear() -> void:
	_anchors.clear()
	_cells.clear()


func is_empty() -> bool:
	return _anchors.is_empty()


func is_inside(cell: Vector2i) -> bool:
	return _cells.has(cell)


func cells() -> Dictionary:
	return _cells.duplicate()


## Returns whether the area contributed by a prospective anchor intersects
## another territory. Used before committing an expanding building.
func anchor_overlaps_cells(cell: Vector2i, building_type: String, other_cells: Dictionary, footprint := Vector2i.ONE) -> bool:
	var radius := anchor_radius_for(building_type)
	if radius <= 0.0:
		return false
	for candidate in _circle_cells(cell, radius, footprint):
		if other_cells.has(candidate):
			return true
	return false


func anchor_count() -> int:
	return _anchors.size()


func has_flag() -> bool:
	for anchor in _anchors:
		if is_flag_type(anchor.building_type):
			return true
	return false


func has_campfire() -> bool:
	for anchor in _anchors:
		if is_campfire_type(anchor.building_type):
			return true
	return false


func campfire_count() -> int:
	var count := 0
	for anchor in _anchors:
		if is_campfire_type(anchor.building_type):
			count += 1
	return count


## Returns the set of cells forming the external perimeter of the territory.
func perimeter_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cells:
		var c: Vector2i = cell
		# A cell is on the perimeter if any orthogonal neighbour is outside.
		if not _cells.has(c + Vector2i(1, 0)) \
			or not _cells.has(c + Vector2i(-1, 0)) \
			or not _cells.has(c + Vector2i(0, 1)) \
			or not _cells.has(c + Vector2i(0, -1)):
			result.append(c)
	return result


func _recalculate() -> void:
	_cells.clear()
	var campfire_exists := has_campfire()
	var flag_exists := has_flag()
	if not campfire_exists and not flag_exists:
		return
	for anchor in _anchors:
		if campfire_exists or is_flag_type(anchor.building_type):
			_add_circle(anchor.cell, anchor.radius, anchor.footprint)


func _add_circle(center_cell: Vector2i, radius: float, footprint := Vector2i.ONE) -> void:
	for cell in _circle_cells(center_cell, radius, footprint):
		_cells[cell] = true


func _circle_cells(center_cell: Vector2i, radius: float, footprint := Vector2i.ONE) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var min_x := center_cell.x - floori((footprint.x - 1) * 0.5)
	var max_x := min_x + footprint.x - 1
	var min_z := center_cell.y - floori((footprint.y - 1) * 0.5)
	var max_z := min_z + footprint.y - 1

	var r_ceil := ceili(radius)
	for x in range(min_x - r_ceil, max_x + r_ceil + 1):
		for z in range(min_z - r_ceil, max_z + r_ceil + 1):
			var closest_x := clampi(x, min_x, max_x)
			var closest_z := clampi(z, min_z, max_z)
			var dx := float(x - closest_x)
			var dz := float(z - closest_z)
			if sqrt(dx * dx + dz * dz) <= radius:
				result.append(Vector2i(x, z))
	return result
