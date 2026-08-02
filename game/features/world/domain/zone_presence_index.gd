class_name ZonePresenceIndex
extends RefCounted

## Cell-keyed view of every addressable area on a map (active_zones.md §14).
##
## The presence tracker needs one question per cell, answered in O(1): "which
## region/room footprints cover this cell?". This index answers it, the same way
## `ZoneOverlayIndex` answers "what does it cost to cross?". The two are parallel
## cell-keyed views over the same `MapZoneLayer`, rebuilt together when zones
## change.
##
## Only `room` and `region` areas are indexed. §14 is explicit: a presence event
## is published for an addressable area, not for a technical `overlay` — an
## overlay changes a calculation (cost, vision, access) but creates no second
## stream of scenario enters. Indexing overlays here would publish noise a rule
## author never asked for.

var _areas_at_cell: Dictionary = {} # Vector2i -> Array[StringName]


func clear() -> void:
	_areas_at_cell.clear()


## Rebuilds the index from the layer's addressable areas. Overlays are skipped:
## they are not presence sources. Rooms are included for completeness even
## though the first cut only tracks map regions, so a future building-room pass
## needs no change here.
func rebuild(zones: MapZoneLayer, board_cells: int) -> void:
	clear()
	for area in zones.areas:
		if area.is_overlay():
			continue
		for cell in area.footprint_cells():
			# Board cells are centred on the origin (`MapZoneLayer.is_board_cell`).
			if not MapZoneLayer.is_board_cell(cell, board_cells):
				continue
			var ids: Array = _areas_at_cell.get(cell, [])
			ids.append(area.id)
			_areas_at_cell[cell] = ids


## Area ids whose footprint covers the cell, in authoring order. Empty when the
## cell is outside every region/room — the tracker treats that as "exited all".
func areas_at(cell: Vector2i) -> Array[StringName]:
	var raw: Array = _areas_at_cell.get(cell, [])
	var typed: Array[StringName] = []
	for id in raw:
		typed.append(id)
	return typed
