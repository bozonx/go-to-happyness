class_name ZoneAccess
extends RefCounted

## Permission masks for active zones (design_docs/engine/active_zones.md §4).
##
## One mechanism replaces every "forbidden zone" variant: standing behind the
## counter, staff-only storage, no-build areas, foreign territory, no vehicles.
## An area or a door carries `allow` / `deny` lists over *audiences*; a denial
## always wins over an allowance.
##
## A permission is **not** walkability. The cell stays traversable in NavGrid;
## the mask is applied to a concrete agent while planning, so staff walk through
## a cell a visitor may not enter.

## Audiences the engine itself knows. A pack may use its own tags (faction,
## species) — they are opaque labels here and are matched by string equality.
const AUDIENCE_VISITOR := &"visitor"
const AUDIENCE_STAFF := &"staff"
const AUDIENCE_OWNER := &"owner"
const AUDIENCE_BUILDER := &"builder"
const AUDIENCE_VEHICLE := &"vehicle"

const AUDIENCES: Array[StringName] = [
	AUDIENCE_VISITOR, AUDIENCE_STAFF, AUDIENCE_OWNER, AUDIENCE_BUILDER, AUDIENCE_VEHICLE,
]

## Wildcard usable in either list: `deny: ["*"]` closes the area to everyone.
const AUDIENCE_ANY := &"*"


## Resolves a mask for one audience. Deny wins; an explicit non-empty `allow`
## list turns the mask into a whitelist; an empty mask permits everyone.
static func permits(allow: Array[StringName], deny: Array[StringName], audience: StringName) -> bool:
	if AUDIENCE_ANY in deny or audience in deny:
		return false
	if allow.is_empty() or AUDIENCE_ANY in allow:
		return true
	return audience in allow


## Combines masks of several overlapping areas: any denial forbids entry.
static func permits_all(masks: Array, audience: StringName) -> bool:
	for mask in masks:
		if mask is Dictionary:
			var allow: Array[StringName] = mask.get("allow", [] as Array[StringName])
			var deny: Array[StringName] = mask.get("deny", [] as Array[StringName])
			if not permits(allow, deny, audience):
				return false
	return true


static func is_known_audience(audience: StringName) -> bool:
	return audience == AUDIENCE_ANY or audience in AUDIENCES


static func audience_display_name(audience: StringName) -> String:
	match audience:
		AUDIENCE_VISITOR: return "Посетитель"
		AUDIENCE_STAFF: return "Персонал"
		AUDIENCE_OWNER: return "Владелец"
		AUDIENCE_BUILDER: return "Строительство"
		AUDIENCE_VEHICLE: return "Транспорт"
		AUDIENCE_ANY: return "Все"
		_: return String(audience)


## Parses a JSON list of audience strings into a typed list.
static func parse_audiences(raw: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if raw is Array:
		for entry in raw:
			var audience := StringName(entry)
			if audience != &"" and audience not in result:
				result.append(audience)
	return result


static func audiences_to_json(audiences: Array[StringName]) -> Array:
	var result: Array = []
	for audience in audiences:
		result.append(String(audience))
	return result
