class_name MapSpawnGroup
extends RefCounted

## Where a party of a size nobody knew at authoring time appears
## (design_docs/engine/map_start.md §4.2).
##
## The thing this replaces is the rule that a map must carry exactly
## `population - 1` companion anchors. That rule made geometry own the party
## size: an author who drew three points capped the game at four settlers, and a
## player who asked for eight got a launch error about anchors they never saw.
##
## A group is authored places **plus** an area to grow into. Three nice spots by
## the fire still read as three nice spots; the fourth settler stands beside them
## instead of blocking the session.
##
## What a group deliberately does not know is *who* appears and *what they carry*
## (§4.4). The moment a point carries a loadout, the same companion stops being
## reusable between start options and the map starts owning class rules.

## Rings outward from the centre — the default, and what a camp looks like.
const FORMATION_LOOSE := &"loose"
## A single row along `facing`. For a column arriving at a gate.
const FORMATION_LINE := &"line"
## Two, on purpose (§4.2). `column`, `wedge` and `grid` each need their own
## algorithm on uneven ground and none of them is distinguishable from `loose` in
## a settlement. The list is open in the same way the function list is: a third
## value changes no format.
const FORMATIONS: Array[StringName] = [FORMATION_LOOSE, FORMATION_LINE]

## Grow the formation around the area centre. The default.
const FALLBACK_FORMATION := &"formation"
## Search outward for any passable cell. What a test run uses.
const FALLBACK_NEAREST := &"nearest_valid"
## Refuse the launch. For a map whose author means "these places or none".
const FALLBACK_FAIL := &"fail"
const FALLBACKS: Array[StringName] = [FALLBACK_FORMATION, FALLBACK_NEAREST, FALLBACK_FAIL]

const DEFAULT_SPACING := 1.5
const DEFAULT_CAPACITY := 12

## One authored place inside a group. `tags` is how a leader gets the spot the
## author meant for a leader without the engine learning what a leader is.
class Slot:
	extends RefCounted

	var id: StringName = &""
	var anchor_id: StringName = &""
	var tags: Array[StringName] = []
	var order := 0

	static func from_dict(source: Dictionary) -> Slot:
		var slot := Slot.new()
		slot.id = StringName(source.get("id", ""))
		slot.anchor_id = StringName(source.get("anchor", ""))
		for tag: Variant in source.get("tags", []):
			slot.tags.append(StringName(tag))
		slot.order = int(source.get("order", 0))
		return slot

	func to_dict() -> Dictionary:
		var result: Dictionary = {"id": String(id), "anchor": String(anchor_id), "order": order}
		if not tags.is_empty():
			result["tags"] = tags.map(func(tag: StringName) -> String: return String(tag))
		return result

	func has_tag(tag: StringName) -> bool:
		return tag in tags

## Tag of the slot the party leader takes, and of the member that takes it.
const TAG_LEADER := &"leader"

var id: StringName = &""
## Localised, as everything an author names is (§3.1): a dictionary of languages
## in the file itself, because a map has no string table of its own.
var name: Dictionary = {}
## Area the formation grows inside. Without one the group is its slots and no more.
var area_id: StringName = &""
var formation: StringName = FORMATION_LOOSE
## Minimum distance between members, in metres.
var spacing := DEFAULT_SPACING
## The author's ceiling — "I do not want more than twelve here". Not a promise
## that twelve fit: the clearing can be flooded after the number was typed (§4.3).
var capacity := DEFAULT_CAPACITY
## Bearing for slots that do not declare their own.
var facing := 0.0
## Who may be placed here at all. Empty means anyone.
var allowed_tags: Array[StringName] = []
var slots: Array[Slot] = []
var fallback: StringName = FALLBACK_FORMATION


static func from_dict(source: Dictionary) -> MapSpawnGroup:
	var group := MapSpawnGroup.new()
	group.id = StringName(source.get("id", ""))
	if source.get("name") is Dictionary:
		group.name = (source["name"] as Dictionary).duplicate()
	elif source.get("name") != null:
		group.name = {"ru": String(source["name"])}
	group.area_id = StringName(source.get("area", ""))
	group.formation = StringName(source.get("formation", FORMATION_LOOSE))
	if group.formation not in FORMATIONS:
		group.formation = FORMATION_LOOSE
	group.spacing = maxf(float(source.get("spacing", DEFAULT_SPACING)), 0.0)
	group.capacity = maxi(int(source.get("capacity", DEFAULT_CAPACITY)), 0)
	group.facing = float(source.get("facing", 0.0))
	for tag: Variant in source.get("allowed_tags", []):
		group.allowed_tags.append(StringName(tag))
	for raw_slot: Variant in source.get("slots", []):
		if raw_slot is Dictionary:
			group.slots.append(Slot.from_dict(raw_slot as Dictionary))
	group.fallback = StringName(source.get("fallback", FALLBACK_FORMATION))
	if group.fallback not in FALLBACKS:
		group.fallback = FALLBACK_FORMATION
	return group


func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": String(id),
		"formation": String(formation),
		"spacing": spacing,
		"capacity": capacity,
		"fallback": String(fallback),
	}
	if not name.is_empty():
		result["name"] = name.duplicate()
	if area_id != &"":
		result["area"] = String(area_id)
	if not is_zero_approx(facing):
		result["facing"] = facing
	if not allowed_tags.is_empty():
		result["allowed_tags"] = allowed_tags.map(func(tag: StringName) -> String: return String(tag))
	if not slots.is_empty():
		result["slots"] = slots.map(func(slot: Slot) -> Dictionary: return slot.to_dict())
	return result


## Slots in fill order. `order` is the contract, not the position in the array:
## sorting the list in an editor must not change where the second settler stands.
func ordered_slots() -> Array[Slot]:
	var sorted := slots.duplicate()
	sorted.sort_custom(func(left: Slot, right: Slot) -> bool: return left.order < right.order)
	var result: Array[Slot] = []
	for slot: Slot in sorted:
		result.append(slot)
	return result


func slot_with_tag(tag: StringName) -> Slot:
	for slot: Slot in ordered_slots():
		if slot.has_tag(tag):
			return slot
	return null


func display_name() -> String:
	return MapLocalizedText.read(name, String(id))


## Whether an agent carrying these tags may be placed here (§4.2).
func admits(tags: Array[StringName]) -> bool:
	if allowed_tags.is_empty():
		return true
	for tag: StringName in tags:
		if tag in allowed_tags:
			return true
	return false
