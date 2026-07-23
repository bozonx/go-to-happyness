class_name BiomeLayout
extends Resource

## Immutable, biome-authored placement data. Mutable availability belongs to
## WorldResourceState and is never inferred from the presentation scene.

@export var tree_cells: Array[Vector2i] = []
@export var pond_cells: Array[Vector2i] = []
@export var starter_loot: Array[Resource] = []
