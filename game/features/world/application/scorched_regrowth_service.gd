class_name ScorchedRegrowthService
extends RefCounted

## Turns burned ground back into ordinary grass through TerrainService. `scorched`
## deliberately has no hidden "former material" field: it represents a burned
## natural surface, and its stable, authored recovery target is grass.
##
## Call once per simulated day. The deterministic cell/day roll spreads recovery
## across the board instead of repainting every burned cell in one frame.

var service: TerrainService = null
var grid: TerrainGrid = null


func configure(next_service: TerrainService) -> void:
	service = next_service
	grid = null if service == null else service.get_grid()


func regrow_day(day: int, growth_rate: float) -> Array[Vector2i]:
	var restored: Array[Vector2i] = []
	if service == null or grid == null or growth_rate <= 0.0:
		return restored
	var chance := clampi(roundi(growth_rate * 1000.0), 0, 1000)
	for z in range(grid.min_cell().y, grid.max_cell().y + 1):
		for x in range(grid.min_cell().x, grid.max_cell().x + 1):
			var cell := Vector2i(x, z)
			if grid.material_of(cell) != TerrainMaterialCatalog.SCORCHED:
				continue
			if posmod(hash(Vector3i(x, z, day)), 1000) < chance:
				restored.append(cell)
	if restored.is_empty() or not service.paint_material(restored, TerrainMaterialCatalog.GRASS):
		return []
	return restored
