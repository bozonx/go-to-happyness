class_name ActiveWorkZoneRecord
extends RefCounted

## One active work zone inside a building blueprint (design_docs/content/
## modular_building_editor.md §4). A zone gives part of a building a purpose:
## a profession + worker anchors, a trade post, a storage bay, housing, etc.
##
## Purely data + (de)serialization; no engine node types. Matches the
## `.gdbuilding.json` `work_zones[]` shape, extended with a `kind` field.

## Zone purpose. Drives which extra fields matter and how employment/AI will
## later consume the zone.
const KIND_WORKPLACE := &"workplace"  ## staffed by a profession (cook, seller, ...)
const KIND_CIVIC := &"civic"          ## campfire / town hall — official / researcher
const KIND_TRADE := &"trade"          ## market — trading, outside work
const KIND_STORAGE := &"storage"      ## warehouse bay — input/output trays only
const KIND_HOUSING := &"housing"      ## residence — sleeping capacity
const KIND_LEISURE := &"leisure"      ## recreation — visitors relax, see LEISURE_SUBTYPES
const KIND_SPECIAL := &"special"      ## non-work marker zone, see SPECIAL_SUBTYPES

const KINDS: Array[StringName] = [
	KIND_WORKPLACE, KIND_CIVIC, KIND_TRADE, KIND_STORAGE, KIND_HOUSING,
	KIND_LEISURE, KIND_SPECIAL,
]

## Recreation flavours for KIND_LEISURE. The subtype drives the kind of leisure
## need a visit satisfies and the ambience the building projects.
const LEISURE_SUBTYPES: Array[StringName] = [
	&"park", &"plaza", &"playground", &"sports_field", &"gym", &"cinema", &"theater",
]

## Marker roles for KIND_SPECIAL. `entrance_sign` designates a settlement gate
## landmark (a plain post or a triumphal arch — the geometry is up to the author).
const SPECIAL_SUBTYPES: Array[StringName] = [
	&"entrance_sign", &"monument", &"notice_board", &"flagpole",
]

var zone_id: StringName = &"zone_1"
var zone_name: String = "Зона"
var kind: StringName = KIND_WORKPLACE
## Optional flavour within a kind (LEISURE_SUBTYPES / SPECIAL_SUBTYPES). Empty
## for kinds that need no sub-classification.
var subtype: StringName = &""
var profession: StringName = &""
var max_workers: int = 1
## Cells occupied by the zone on the 1m authoring grid. This is intentionally
## independent from any future furniture snapping increment.
var cells: Array[Vector3i] = []

## Each anchor: { id: String, pos: Vector3, rot: Vector3 (deg), action: String }.
var work_anchors: Array[Dictionary] = []

## { "input": {pos: Vector3, capacity: int}, "output": {pos: Vector3, capacity: int} }.
## Either key may be absent.
var storage_trays: Dictionary = {}


func add_anchor(pos: Vector3, rot: Vector3 = Vector3.ZERO, action: String = "work") -> Dictionary:
	var anchor := {
		"id": "spot_%d" % (work_anchors.size() + 1),
		"pos": pos,
		"rot": rot,
		"action": action,
	}
	work_anchors.append(anchor)
	return anchor


func set_tray(slot: StringName, pos: Vector3, capacity: int) -> void:
	# slot is &"input" or &"output".
	storage_trays[String(slot)] = {"pos": pos, "capacity": capacity}


func to_dict() -> Dictionary:
	var anchors: Array = []
	for anchor in work_anchors:
		anchors.append({
			"id": anchor.get("id", ""),
			"pos": _vec3_to_arr(anchor.get("pos", Vector3.ZERO)),
			"rot": _vec3_to_arr(anchor.get("rot", Vector3.ZERO)),
			"action": anchor.get("action", "work"),
		})
	var trays: Dictionary = {}
	for slot in storage_trays.keys():
		var tray: Dictionary = storage_trays[slot]
		trays[slot] = {
			"pos": _vec3_to_arr(tray.get("pos", Vector3.ZERO)),
			"capacity": int(tray.get("capacity", 0)),
		}
	return {
		"id": String(zone_id),
		"name": zone_name,
		"kind": String(kind),
		"subtype": String(subtype),
		"profession_type": String(profession),
		"max_workers": max_workers,
		"cells": cells.map(func(cell: Vector3i): return [cell.x, cell.y, cell.z]),
		"work_anchors": anchors,
		"storage_trays": trays,
	}


static func from_dict(data: Dictionary) -> ActiveWorkZoneRecord:
	var zone := ActiveWorkZoneRecord.new()
	zone.zone_id = StringName(data.get("id", "zone_1"))
	zone.zone_name = String(data.get("name", "Зона"))
	zone.kind = StringName(data.get("kind", KIND_WORKPLACE))
	zone.subtype = StringName(data.get("subtype", ""))
	zone.profession = StringName(data.get("profession_type", ""))
	zone.max_workers = int(data.get("max_workers", 1))
	for raw_cell in data.get("cells", []):
		if raw_cell is Array and raw_cell.size() >= 3:
			zone.cells.append(Vector3i(int(raw_cell[0]), int(raw_cell[1]), int(raw_cell[2])))
	for raw in data.get("work_anchors", []):
		if raw is Dictionary:
			zone.work_anchors.append({
				"id": String(raw.get("id", "spot")),
				"pos": _arr_to_vec3(raw.get("pos", [])),
				"rot": _arr_to_vec3(raw.get("rot", [])),
				"action": String(raw.get("action", "work")),
			})
	var raw_trays: Variant = data.get("storage_trays", {})
	if raw_trays is Dictionary:
		for slot in raw_trays.keys():
			var tray: Variant = raw_trays[slot]
			if tray is Dictionary:
				zone.storage_trays[String(slot)] = {
					"pos": _arr_to_vec3(tray.get("pos", [])),
					"capacity": int(tray.get("capacity", 0)),
				}
	return zone


func supports_role(role: StringName) -> bool:
	return profession == role and max_workers > 0 and kind in [KIND_WORKPLACE, KIND_CIVIC, KIND_TRADE]


static func kind_display_name(zone_kind: StringName) -> String:
	match zone_kind:
		KIND_WORKPLACE: return "Место работы"
		KIND_CIVIC: return "Гражданская (костёр/ратуша)"
		KIND_TRADE: return "Торговля / рынок"
		KIND_STORAGE: return "Склад"
		KIND_HOUSING: return "Жильё"
		KIND_LEISURE: return "Отдых / рекреация"
		KIND_SPECIAL: return "Особая зона"
		_: return String(zone_kind)


## Subtypes that apply to a kind, or an empty array when the kind is flat.
static func subtypes_for_kind(zone_kind: StringName) -> Array[StringName]:
	match zone_kind:
		KIND_LEISURE: return LEISURE_SUBTYPES
		KIND_SPECIAL: return SPECIAL_SUBTYPES
		_: return []


static func subtype_display_name(zone_subtype: StringName) -> String:
	match zone_subtype:
		&"park": return "Парк"
		&"plaza": return "Площадь"
		&"playground": return "Детская площадка"
		&"sports_field": return "Спортплощадка"
		&"gym": return "Спортзал"
		&"cinema": return "Кинотеатр"
		&"theater": return "Театр"
		&"entrance_sign": return "Въездной знак"
		&"monument": return "Монумент"
		&"notice_board": return "Доска объявлений"
		&"flagpole": return "Флагшток"
		_: return String(zone_subtype)


static func _vec3_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _arr_to_vec3(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
