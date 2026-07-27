class_name ZoneAnchorRecord
extends RefCounted

## A **point** — one of the three active-zone primitives
## (design_docs/engine/active_zones.md §3, §5.2).
##
## One struct covers every point-shaped zone in both editors; `role` selects what
## the engine does with it. The role list is deliberately tiny and closed: what a
## point *means* comes from a pack, not from a new enum entry.
##
## The previous model had nine occupancy roles (work, counter, reception, desk,
## bed, rest, fishing, …). They were never different engine behaviour — only a
## different pose and a different piece of furniture — so they collapse into
## `slot` plus `pose` and `activity`.
##
## `owner` links a point to its area; empty means a top-level point (a bus stop
## on a street, a spawn on a map).

## Portal in or out. The only authority on entrances — the board-level
## `entrance` fields the game consumes are derived from these.
const ROLE_DOOR := &"door"
## A point a unit occupies to act. Capacity is always one; reservation required.
const ROLE_SLOT := &"slot"
## A place in a queue leading to a slot.
const ROLE_QUEUE := &"queue"
## An intake / dispatch tray. A unit walks up to it but does not occupy it.
const ROLE_STORAGE := &"storage"
## Where something appears: hero, squad, NPC, animal, vehicle, loot.
const ROLE_SPAWN := &"spawn"
## A point a route or patrol strings together; inert on its own.
const ROLE_WAYPOINT := &"waypoint"
## Everything else point-shaped: stage, podium, viewpoint, start camera.
const ROLE_POI := &"poi"

const ROLES: Array[StringName] = [
	ROLE_DOOR, ROLE_SLOT, ROLE_QUEUE, ROLE_STORAGE, ROLE_SPAWN, ROLE_WAYPOINT, ROLE_POI,
]

## Roles a building author uses; the map editor offers the rest.
const BUILDING_ROLES: Array[StringName] = [
	ROLE_DOOR, ROLE_SLOT, ROLE_QUEUE, ROLE_STORAGE, ROLE_POI, ROLE_SPAWN,
]

# Poses of a `slot` — what the occupant's body does there.
const POSE_STAND := &"stand"
const POSE_SIT := &"sit"
const POSE_SLEEP := &"sleep"
const POSE_LEAN := &"lean"
const POSE_KNEEL := &"kneel"

const POSES: Array[StringName] = [POSE_STAND, POSE_SIT, POSE_SLEEP, POSE_LEAN, POSE_KNEEL]

# Direction of a `storage` point.
const DIRECTION_IN := &"in"
const DIRECTION_OUT := &"out"

const DIRECTIONS: Array[StringName] = [DIRECTION_IN, DIRECTION_OUT]

var id: StringName = &"anchor_1"
## Area this point belongs to; empty means a top-level point.
var owner_id: StringName = &""
var role: StringName = ROLE_SLOT
var pos: Vector3 = Vector3.ZERO
## Yaw in degrees. Points are placed on a grid, so one axis is enough — a slot
## facing up or rolled sideways is not a thing the engine can act on.
var facing: float = 0.0

## `slot` — body pose and the pack-defined activity performed there.
var pose: StringName = POSE_STAND
var activity: StringName = &""
## `slot` — the fixture operated from this point (`fixtures[].id`), if any.
var fixture_id: StringName = &""

## `door` — who may pass. See ZoneAccess.
var allow: Array[StringName] = []
var deny: Array[StringName] = []

## `storage` — intake or dispatch, and how many units it holds.
var direction: StringName = DIRECTION_IN
var capacity: int = 0

## `queue` — the slot this queue leads to, and the place in line (0 = head).
var target_id: StringName = &""
var index: int = 0

## `spawn` / `poi` — an opaque pack label (faction, species, "stage", "camera").
var tag: StringName = &""


func is_door() -> bool:
	return role == ROLE_DOOR


func is_slot() -> bool:
	return role == ROLE_SLOT


func is_storage() -> bool:
	return role == ROLE_STORAGE


func is_queue() -> bool:
	return role == ROLE_QUEUE


func permits(audience: StringName) -> bool:
	return ZoneAccess.permits(allow, deny, audience)


## Board cell the point sits in, for overlap and reachability checks.
func cell() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.z))


func to_dict() -> Dictionary:
	var data := {
		"id": String(id),
		"role": String(role),
		"pos": [pos.x, pos.y, pos.z],
	}
	if owner_id != &"":
		data["owner"] = String(owner_id)
	if not is_zero_approx(facing):
		data["facing"] = facing
	match role:
		ROLE_SLOT:
			if pose != POSE_STAND:
				data["pose"] = String(pose)
			if activity != &"":
				data["activity"] = String(activity)
			if fixture_id != &"":
				data["fixture"] = String(fixture_id)
		ROLE_DOOR:
			if not allow.is_empty():
				data["allow"] = ZoneAccess.audiences_to_json(allow)
			if not deny.is_empty():
				data["deny"] = ZoneAccess.audiences_to_json(deny)
		ROLE_STORAGE:
			data["direction"] = String(direction)
			data["capacity"] = capacity
		ROLE_QUEUE:
			data["target"] = String(target_id)
			data["index"] = index
		ROLE_SPAWN, ROLE_POI:
			if tag != &"":
				data["tag"] = String(tag)
	return data


static func from_dict(data: Dictionary) -> ZoneAnchorRecord:
	var anchor := ZoneAnchorRecord.new()
	anchor.id = StringName(data.get("id", "anchor_1"))
	anchor.owner_id = StringName(data.get("owner", ""))
	anchor.role = StringName(data.get("role", ROLE_SLOT))
	var raw_pos: Variant = data.get("pos", [])
	if raw_pos is Array and raw_pos.size() >= 3:
		anchor.pos = Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
	anchor.facing = float(data.get("facing", 0.0))
	anchor.pose = StringName(data.get("pose", POSE_STAND))
	anchor.activity = StringName(data.get("activity", ""))
	anchor.fixture_id = StringName(data.get("fixture", ""))
	anchor.allow = ZoneAccess.parse_audiences(data.get("allow", []))
	anchor.deny = ZoneAccess.parse_audiences(data.get("deny", []))
	anchor.direction = StringName(data.get("direction", DIRECTION_IN))
	anchor.capacity = int(data.get("capacity", 0))
	anchor.target_id = StringName(data.get("target", ""))
	anchor.index = int(data.get("index", 0))
	anchor.tag = StringName(data.get("tag", ""))
	return anchor


static func roles_for_editor(is_map_editor: bool) -> Array[StringName]:
	return ROLES if is_map_editor else BUILDING_ROLES


static func role_display_name(anchor_role: StringName) -> String:
	match anchor_role:
		ROLE_DOOR: return "Дверь"
		ROLE_SLOT: return "Место"
		ROLE_QUEUE: return "Очередь"
		ROLE_STORAGE: return "Поддон"
		ROLE_SPAWN: return "Появление"
		ROLE_WAYPOINT: return "Путевая точка"
		ROLE_POI: return "Точка интереса"
		_: return String(anchor_role)


static func pose_display_name(anchor_pose: StringName) -> String:
	match anchor_pose:
		POSE_STAND: return "Стоя"
		POSE_SIT: return "Сидя"
		POSE_SLEEP: return "Лёжа (сон)"
		POSE_LEAN: return "Прислонившись"
		POSE_KNEEL: return "На колене"
		_: return String(anchor_pose)


static func direction_display_name(anchor_direction: StringName) -> String:
	return "Приёмка" if anchor_direction == DIRECTION_IN else "Выдача"
