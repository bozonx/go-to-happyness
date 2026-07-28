class_name ZonePresenceTracker
extends RefCounted

## Detects when an agent's cell enters or leaves an addressable area, and
## publishes `area_entered` / `area_exited` on the bus (active_zones.md §14).
##
## Fed once per tick by `guard_citizen_positions`, which already walks every
## citizen and tracks its previous position. The tracker keeps its own
## per-citizen membership set (the regions it currently stands in) and, on a
## cell change, diffs the new cell's areas against the old to find enters and
## exits. This is cheaper than re-scanning every region per citizen, and it is
## the one place presence is computed — never inside the registry, never inside
## the index.
##
## Tags: until a tag issuer exists (§12), every acting entity publishes with an
## empty tag set. The `area_entered` event still carries `ai_id`, which is what a
## rule needs to react; tags are an additive refinement, not a prerequisite.

var _index: ZonePresenceIndex = null
var _bus: ZoneEventBus = null
# ai_id -> Dictionary[StringName, bool] of currently-held area memberships.
var _memberships: Dictionary = {}


func configure(index: ZonePresenceIndex, bus: ZoneEventBus) -> void:
	_index = index
	_bus = bus


## Called when a citizen's cell has changed. Computes the enter/exit diff
## against the index and publishes one event per transition. Idempotent: a
## no-op move (same cell, or a cell with the same coverage) publishes nothing.
func on_citizen_cell_changed(ai_id: int, cell: Vector2i, tags: Array[StringName] = []) -> void:
	if _index == null or _bus == null:
		return
	var current: Dictionary = _memberships.get(ai_id, {})
	var next_ids := _index.areas_at(cell)
	var next: Dictionary = {}
	for id in next_ids:
		next[id] = true
	# Exits: in `current` but not in `next`. Order-stable over the membership set.
	var exited: Array = current.keys()
	exited.sort()
	for id in exited:
		if not next.has(id):
			_bus.dispatch(ZoneEvent.area_exited(id, ai_id, tags))
	# Enters: in `next` but not in `current`.
	var entered: Array = next.keys()
	entered.sort()
	for id in entered:
		if not current.has(id):
			_bus.dispatch(ZoneEvent.area_entered(id, ai_id, tags))
	if next.is_empty():
		_memberships.erase(ai_id)
	else:
		_memberships[ai_id] = next


## Drops a citizen's membership entirely (e.g. on death/leave), publishing exits
## for every area it still held. Without this a departed resident would stay
## "inside" a region forever.
func clear_citizen(ai_id: int, tags: Array[StringName] = []) -> void:
	if _bus == null:
		_memberships.erase(ai_id)
		return
	var current: Dictionary = _memberships.get(ai_id, {})
	var exited: Array = current.keys()
	exited.sort()
	for id in exited:
		_bus.dispatch(ZoneEvent.area_exited(id, ai_id, tags))
	_memberships.erase(ai_id)
