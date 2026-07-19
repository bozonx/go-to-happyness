class_name VillageTerritory
extends RefCounted

## Deterministic village territory model.
##
## A territory is the union of circular areas around anchors (campfire, houses,
## boundary posts). The territory is stored as a set of grid cells. All
## placement checks go through this model — there is no longer a simple
## fixed radius from the campfire.

const CAMPFIRE_RADII := {
	"campfire": 12.0,
	"campfire_lvl2": 14.0,
	"campfire_lvl3": 16.0,
	"earth_assembly": 18.0,
	"clay_lodge": 20.0,
	"wood_town_hall": 22.0,
	"stone_prefecture": 24.0,
	"brick_city_hall": 26.0,
}

const HOUSE_RADIUS := 8.0
const POST_RADIUS := 5.0

const CAMPFIRE_TYPES: Array[String] = [
	"campfire", "campfire_lvl2", "campfire_lvl3",
	"earth_assembly", "clay_lodge", "wood_town_hall",
	"stone_prefecture", "brick_city_hall",
]

const HOUSING_TYPES: Array[String] = [
	"tent", "straw_tent", "tarp_tent",
	"dugout", "earth_house", "clay_house", "stone_house",
	"house", "house_lvl2", "house_lvl3", "brick_house",
]

## Era-indexed campfire (settlement) limits.
# Era enum: TENT=0, EARTH=1, CLAY=2, WOOD=3, STONE=4, BRICK=5
const CAMPFIRE_LIMITS: Array[int] = [1, 2, 3, 4, 5, 6]


## A single anchor contributing a circular area to the territory.
class TerritoryAnchor:
	var cell: Vector2i
	var radius: float
	var building_type: String

	func _init(p_cell: Vector2i, p_radius: float, p_building_type: String) -> void:
		cell = p_cell
		radius = p_radius
		building_type = p_building_type


var _anchors: Array[TerritoryAnchor] = []
var _cells: Dictionary = {}


static func campfire_radius_for(building_type: String) -> float:
	return CAMPFIRE_RADII.get(building_type, CAMPFIRE_RADII["campfire"])


static func campfire_limit_for_era(era: int) -> int:
	if era < 0 or era >= CAMPFIRE_LIMITS.size():
		return 1
	return CAMPFIRE_LIMITS[era]


static func is_campfire_type(building_type: String) -> bool:
	return building_type in CAMPFIRE_TYPES


static func is_housing_type(building_type: String) -> bool:
	return building_type in HOUSING_TYPES


static func is_boundary_post_type(building_type: String) -> bool:
	return building_type == "boundary_post"


static func anchor_radius_for(building_type: String) -> float:
	if is_campfire_type(building_type):
		return campfire_radius_for(building_type)
	if is_housing_type(building_type):
		return HOUSE_RADIUS
	if is_boundary_post_type(building_type):
		return POST_RADIUS
	return 0.0


func add_anchor(cell: Vector2i, building_type: String) -> void:
	var radius := anchor_radius_for(building_type)
	if radius <= 0.0:
		return
	_anchors.append(TerritoryAnchor.new(cell, radius, building_type))
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
func anchor_overlaps_cells(cell: Vector2i, building_type: String, other_cells: Dictionary) -> bool:
	var radius := anchor_radius_for(building_type)
	if radius <= 0.0:
		return false
	for candidate in _circle_cells(cell, radius):
		if other_cells.has(candidate):
			return true
	return false


func anchor_count() -> int:
	return _anchors.size()


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
	# Houses and posts only extend an existing settlement. Once its final
	# campfire is gone, their anchors remain as buildings but do not create land.
	if not has_campfire():
		return
	for anchor in _anchors:
		_add_circle(anchor.cell, anchor.radius)


func _add_circle(center_cell: Vector2i, radius: float) -> void:
	for cell in _circle_cells(center_cell, radius):
		_cells[cell] = true


func _circle_cells(center_cell: Vector2i, radius: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cell_radius := ceili(radius)
	var center := Vector3(center_cell.x + 0.5, 0.0, center_cell.y + 0.5)
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for z in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, z)
			var cell_center := Vector3(x + 0.5, 0.0, z + 0.5)
			if cell_center.distance_to(center) <= radius:
				result.append(cell)
	return result
