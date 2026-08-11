class_name SettlementWorldState
extends RefCounted

## World-level mutable state: trees, dig sites, terrain cells, resource piles,
## outside workers, and citizen position tracking.
## Extracted from SettlementGame to reduce its field count.


var tree_cells: Dictionary[Vector2i, bool] = {}
var terrain_blocked_cells: Dictionary[Vector2i, bool] = {}
var navigation_blocked_cells: Dictionary[Vector2i, bool] = {}
var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary[Vector2i, Node3D] = {}
var gather_progress_labels: Dictionary[int, Node3D] = {}

var dig_sites: Array = []
var dig_cells: Dictionary = {}
var exhausted_dig_cells: Dictionary = {}

var outside_workers: Dictionary = {}
var last_citizen_positions: Dictionary = {}
## The previous board cell of each citizen, so the presence tracker can diff.
## Kept alongside `last_citizen_positions` because both are maintained in the
## same `guard_citizen_positions` pass; a separate tracker would re-walk every
## citizen to recompute what that pass already touches.
var last_citizen_cells: Dictionary = {}
var resource_piles: Array[ResourcePile] = []
