class_name SnowRestRule
extends RefCounted

## One physical answer shared by authoring and runtime accumulation. Snow needs
## a real, sufficiently level floor; frozen water supplies one, open water does
## not.
static func can_rest(terrain: TerrainGrid, water: WaterGrid, cell: Vector2i) -> bool:
	if terrain == null or not terrain.is_inside(cell) or terrain.is_hole(cell):
		return false
	if water != null and water.is_wet(terrain, cell) and not water.is_frozen(cell):
		return false
	return terrain.slope_class_at(cell) < SlopeCatalog.CLASS_VERY_STEEP
