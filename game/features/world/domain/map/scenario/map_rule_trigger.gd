class_name MapRuleTrigger
extends RefCounted

## The `when` of a rule: the one moment that makes the engine look at it
## (map_editor.md §10.2).
##
## The list below is short on purpose, and every entry is something the **host**
## already computes: presence on the zone event bus (`active_zones.md` §14),
## elapsed session time, a flag it owns, and the start of the session itself.
## A trigger the host cannot produce would be a promise the format cannot keep.
##
## A game publishes its own moments through `MapScenarioRuntime.publish`, and
## they arrive here as an unknown `kind` that matches by name. That is why an
## unrecognised kind round-trips instead of being dropped: `gth.settlement:era_reached`
## is a valid trigger in a settlement scenario and meaningless in a shooter, and
## neither map should be corrupted by the other's editor.

const SESSION_STARTED := &"session_started"
const AREA_ENTERED := &"area_entered"
const AREA_EXITED := &"area_exited"
const FLAG_CHANGED := &"flag_changed"
const ELAPSED := &"elapsed"

const BUILTIN_KINDS: Array[StringName] = [
	SESSION_STARTED, AREA_ENTERED, AREA_EXITED, FLAG_CHANGED, ELAPSED,
]

## Kinds that address a zone; the validator checks the reference exists.
const ZONE_KINDS: Array[StringName] = [AREA_ENTERED, AREA_EXITED]

var kind: StringName = SESSION_STARTED
## Area addressed by `area_entered` / `area_exited`.
var zone: StringName = &""
## Flag watched by `flag_changed`.
var flag: StringName = &""
## Seconds of session time for `elapsed`.
var seconds := 0.0
## Only presence events carry an actor; empty means "anyone".
var actor: StringName = &""
## Everything a future kind carries, kept verbatim.
var raw: Dictionary = {}


static func of(trigger_kind: StringName) -> MapRuleTrigger:
	var trigger := MapRuleTrigger.new()
	trigger.kind = trigger_kind
	return trigger


static func on_area_entered(zone_id: StringName) -> MapRuleTrigger:
	var trigger := of(AREA_ENTERED)
	trigger.zone = zone_id
	return trigger


static func after_seconds(delay: float) -> MapRuleTrigger:
	var trigger := of(ELAPSED)
	trigger.seconds = delay
	return trigger


static func from_dict(source: Dictionary) -> MapRuleTrigger:
	var trigger := MapRuleTrigger.new()
	trigger.raw = source.duplicate(true)
	trigger.kind = StringName(source.get("trigger", SESSION_STARTED))
	trigger.zone = StringName(source.get("zone", ""))
	trigger.flag = StringName(source.get("flag", ""))
	trigger.seconds = float(source.get("seconds", 0.0))
	trigger.actor = StringName(source.get("actor", ""))
	return trigger


func to_dict() -> Dictionary:
	if not is_builtin():
		return raw.duplicate(true)
	var result := {"trigger": String(kind)}
	if zone != &"":
		result["zone"] = String(zone)
	if flag != &"":
		result["flag"] = String(flag)
	if kind == ELAPSED:
		result["seconds"] = seconds
	if actor != &"":
		result["actor"] = String(actor)
	return result


func is_builtin() -> bool:
	return kind in BUILTIN_KINDS


func addresses_zone() -> bool:
	return kind in ZONE_KINDS


## Whether a published event matches this trigger. `payload` carries whatever the
## publisher knows: `zone`, `flag`, `actor`. A trigger that names a zone requires
## it; one that does not matches every zone, which is how "entered any region"
## is written.
func matches(event_kind: StringName, payload: Dictionary) -> bool:
	if event_kind != kind:
		return false
	if zone != &"" and StringName(payload.get("zone", "")) != zone:
		return false
	if flag != &"" and StringName(payload.get("flag", "")) != flag:
		return false
	if actor != &"" and StringName(payload.get("actor", "")) != actor:
		return false
	return true


func describe() -> String:
	match kind:
		SESSION_STARTED: return "старт сессии"
		AREA_ENTERED: return "вход в %s" % (zone if zone != &"" else &"любую область")
		AREA_EXITED: return "выход из %s" % (zone if zone != &"" else &"любой области")
		FLAG_CHANGED: return "изменение флага %s" % (flag if flag != &"" else &"любого")
		ELAPSED: return "через %.0f с" % seconds
	return String(kind)
