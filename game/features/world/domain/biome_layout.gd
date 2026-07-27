class_name BiomeLayout
extends Resource

## Immutable, biome-authored placement data. Mutable availability belongs to
## WorldResourceState and is never inferred from the presentation scene.

@export var tree_cells: Array[Vector2i] = []
## Seeds for the ponds a map-less session starts with. They are dug into the real
## terrain and filled from the real water layer by `StarterWater`, not spawned as
## props: water has one owner (grid_terrain_system.md §9).
@export var water_cells: Array[Vector2i] = []
@export var starter_loot: Array[Resource] = []
