class_name TestMapSpawnService
extends RefCounted

## Domain tests for the spawn operation (active_zones.md §15): launch roles are
## explicit, so a generic spawn can never silently become a hero fallback.


static func run_all() -> void:
	_test_spawn_anchors_become_positions()
	_test_launch_roles_are_explicit()
	_test_non_spawn_anchors_are_ignored()
	_test_board_cells_become_world_space()
	_test_a_party_larger_than_its_slots_grows_into_the_area()
	_test_a_party_that_does_not_fit_refuses()
	_test_claim_hands_out_each_address_once()
	_test_claim_refuses_a_cell_its_own_audience_may_not_enter()
	_test_claim_falls_back_to_a_region()
	print("    [PASS] Map Spawn Service Tests")


## `spawn` anchors surface in authoring order, so two authored points land where
## the author drew them.
static func _test_spawn_anchors_become_positions() -> void:
	var zones := MapZoneLayer.new()
	var first := ZoneAnchorRecord.new()
	first.id = &"hero_start"
	first.role = ZoneAnchorRecord.ROLE_SPAWN
	first.pos = Vector3(2.5, 0.0, 3.5)
	first.function = MapSpawnService.PARTY_LEADER
	zones.anchors.append(first)
	var second := ZoneAnchorRecord.new()
	second.id = &"reinforcements"
	second.role = ZoneAnchorRecord.ROLE_SPAWN
	second.pos = Vector3(10.5, 0.0, 8.5)
	second.function = MapSpawnService.PARTY_SLOT
	zones.anchors.append(second)

	var service := MapSpawnService.new()
	var positions := service.spawn_positions(zones)
	assert(positions.size() == 2)
	assert(positions[0] == Vector3(2.5, 0.0, 3.5))
	assert(positions[1] == Vector3(10.5, 0.0, 8.5))
	# The v7 names still answer, for one release (§16): a document held in memory
	# from before the migration must not read as a map with no party at all.
	assert(MapSpawnService.canonical_function(&"core:hero_start") == MapSpawnService.PARTY_LEADER)
	assert(MapSpawnService.canonical_function(&"core:companion_start") == MapSpawnService.PARTY_SLOT)


## Missing roles have no hidden fallback at launch.
static func _test_launch_roles_are_explicit() -> void:
	var zones := MapZoneLayer.new()
	var service := MapSpawnService.new()
	assert(service.spawn_positions(zones).is_empty())
	assert(service.anchor_with_function(zones, MapSpawnService.PARTY_LEADER) == null)
	assert(service.camera_position(zones, &"nowhere") == Vector3.INF)


## A `waypoint` or a `poi` is not a spawn point and must not surface here — the
## engine reads only `role`, never `function` (§2), so the filter is on the role.
static func _test_non_spawn_anchors_are_ignored() -> void:
	var zones := MapZoneLayer.new()
	var waypoint := ZoneAnchorRecord.new()
	waypoint.id = &"post_a"
	waypoint.role = ZoneAnchorRecord.ROLE_WAYPOINT
	waypoint.pos = Vector3(5.0, 0.0, 5.0)
	zones.anchors.append(waypoint)

	var service := MapSpawnService.new()
	assert(service.spawn_positions(zones).is_empty(), "waypoints are not spawn points")


## Zone geometry is authored in board cells and `pos.y` is a terrain level (§6);
## world space is reached here, on the runtime boundary, and exactly once. A map
## with a cell size other than 1 used to place its party at a fraction of where
## the author drew it.
static func _test_board_cells_become_world_space() -> void:
	var zones := MapZoneLayer.new()
	var hero := ZoneAnchorRecord.new()
	hero.id = &"hero_start"
	hero.role = ZoneAnchorRecord.ROLE_SPAWN
	hero.function = MapSpawnService.HERO_START
	hero.facing = 90.0
	hero.pos = Vector3(2.5, 3.0, 3.5) # cell (2,3), terrain level 3
	zones.anchors.append(hero)

	var group := MapSpawnGroup.new()
	group.id = &"party"
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"leader"
	slot.anchor_id = &"hero_start"
	slot.tags = [MapSpawnGroup.TAG_LEADER]
	group.slots.append(slot)

	var service := MapSpawnService.new()
	var plan := service.plan_party(zones, group, 1)
	assert(plan.ok and plan.placements[0].position == Vector3(2.5, 3.0 * TerrainGrid.HEIGHT_STEP, 3.5),
		"a level becomes metres, not the other way round")
	var scaled := service.plan_party(zones, group, 1, 2.0)
	assert(scaled.placements[0].position == Vector3(5.0, 3.0 * TerrainGrid.HEIGHT_STEP, 7.0),
		"cell size scales the plan, got %s" % scaled.placements[0].position)
	assert(is_equal_approx(plan.placements[0].facing, 90.0),
		"the authored bearing survives to launch")


## The point of §4.3: three authored places do not cap the party at three. A
## fourth member stands beside them instead of failing the launch, which is what
## the removed `population - 1` anchor rule did.
static func _test_a_party_larger_than_its_slots_grows_into_the_area() -> void:
	var zones := MapZoneLayer.new()
	var clearing := ZoneAreaRecord.new()
	clearing.id = &"clearing"
	clearing.role = ZoneAreaRecord.ROLE_REGION
	clearing.add_rect(Rect2i(-4, -4, 8, 8))
	zones.areas.append(clearing)
	var leader := ZoneAnchorRecord.new()
	leader.id = &"leader_point"
	leader.role = ZoneAnchorRecord.ROLE_SPAWN
	leader.function = MapSpawnService.PARTY_LEADER
	leader.pos = Vector3(0.5, 0.0, 0.5)
	zones.anchors.append(leader)

	var group := MapSpawnGroup.new()
	group.id = &"river_party"
	group.area_id = &"clearing"
	group.spacing = 1.0
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"leader"
	slot.anchor_id = &"leader_point"
	slot.tags = [MapSpawnGroup.TAG_LEADER]
	group.slots.append(slot)

	var plan := MapSpawnService.new().plan_party(zones, group, 6)
	assert(plan.ok, "one authored place plus a clearing seats six: %s" % plan.reason)
	assert(plan.placements.size() == 6, "everybody gets a place")
	assert(plan.placements[0].position == Vector3(0.5, 0.0, 0.5), "the leader keeps the authored spot")
	var seen: Dictionary = {}
	for placement: MapSpawnService.PartyPlacement in plan.placements:
		var key := Vector2i(floori(placement.position.x), floori(placement.position.z))
		assert(not seen.has(key), "two members on one cell")
		seen[key] = true


## A party that does not fit blocks the launch and says by how much. Silently
## seating fewer settlers than the player chose would be a bug wearing a
## fallback's coat (§4.3).
static func _test_a_party_that_does_not_fit_refuses() -> void:
	var zones := MapZoneLayer.new()
	var spawn := ZoneAnchorRecord.new()
	spawn.id = &"only_place"
	spawn.role = ZoneAnchorRecord.ROLE_SPAWN
	spawn.function = MapSpawnService.PARTY_LEADER
	spawn.pos = Vector3(0.5, 0.0, 0.5)
	zones.anchors.append(spawn)

	var group := MapSpawnGroup.new()
	group.id = &"tight"
	group.fallback = MapSpawnGroup.FALLBACK_FAIL
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"leader"
	slot.anchor_id = &"only_place"
	group.slots.append(slot)

	var plan := MapSpawnService.new().plan_party(zones, group, 4)
	assert(not plan.ok, "one place cannot seat four")
	assert(plan.reason.contains("tight") and plan.reason.contains("3"),
		"the refusal names the group and how many did not fit: %s" % plan.reason)

	group.capacity = 2
	var over_capacity := MapSpawnService.new().plan_party(zones, group, 3)
	assert(not over_capacity.ok, "the author's ceiling is enforced before anything is placed")


## The §15 operation: one address, one occupant. Without it a wave of three would
## put all three on the single point the author drew.
static func _test_claim_hands_out_each_address_once() -> void:
	var zones := MapZoneLayer.new()
	for index in 2:
		var spawn := ZoneAnchorRecord.new()
		spawn.id = StringName("drop_%d" % index)
		spawn.role = ZoneAnchorRecord.ROLE_SPAWN
		spawn.function = &"pack:drop"
		spawn.pos = Vector3(float(index) + 0.5, 0.0, 0.5)
		zones.anchors.append(spawn)

	var service := MapSpawnService.new()
	var first := service.claim(zones, &"pack:drop")
	var second := service.claim(zones, &"pack:drop")
	var third := service.claim(zones, &"pack:drop")
	assert(first.ok and second.ok, "two authored points serve two claims")
	assert(first.address != second.address, "a claimed address is not handed out twice")
	assert(not third.ok, "a full drop zone refuses rather than stacking units")
	assert(not third.reason.is_empty(), "a refusal says why")

	service.release(first.address)
	assert(service.claim(zones, &"pack:drop").ok, "a released address comes back into rotation")


## Rights are part of the operation, not an afterthought: a point sealed off for
## the audience being spawned is not a place that unit may appear (§4.1, §15).
static func _test_claim_refuses_a_cell_its_own_audience_may_not_enter() -> void:
	var zones := MapZoneLayer.new()
	var spawn := ZoneAnchorRecord.new()
	spawn.id = &"gate"
	spawn.role = ZoneAnchorRecord.ROLE_SPAWN
	spawn.function = &"pack:drop"
	spawn.pos = Vector3(4.5, 0.0, 4.5)
	zones.anchors.append(spawn)
	var overlay := ZoneAreaRecord.new()
	overlay.id = &"keep_out"
	overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	overlay.deny = [&"visitor"]
	overlay.add_rect(Rect2i(4, 4, 1, 1))
	zones.areas.append(overlay)

	var service := MapSpawnService.new()
	assert(not service.claim(zones, &"pack:drop").ok, "a visitor may not appear where visitors are denied")
	var staff: Array[StringName] = [&"staff"]
	assert(service.claim(zones, &"pack:drop", 1.0, staff).ok, "staff may")


## §15 allows a `region` whose pack function declares it an appearance area, so an
## author who wants "somewhere in this clearing" draws instead of dotting points.
static func _test_claim_falls_back_to_a_region() -> void:
	var zones := MapZoneLayer.new()
	var region := ZoneAreaRecord.new()
	region.id = &"clearing"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.function = &"pack:drop"
	region.add_rect(Rect2i(-3, -3, 2, 2))
	region.y_min = 1
	region.y_max = 1
	zones.areas.append(region)

	var service := MapSpawnService.new()
	var first := service.claim(zones, &"pack:drop")
	assert(first.ok, "a region with the function is a spawn address: %s" % first.reason)
	assert(first.position.y == 1.0 * TerrainGrid.HEIGHT_STEP, "the region's level becomes metres")
	var second := service.claim(zones, &"pack:drop")
	assert(second.ok and second.address != first.address, "a region serves one claim per cell")
