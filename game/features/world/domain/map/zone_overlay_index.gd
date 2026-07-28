class_name ZoneOverlayIndex
extends RefCounted

## Cell-keyed view of every `overlay` area on a map (active_zones.md §4, §18).
##
## An overlay carries rights and effects over a rectangle footprint. Routing
## only wants two questions per cell, answered after combining every overlay
## that covers it: "what does it cost to cross?" and "is a visitor allowed?".
## This index answers both in O(1), so the navigation publisher can push the
## whole layer into `NavGrid` once at session start without scanning areas per
## route.
##
## Effects combine per §4.2 — cost multiplies, the others take the strongest —
## and rights combine per §7.4: any denial wins. Until a tag issuer exists
## (§12), the only audience the engine asks about is `visitor`, the default for
## every acting entity; `denies_visitor` is the visitor half of that, and a
## denial here will keep the route planner off the cell entirely.

var _cell_cost: Dictionary = {} # Vector2i -> float (combined cost multiplier)
var _cell_denies_visitor: Dictionary = {} # Vector2i -> bool


func clear() -> void:
	_cell_cost.clear()
	_cell_denies_visitor.clear()


## Rebuilds the index from the layer's overlay areas. Non-overlay areas are
## skipped: a `region` carries a name for rules, not a cost or a right.
func rebuild(zones: MapZoneLayer, board_cells: int) -> void:
	clear()
	for area in zones.areas:
		if not area.is_overlay():
			continue
		var denies := ZoneAccess.permits(area.allow, area.deny, ZoneAccess.AUDIENCE_VISITOR) == false
		var effect_cost := float(area.effects.get(ZoneEffects.KEY_COST, ZoneEffects.default_of(ZoneEffects.KEY_COST)))
		for cell in area.footprint_cells():
			if cell.x < 0 or cell.y < 0 or cell.x >= board_cells or cell.y >= board_cells:
				continue
			# Cost multiplies across overlapping overlays (§4.2); a neutral 1.0
			# from one of them changes nothing, which is why an overlay that only
			# sets rights still reads as no-cost.
			var combined := float(_cell_cost.get(cell, 1.0)) * effect_cost
			_cell_cost[cell] = combined
			if denies:
				_cell_denies_visitor[cell] = true


func cost_at(cell: Vector2i) -> float:
	return float(_cell_cost.get(cell, 1.0))


func denies_visitor(cell: Vector2i) -> bool:
	return _cell_denies_visitor.has(cell)


## Every cell with a non-neutral cost, for the publisher to push wholesale.
func cost_cells() -> Dictionary:
	return _cell_cost.duplicate()


## Every cell a visitor may not enter, for the planner to treat as planning-time
## walls (§4.1: a denial is not NavGrid passability, it is a per-agent filter).
func denied_visitor_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _cell_denies_visitor:
		cells.append(cell)
	return cells
