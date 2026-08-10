class_name HeroInteractionRuntimePort
extends RefCounted

## Explicit integration boundary for hero proximity queries against
## trees, sawmills, farms, water, grass, forage and rabbit sources.

var player_citizen_getter: Callable
var interaction_range: float
var tree_positions: Array[Vector3] = []
var tree_nodes: Dictionary = {}
var sawmill_positions: Array[Vector3] = []
var farm_positions: Array[Vector3] = []
var water_source_positions_getter: Callable
var grass_sources: Dictionary = {}
var forage_sources: Dictionary = {}
var bush_sources: Dictionary = {}
var rabbit_sources: Dictionary = {}
var cell_from_position: Callable
var consume_grass_source: Callable
