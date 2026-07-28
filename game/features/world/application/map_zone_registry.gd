class_name MapZoneRegistry
extends RefCounted

## Session-state of every authored zone on the map (active_zones.md §13).
##
## The map-side peer of `BuildingRuntimeState.zones`: where the building carries
## one `ZoneRuntimeState` per room on a node's meta, the map carries one
## `MapZoneRuntimeState` per region/overlay here, in memory. The split is the
## same — definition comes from the file (`MapZoneLayer`), session state lives in
## the party — only the storage differs, because a map has no per-zone node to
## hang meta off.
##
## The registry is the single owner of map-zone session state, the way
## `MapZoneLayer` is the single owner of its definition. `MapZoneService` is the
## facade rules will eventually call through; nothing else mutates this directly.

var _states: Dictionary = {} # zone_id (StringName) -> MapZoneRuntimeState
## The bus state mutations publish on (active_zones.md §14). Set by `configure`;
## null means mutations are silent, which is exactly what a save restore wants —
## replaying saved owner/flags onto a fresh build must not fire a stream of
## `owner_changed` events as if a player had just captured every zone.
var _bus: ZoneEventBus = null


func configure(bus: ZoneEventBus) -> void:
	_bus = bus


func clear() -> void:
	_states.clear()


## Builds session state for every area on the layer. Idempotent — a rebuild
## discards the previous session, which is correct for a fresh launch and wrong
## mid-session: once persistence exists, a save load will call `apply_session_state`
## after this rather than rebuild a second time.
func build_from(zones: MapZoneLayer) -> void:
	clear()
	for area in zones.areas:
		_states[area.id] = MapZoneRuntimeState.from_definition(area)


## Lays saved session state over the freshly-built definitions. Called by the
## save loader after `build_from`, so a re-authored map still owns the geometry
## while a player's captured regions and flags come back. Entries whose id no
## longer matches a zone are dropped: a definition that removed an address
## discards its state rather than resurrecting a zone the author deleted (§13).
func apply_session_state(snapshot: Array) -> void:
	for raw in snapshot:
		if not (raw is Dictionary):
			continue
		var zone_id := StringName(raw.get("id", &""))
		var s := state(zone_id)
		if s == null:
			continue
		s.apply_session_state(raw)


func state(zone_id: StringName) -> MapZoneRuntimeState:
	return _states.get(zone_id, null)


func owner_of(zone_id: StringName) -> StringName:
	var s := state(zone_id)
	return s.owner_tag if s != null else &""


func flag_of(zone_id: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var s := state(zone_id)
	return s.flag(key, fallback) if s != null else fallback


## Sets the owner of a zone, returning whether anything changed. A no-op (same
## owner, or a zone that does not exist) returns false and publishes nothing,
## so a re-applied capture does not fire a second `owner_changed`. A genuine
## change publishes on the bus — unless `_bus` is null, which is the restore
## path replaying saved state without claiming the player just captured it.
func set_owner(zone_id: StringName, owner_tag: StringName) -> bool:
	var s := state(zone_id)
	if s == null:
		return false
	if not s.set_owner(owner_tag):
		return false
	if _bus != null:
		_bus.dispatch(ZoneEvent.owner_changed(zone_id, owner_tag))
	return true


func set_flag(zone_id: StringName, key: StringName, value: Variant) -> bool:
	var s := state(zone_id)
	if s == null:
		return false
	if not s.set_flag(key, value):
		return false
	if _bus != null:
		_bus.dispatch(ZoneEvent.zone_flag_changed(zone_id, key, value))
	return true


func is_owned_by(zone_id: StringName, agent_tags: Array) -> bool:
	var s := state(zone_id)
	return s.is_owned_by(agent_tags) if s != null else false


## Session slice of every zone, in id order, for a future save. Geometry never
## leaves the file, so this is only `{id, owner, flags}` per zone. Stable order
## keeps a map saved twice without an edit byte-identical. Sort compares the ids
## as strings: `Array.sort()` on `StringName` is not lexicographic, so a plain
## sort would put `gate_yard` before `forest` and break the byte-identical claim.
func session_state_to_dict() -> Array:
	var ids: Array = _states.keys()
	ids.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var result: Array = []
	for id in ids:
		result.append((_states[id] as MapZoneRuntimeState).session_state_to_dict())
	return result
