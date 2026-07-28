class_name OverlayNavigationPublisher
extends RefCounted

## Pushes active-zone overlay effects into the navigation grid
## (active_zones.md §4.2, §18).
##
## The single write owner of `NavGrid._overlay_cell_weights`, the same way
## `TerrainNavigationPublisher` owns the terrain field: nothing else may set the
## overlay weights, or the two would race on a map whose zones change after the
## session started. The map editor's authoring loop republishes here too, so the
## author sees a freshly-priced route the moment a forest rectangle lands.
##
## What this publisher is deliberately *not*: it does not touch passability. A
## `deny` for a visitor is a planning-time filter, not a wall (§4.1), and
## `vision`/`conceal` have nothing to do with movement at all. Only `cost`
## reaches the grid here; the others wait for a consumer that computes
## visibility, which does not exist yet.

var _overlay_index: ZoneOverlayIndex = null
var _nav_grid: NavGrid = null


func configure(overlay_index: ZoneOverlayIndex, nav_grid: NavGrid) -> void:
	_overlay_index = overlay_index
	_nav_grid = nav_grid


## Rebuilds the index from the layer and pushes every cell's combined cost into
## the grid. Call once at session start, after the terrain publisher — the
## overlay multiplies the surface weight, so the surface must exist first.
func publish_all() -> void:
	if _overlay_index == null or _nav_grid == null:
		return
	_nav_grid.set_overlay_cell_weights(_overlay_index.cost_cells())
