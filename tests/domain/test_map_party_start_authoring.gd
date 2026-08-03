class_name TestMapPartyStartAuthoring
extends RefCounted

## Domain tests for the gesture that makes a map launchable (`map_start.md` §4.2).
##
## The bug these exist for: a spawn group and an entrance were readable, writable
## and validated, but authorable nowhere — `MapSpawnGroup` had exactly one caller,
## the v7→v8 migration. So placing the party's start point produced a map the
## editor accepted and the launch refused, and no gesture in the editor could fix
## it. Every case below is "the author put a point down; is the map launchable
## now?".


static func run_all() -> void:
	_test_the_first_party_point_builds_the_group_and_the_entrance()
	_test_a_second_party_point_joins_the_group_it_found()
	_test_an_authored_multi_group_map_is_left_alone()
	_test_a_non_party_point_builds_nothing()
	_test_deleting_the_last_party_point_takes_the_group_with_it()
	_test_renaming_a_point_follows_into_the_slot()
	_test_the_built_map_passes_the_launch_gate()
	print("    [PASS] Map Party Start Authoring Tests")


static func _document() -> MapDocument:
	return MapDocument.create(&"test_map", "Тест", 32)


static func _party_point(document: MapDocument, id: StringName, function: StringName,
		cell := Vector2i(0, 0)) -> ZoneAnchorRecord:
	var anchor := ZoneAnchorRecord.new()
	anchor.id = id
	anchor.role = ZoneAnchorRecord.ROLE_SPAWN
	anchor.function = function
	anchor.pos = Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	document.zones.anchors.append(anchor)
	return anchor


## The whole point: one point, and the map has everything a launch looks up.
static func _test_the_first_party_point_builds_the_group_and_the_entrance() -> void:
	var document := _document()
	assert(document.zones.spawn_groups.is_empty())
	assert(document.meta.start.starts.is_empty())

	var anchor := _party_point(document, &"party_leader", MapSpawnService.PARTY_LEADER)
	var result := MapPartyStartAuthoring.wire(document, anchor)

	assert(result.created_group and result.created_option and result.created_slot)
	assert(document.zones.spawn_groups.size() == 1)
	var group := document.zones.spawn_groups[0]
	assert(group.id == MapPartyStartAuthoring.GROUP_ID)
	# `nearest_valid`, not `fail`: a party larger than the authored places must land
	# rather than block the launch of a map nobody finished marking up.
	assert(group.fallback == MapSpawnGroup.FALLBACK_NEAREST)
	var leader := group.slot_with_tag(MapSpawnGroup.TAG_LEADER)
	assert(leader != null and leader.anchor_id == &"party_leader")
	assert(document.meta.start.starts.size() == 1)
	var option := document.meta.start.starts[0]
	assert(option.spawn_group == group.id)
	assert(document.meta.start.default_start == option.id)


## The second point is a slot in the group that exists, and only the leader ever
## carries the leader tag — the order slots fill is the order they were drawn.
static func _test_a_second_party_point_joins_the_group_it_found() -> void:
	var document := _document()
	MapPartyStartAuthoring.wire(document,
		_party_point(document, &"party_leader", MapSpawnService.PARTY_LEADER))
	var second := _party_point(document, &"spawn_2", MapSpawnService.PARTY_SLOT, Vector2i(1, 0))
	var result := MapPartyStartAuthoring.wire(document, second)

	assert(not result.created_group and not result.created_option)
	assert(result.created_slot)
	var group := document.zones.spawn_groups[0]
	assert(group.slots.size() == 2)
	var ordered := group.ordered_slots()
	assert(ordered[0].anchor_id == &"party_leader")
	assert(ordered[1].anchor_id == &"spawn_2" and ordered[1].tags.is_empty())
	# Wiring the same point twice must not grow a second slot for it — the
	# inspector re-applies a function on every edit of the row.
	assert(not MapPartyStartAuthoring.wire(document, second).created_slot)
	assert(group.slots.size() == 2)


## Two groups mean the author is arranging entrances deliberately, and there is
## no way to tell which clearing a new point meant. Guessing would silently move
## a settler to the wrong side of the map.
static func _test_an_authored_multi_group_map_is_left_alone() -> void:
	var document := _document()
	for id: StringName in [&"north_camp", &"south_camp"]:
		var group := MapSpawnGroup.new()
		group.id = id
		group.area_id = &"clearing"
		document.zones.spawn_groups.append(group)

	var result := MapPartyStartAuthoring.wire(document,
		_party_point(document, &"party_leader", MapSpawnService.PARTY_LEADER))

	assert(not result.changed())
	assert(document.zones.spawn_groups.size() == 2)
	assert(document.meta.start.starts.is_empty())


## A waypoint, a door, or a spawn with somebody else's function is not the party.
static func _test_a_non_party_point_builds_nothing() -> void:
	var document := _document()
	var waypoint := ZoneAnchorRecord.new()
	waypoint.id = &"waypoint_1"
	waypoint.role = ZoneAnchorRecord.ROLE_WAYPOINT
	assert(not MapPartyStartAuthoring.wire(document, waypoint).changed())

	var wildlife := _party_point(document, &"spawn_1", &"pack:wildlife_den")
	assert(not MapPartyStartAuthoring.wire(document, wildlife).changed())
	assert(document.zones.spawn_groups.is_empty())


## Deleting the point used to leave the slot behind, and the map then failed to
## *save* with "слот ссылается на отсутствующую точку" — a record naming a point
## the author had just deliberately removed. The entrance is cleared rather than
## left dangling, so the validator can name the gesture instead of the record.
static func _test_deleting_the_last_party_point_takes_the_group_with_it() -> void:
	var document := _document()
	MapPartyStartAuthoring.wire(document,
		_party_point(document, &"party_leader", MapSpawnService.PARTY_LEADER))

	var removed := ZoneAuthoring.remove_anchor_cascade(
		document.zones.anchors, document.zones.routes, &"party_leader")
	MapPartyStartAuthoring.forget_records(document, removed)

	assert(document.zones.spawn_groups.is_empty())
	assert(document.meta.start.starts[0].spawn_group == &"")
	assert(document.zones.validate(document.board_cells()).is_empty())


## A group holding a clearing survives losing its last slot: the area is still a
## place a party can appear, which is what `fallback: formation` means.
static func _test_renaming_a_point_follows_into_the_slot() -> void:
	var document := _document()
	MapPartyStartAuthoring.wire(document,
		_party_point(document, &"party_leader", MapSpawnService.PARTY_LEADER))
	document.zones.anchors[0].id = &"camp_leader"
	MapPartyStartAuthoring.rename_record(document, &"party_leader", &"camp_leader")

	var group := document.zones.spawn_groups[0]
	assert(group.slots[0].anchor_id == &"camp_leader")
	assert(document.zones.validate(document.board_cells()).is_empty())

	group.area_id = &"clearing"
	MapPartyStartAuthoring.forget_records(document, [&"camp_leader"] as Array[StringName])
	assert(document.zones.spawn_groups.size() == 1)
	assert(document.zones.spawn_groups[0].slots.is_empty())


## The end-to-end claim: a map with one authored party point launches a party of
## four. This is the gate `SettlementGameModule.validate_session` runs, and the
## one that used to refuse every map drawn in this editor.
static func _test_the_built_map_passes_the_launch_gate() -> void:
	var document := _document()
	MapPartyStartAuthoring.wire(document,
		_party_point(document, &"party_leader", MapSpawnService.PARTY_LEADER))

	var errors := MapValidator.validate_party_capacity(document, &"", 4)
	assert(errors.is_empty(), "; ".join(errors))
	# And the structural rules the save path runs agree with it.
	assert(document.zones.validate(document.board_cells()).is_empty())
	assert(MapValidator.validate(document, document.terrain, document.water, null).is_empty())
