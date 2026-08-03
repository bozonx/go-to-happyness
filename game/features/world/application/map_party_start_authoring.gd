class_name MapPartyStartAuthoring
extends RefCounted

## Turns a party appearance point into a launchable start (`map_start.md` §4.2,
## §3.3).
##
## A spawn group and an entrance are what the runtime actually looks up: the
## session resolves an entrance, the entrance names a group, the group places the
## party. Both were readable, writable and validated — and authorable *nowhere*.
## `MapSpawnGroup` was built by exactly one caller, the v7→v8 migration, so an old
## map arrived with a group while a map drawn today could never gain one. Placing
## the party's start point therefore produced a map that the editor accepted, the
## validator refused, and the author had no gesture to fix: "вариант старта не
## называет группу появления" named two records the editor could not create.
##
## So the point that means "the party starts here" builds the structure around
## itself, exactly as the migration builds it for a v7 map. This is filling in
## what the author's gesture already said, not guessing: a `core:party_leader`
## anchor has one possible meaning.
##
## What it deliberately does not do is take over a map whose author is managing
## these records by hand. With two or more groups on the layer the intent is no
## longer inferable — which of them did this point mean? — so it stops and leaves
## the explicit editor to it (§4.2: a map may have as many entrances as it likes).

## Id the first auto-built group takes. Readable rather than generated, for the
## same reason the first party point is `party_leader` and not `spawn_3`: it is
## the address the start dialog shows and a scenario rule may name.
const GROUP_ID := &"party_start"

## Report of what a wiring pass changed. Empty `created` means the layer already
## said everything the point implied, which is the common case from the second
## point onwards.
class Result:
	extends RefCounted

	var group: MapSpawnGroup = null
	var created_group := false
	var created_option := false
	var created_slot := false

	func changed() -> bool:
		return created_group or created_option or created_slot

	## What the status bar says. Deliberately names the records by the words the
	## start dialog uses, so an author who wants to change them knows where to look.
	func message() -> String:
		if created_group and created_option:
			return "создана группа появления «%s» и вариант старта — правьте в «Старт»" % GROUP_ID
		if created_group:
			return "создана группа появления «%s» — правьте в «Старт»" % GROUP_ID
		if created_slot:
			return "точка добавлена в группу появления «%s»" % GROUP_ID
		return ""


## Wires `anchor` into the document's start structure and reports what it built.
##
## Callers snapshot the zone layer and the start section *before* this and push a
## composite command: one gesture, one `Ctrl+Z`.
static func wire(document: MapDocument, anchor: ZoneAnchorRecord) -> Result:
	var result := Result.new()
	if document == null or anchor == null or not anchor.is_spawn():
		return result
	var function := MapSpawnService.canonical_function(anchor.function)
	if function != MapSpawnService.PARTY_LEADER and function != MapSpawnService.PARTY_SLOT:
		return result
	var zones := document.zones
	# Two or more groups: the author is arranging entrances deliberately and a
	# guess here would silently join a point to the wrong clearing.
	if zones.spawn_groups.size() > 1:
		return result
	var group: MapSpawnGroup = zones.spawn_groups[0] if not zones.spawn_groups.is_empty() else null
	if group == null:
		group = _new_group(zones)
		zones.spawn_groups.append(group)
		result.created_group = true
	result.group = group
	if _slot_for_anchor(group, anchor.id) == null:
		group.slots.append(_new_slot(group, anchor, function))
		result.created_slot = true
	# The group's ceiling must not be what caps the party. An author who wants a
	# real ceiling types one; a group grown by placing points means "these places,
	# and more if the session asks", which is what `capacity` under the slot count
	# would quietly refuse at launch.
	group.capacity = maxi(group.capacity, group.slots.size())
	if _ensure_entrance(document, group):
		result.created_option = true
	return result


## The group a lone party point implies: no clearing (a v7 map had none either),
## and `nearest_valid` so a party larger than the authored places still lands
## instead of blocking the launch on a map nobody finished marking up.
static func _new_group(zones: MapZoneLayer) -> MapSpawnGroup:
	var group := MapSpawnGroup.new()
	# `has_id` walks areas, anchors and routes; groups share the same id space
	# (`MapZoneLayer.validate` checks them against one table), so both are asked.
	var taken := func(candidate: StringName) -> bool:
		return zones.has_id(candidate) or zones.spawn_group_by_id(candidate) != null
	group.id = GROUP_ID if not taken.call(GROUP_ID) else ZoneAuthoring.unique_id(
		String(GROUP_ID), taken)
	group.name = {"ru": "Старт отряда"}
	group.fallback = MapSpawnGroup.FALLBACK_NEAREST
	return group


static func _new_slot(group: MapSpawnGroup, anchor: ZoneAnchorRecord, function: StringName) -> MapSpawnGroup.Slot:
	var slot := MapSpawnGroup.Slot.new()
	slot.anchor_id = anchor.id
	var is_leader := function == MapSpawnService.PARTY_LEADER \
		and group.slot_with_tag(MapSpawnGroup.TAG_LEADER) == null
	if is_leader:
		slot.id = &"leader"
		slot.tags = [MapSpawnGroup.TAG_LEADER]
		slot.order = 0
	else:
		# Authoring order is fill order (§4.3), and `order` is the contract rather
		# than the array position — so a new slot goes after the last one that
		# exists, not after the last one currently displayed.
		var next := 1
		for existing: MapSpawnGroup.Slot in group.slots:
			next = maxi(next, existing.order + 1)
		slot.id = StringName("slot_%d" % next)
		slot.order = next
	return slot


static func _slot_for_anchor(group: MapSpawnGroup, anchor_id: StringName) -> MapSpawnGroup.Slot:
	for slot: MapSpawnGroup.Slot in group.slots:
		if slot.anchor_id == anchor_id:
			return slot
	return null


## --- Keeping the structure honest after an edit --------------------------------

## Follows a deletion into the groups: slots whose anchor is gone, and a clearing
## a group grew into that is gone. Deleting a party point used to leave the slot
## behind, and the map then failed *save* with "слот ссылается на отсутствующую
## точку" — a record the author never made, naming a point they had just
## deliberately removed.
##
## `removed_ids` is what the cascade reports, areas and anchors together: an area
## deletion takes the points it owned with it, so both kinds arrive in one list
## and both are references a group may hold.
##
## A group left with neither slots nor a clearing is removed too, and every
## entrance that named it is cleared rather than left dangling: "поставьте точку
## появления партии" is a thing an author can act on, "ссылается на несуществующую
## группу party_start" is not.
static func forget_records(document: MapDocument, removed_ids: Array[StringName]) -> void:
	if document == null or removed_ids.is_empty():
		return
	var zones := document.zones
	var dropped: Array[StringName] = []
	for index in range(zones.spawn_groups.size() - 1, -1, -1):
		var group: MapSpawnGroup = zones.spawn_groups[index]
		for slot_index in range(group.slots.size() - 1, -1, -1):
			if group.slots[slot_index].anchor_id in removed_ids:
				group.slots.remove_at(slot_index)
		if group.area_id in removed_ids:
			group.area_id = &""
		if group.slots.is_empty() and group.area_id == &"":
			dropped.append(group.id)
			zones.spawn_groups.remove_at(index)
	for option: MapStartOption in document.meta.start.starts:
		if option.spawn_group in dropped:
			option.spawn_group = &""


## Follows a rename into the references a group holds — its slots' anchors and
## its clearing. Same rule as the queue targets and route stops the rename
## already walks: an id is a reference, and a reference the editor forgets to
## move is a launch error. Points and areas share one id space, so one pass
## covers both without the caller saying which kind it renamed.
static func rename_record(document: MapDocument, from_id: StringName, to_id: StringName) -> void:
	if document == null:
		return
	for group: MapSpawnGroup in document.zones.spawn_groups:
		if group.area_id == from_id:
			group.area_id = to_id
		for slot: MapSpawnGroup.Slot in group.slots:
			if slot.anchor_id == from_id:
				slot.anchor_id = to_id


## The entrance that names the group. A map with no entrances gains the one the
## migration would have given it; a map whose entrances exist but name nothing
## gets them filled in, because an entrance without a group is the launch error
## this whole file is about.
static func _ensure_entrance(document: MapDocument, group: MapSpawnGroup) -> bool:
	var start := document.meta.start
	if start.starts.is_empty():
		var option := MapStartOption.new()
		option.id = MapStart.LEGACY_START_ID
		option.name = MapLocalizedText.of("Начало")
		option.spawn_group = group.id
		start.starts.append(option)
		start.default_start = option.id
		return true
	var filled := false
	for option: MapStartOption in start.starts:
		if option.spawn_group == &"":
			option.spawn_group = group.id
			filled = true
	return filled
