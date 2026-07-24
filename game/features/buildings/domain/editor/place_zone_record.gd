class_name PlaceZoneRecord
extends RefCounted

## Tier-1 active zone: the identity of a place inside a building — a whole house,
## a shop or warehouse room in a mall, a housing unit, a leisure spot. This is the
## zone the player clicks to open the building menu (design_docs/content/
## modular_building_editor.md §3.4).
##
## Employment capacity (profession + max_workers) lives here. Where workers
## actually stand is authored separately as ZoneAnchorRecord slots that reference
## this zone by id; with no slots, occupancy points fall back to `cells`.

## Zone purpose. Only workplace/civic/trade grant employment.
const KIND_WORKPLACE := &"workplace"  ## staffed by a profession (cook, seller, ...)
const KIND_CIVIC := &"civic"          ## campfire / town hall — official / researcher
const KIND_TRADE := &"trade"          ## market — trading, outside work
const KIND_STORAGE := &"storage"      ## warehouse room — trays only
const KIND_HOUSING := &"housing"      ## residence — sleeping capacity
const KIND_LEISURE := &"leisure"      ## recreation — visitors relax, see LEISURE_SUBTYPES
const KIND_SPECIAL := &"special"      ## non-work marker place, see SPECIAL_SUBTYPES

const KINDS: Array[StringName] = [
	KIND_WORKPLACE, KIND_CIVIC, KIND_TRADE, KIND_STORAGE, KIND_HOUSING,
	KIND_LEISURE, KIND_SPECIAL,
]

## Kinds that staff a profession and can be assigned workers.
const STAFFED_KINDS: Array[StringName] = [KIND_WORKPLACE, KIND_CIVIC, KIND_TRADE]

## Recreation flavours for KIND_LEISURE. The subtype drives which leisure need a
## visit satisfies and the ambience the place projects.
const LEISURE_SUBTYPES: Array[StringName] = [
	&"park", &"plaza", &"playground", &"sports_field", &"gym", &"cinema", &"theater",
]

## Marker roles for KIND_SPECIAL. `entrance_sign` designates a settlement gate
## landmark (a plain post or a triumphal arch — the geometry is up to the author).
const SPECIAL_SUBTYPES: Array[StringName] = [
	&"entrance_sign", &"monument", &"notice_board", &"flagpole",
]

var zone_id: StringName = &"place_1"
var zone_name: String = "Место"
var kind: StringName = KIND_WORKPLACE
## Optional flavour within a kind (LEISURE_SUBTYPES / SPECIAL_SUBTYPES). Empty
## for kinds that need no sub-classification.
var subtype: StringName = &""
var profession: StringName = &""
var max_workers: int = 1
## Cells occupied by the place on the 1m authoring grid. Doubles as the fallback
## occupancy area when the place has no authored work slots.
var cells: Array[Vector3i] = []


func supports_role(role: StringName) -> bool:
	return profession == role and max_workers > 0 and kind in STAFFED_KINDS


func to_dict() -> Dictionary:
	return {
		"id": String(zone_id),
		"name": zone_name,
		"kind": String(kind),
		"subtype": String(subtype),
		"profession_type": String(profession),
		"max_workers": max_workers,
		"cells": cells.map(func(cell: Vector3i): return [cell.x, cell.y, cell.z]),
	}


static func from_dict(data: Dictionary) -> PlaceZoneRecord:
	var zone := PlaceZoneRecord.new()
	zone.zone_id = StringName(data.get("id", "place_1"))
	zone.zone_name = String(data.get("name", "Место"))
	zone.kind = StringName(data.get("kind", KIND_WORKPLACE))
	zone.subtype = StringName(data.get("subtype", ""))
	zone.profession = StringName(data.get("profession_type", ""))
	zone.max_workers = int(data.get("max_workers", 1))
	for raw_cell in data.get("cells", []):
		if raw_cell is Array and raw_cell.size() >= 3:
			zone.cells.append(Vector3i(int(raw_cell[0]), int(raw_cell[1]), int(raw_cell[2])))
	return zone


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
