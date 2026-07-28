class_name MapZoneRuntimeState
extends RefCounted

## Session-state of one map zone — the mutable half of §13.
##
## The definition (geometry, role, function) comes from `MapZoneLayer` and does
## not change in a session; only what the party mutates lives here. On the
## building side that includes slot reservations and assignments, but a map
## region owns no slots — it is a named place rules reference — so this class
## carries only the two things a region can be: owned, and flagged. That is
## enough for capture, rent, clearance counters and "who holds the tower".
##
## The shape mirrors `ZoneRuntimeState` deliberately: `is_owned_by` and the
## no-op setters are copied verbatim, so the relational `owner` audience (§12)
## resolves the same way for a map zone as for a building room. When a future
## block adds persistence, `session_state_to_dict` already produces the slice a
## save needs — `{id, owner, flags}` — and geometry never leaves the file.

var zone_id: StringName = &""
## One tag or empty: `faction:red`, `ai:17`, `player`. Changed only by a rule.
var owner_tag: StringName = &""
## Named booleans and counters a rule writes and the engine never interprets.
var flags: Dictionary = {}


static func from_definition(area: ZoneAreaRecord) -> MapZoneRuntimeState:
	var state := MapZoneRuntimeState.new()
	state.zone_id = area.id
	return state


## Lays saved owner/flags over the definition. Unknown keys are ignored, so a
## save from a newer build opens without error even if it carries state this
## build does not recognise. Used by the future persistence layer; called today
## only by tests that fix the shape.
func apply_session_state(data: Dictionary) -> void:
	owner_tag = StringName(data.get("owner", &""))
	var raw_flags: Variant = data.get("flags", {})
	flags = (raw_flags as Dictionary).duplicate(true) if raw_flags is Dictionary else {}


## Whether an agent carrying these tags counts as the owner of this zone. The
## `owner` audience is relational: it matches the zone's current owner rather
## than a fixed tag, which is what lets one piece of markup serve a private
## compound in an RPG and a capture point in a shooter.
func is_owned_by(agent_tags: Array) -> bool:
	return owner_tag != &"" and owner_tag in agent_tags


## Sets the owner, returning whether anything actually changed. The no-op guard
## lets the registry skip work — and, once an event bus exists, skip publishing
## a spurious `owner_changed`.
func set_owner(new_owner: StringName) -> bool:
	if owner_tag == new_owner:
		return false
	owner_tag = new_owner
	return true


func set_flag(key: StringName, value: Variant) -> bool:
	if flags.get(key) == value:
		return false
	flags[key] = value
	return true


func flag(key: StringName, fallback: Variant = null) -> Variant:
	return flags.get(key, fallback)


## The session slice a save stores: geometry never leaves the file. Mirrors
## `ZoneRuntimeState.session_state_to_dict`, minus the reservation/assignment
## keys a map region does not have.
func session_state_to_dict() -> Dictionary:
	return {
		"id": String(zone_id),
		"owner": String(owner_tag),
		"flags": flags.duplicate(true),
	}
