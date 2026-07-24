class_name ZoneAnchorRecord
extends RefCounted

## A single authored anchor inside a building blueprint. Anchors are the shared
## structure behind two authoring tiers (design_docs/content/
## modular_building_editor.md §3.4):
##   • tier 2 — slots: where a citizen stands to work/rest (counter, bed, desk,
##     fishing spot, storage tray). Positional; `capacity` is occupants (1) or,
##     for trays, storage units.
##   • tier 3 — routing zones: doors and transit stops used for pathing, not
##     occupation (visitor/service door, taxi/bus stop). May be world-level.
##
## The `role` field discriminates the two tiers. `owner_zone_id` links the anchor
## to its PlaceZoneRecord; it is empty for world-level routing points such as a
## bus stop on a street.

# Slot roles (tier 2). A citizen occupies the anchor and performs the action.
const ROLE_WORK := &"work"
const ROLE_COUNTER := &"counter"
const ROLE_RECEPTION := &"reception"
const ROLE_DESK := &"desk"
const ROLE_BED := &"bed"
const ROLE_REST := &"rest"
const ROLE_FISHING := &"fishing"
const ROLE_INPUT_TRAY := &"input_tray"
const ROLE_OUTPUT_TRAY := &"output_tray"

const SLOT_ROLES: Array[StringName] = [
	ROLE_WORK, ROLE_COUNTER, ROLE_RECEPTION, ROLE_DESK, ROLE_BED, ROLE_REST,
	ROLE_FISHING, ROLE_INPUT_TRAY, ROLE_OUTPUT_TRAY,
]

# Routing roles (tier 3). Citizens traverse or wait at the anchor; nobody works it.
const ROLE_VISITOR_DOOR := &"visitor_door"
const ROLE_SERVICE_DOOR := &"service_door"
const ROLE_TAXI_STOP := &"taxi_stop"
const ROLE_BUS_STOP := &"bus_stop"

const ROUTING_ROLES: Array[StringName] = [
	ROLE_VISITOR_DOOR, ROLE_SERVICE_DOOR, ROLE_TAXI_STOP, ROLE_BUS_STOP,
]

const TIER_SLOT := &"slot"
const TIER_ROUTING := &"routing"

var anchor_id: StringName = &"anchor_1"
## Place zone this anchor belongs to; empty means a world-level routing point.
var owner_zone_id: StringName = &""
var role: StringName = ROLE_WORK
var pos: Vector3 = Vector3.ZERO
var rot: Vector3 = Vector3.ZERO  ## degrees
## Occupants for slots (usually 1), storage units for trays.
var capacity: int = 1


func tier() -> StringName:
	return TIER_ROUTING if role in ROUTING_ROLES else TIER_SLOT


func is_routing() -> bool:
	return role in ROUTING_ROLES


func is_tray() -> bool:
	return role == ROLE_INPUT_TRAY or role == ROLE_OUTPUT_TRAY


## A slot a worker/visitor stands at (a slot that is not a storage tray).
func is_work_slot() -> bool:
	return not is_routing() and not is_tray()


func to_dict() -> Dictionary:
	return {
		"id": String(anchor_id),
		"owner": String(owner_zone_id),
		"role": String(role),
		"pos": [pos.x, pos.y, pos.z],
		"rot": [rot.x, rot.y, rot.z],
		"capacity": capacity,
	}


static func from_dict(data: Dictionary) -> ZoneAnchorRecord:
	var anchor := ZoneAnchorRecord.new()
	anchor.anchor_id = StringName(data.get("id", "anchor_1"))
	anchor.owner_zone_id = StringName(data.get("owner", ""))
	anchor.role = StringName(data.get("role", ROLE_WORK))
	anchor.pos = _arr_to_vec3(data.get("pos", []))
	anchor.rot = _arr_to_vec3(data.get("rot", []))
	anchor.capacity = int(data.get("capacity", 1))
	return anchor


static func roles_for_tier(tier_id: StringName) -> Array[StringName]:
	return ROUTING_ROLES if tier_id == TIER_ROUTING else SLOT_ROLES


static func role_display_name(anchor_role: StringName) -> String:
	match anchor_role:
		ROLE_WORK: return "Работа"
		ROLE_COUNTER: return "Прилавок"
		ROLE_RECEPTION: return "Ресепшен"
		ROLE_DESK: return "Рабочий стол"
		ROLE_BED: return "Кровать"
		ROLE_REST: return "Отдых"
		ROLE_FISHING: return "Рыбалка"
		ROLE_INPUT_TRAY: return "Поддон (вход)"
		ROLE_OUTPUT_TRAY: return "Поддон (выход)"
		ROLE_VISITOR_DOOR: return "Дверь для посетителей"
		ROLE_SERVICE_DOOR: return "Служебная дверь"
		ROLE_TAXI_STOP: return "Остановка такси"
		ROLE_BUS_STOP: return "Автобусная остановка"
		_: return String(anchor_role)


static func _arr_to_vec3(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
