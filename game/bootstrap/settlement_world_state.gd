class_name SettlementWorldState
extends RefCounted

## World-level mutable state: trees, dig sites, terrain cells, resource piles,
## backpack, outside workers, and citizen position tracking.
## Extracted from SettlementGame to reduce its field count.

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")

var tree_cells: Dictionary[Vector2i, bool] = {}
var terrain_blocked_cells: Dictionary[Vector2i, bool] = {}
var navigation_blocked_cells: Dictionary[Vector2i, bool] = {}
var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary[Vector2i, Node3D] = {}
var gather_progress_labels: Dictionary[Node3D, Node3D] = {}

var dig_sites: Array = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}

var backpack_node: Node3D
var backpack_position: Vector3

var outside_workers: Dictionary = {}
var last_citizen_positions: Dictionary = {}
var resource_piles: Array[ResourcePileScript] = []
