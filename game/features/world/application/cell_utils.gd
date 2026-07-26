class_name CellUtils
extends RefCounted

## Shared utilities for cell arrays used by terrain and water services.


## Deduplicates and sorts a cell array in row-major order (y then x), so a patch
## is processed in the same order on every machine (§4.4 determinism).
static func sorted_unique(cells: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		seen[cell] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in seen:
		result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result
