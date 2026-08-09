class_name TestMapSpawnService
extends RefCounted

## Domain tests for the spawn operation (active_zones.md §15): launch roles are
## explicit, so a generic spawn can never silently become a hero fallback.


static func run_all() -> void:
	_test_launch_roles_are_explicit()
	_test_board_cells_become_world_space()
	_test_a_party_larger_than_its_slots_grows_into_the_area()
	_test_a_party_that_does_not_fit_refuses()
	_test_a_blocked_leader_refuses()
	_test_rights_deny_a_place()
	_test_the_formation_stays_on_dry_ground_inside_the_board()
	print("    [PASS] Map Spawn Service Tests")


## Missing roles have no hidden fallback at launch.
static func _test_launch_roles_are_explicit() -> void:
	var zones := MapZoneLayer.new()
	var service := MapSpawnService.new()
	assert(service.anchor_with_function(zones, MapSpawnService.PARTY_LEADER) == null)
	assert(service.camera_position(zones, &"nowhere") == Vector3.INF)
	# The v7 names still answer, for one release (§16): a document held in memory
	# from before the migration must not read as a map with no party at all.
	assert(MapSpawnService.canonical_function(&"core:hero_start") == MapSpawnService.PARTY_LEADER)
	assert(MapSpawnService.canonical_function(&"core:companion_start") == MapSpawnService.PARTY_SLOT)


## Zone geometry is authored in board cells and `pos.y` is a terrain level (§6);
## world space is reached here, on the runtime boundary, and exactly once. A map
## with a cell size other than 1 used to place its party at a fraction of where
## the author drew it.
static func _test_board_cells_become_world_space() -> void:
	var zones := MapZoneLayer.new()
	var hero := ZoneAnchorRecord.new()
	hero.id = &"hero_start"
	hero.role = ZoneAnchorRecord.ROLE_SPAWN
	hero.function = MapSpawnService.PARTY_LEADER
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


## A leader slot the party cannot use refuses the plan instead of promoting the
## next member. Letting `placements[0]` become a companion put the hero on someone
## else's place and gave the whole party that place's bearing.
static func _test_a_blocked_leader_refuses() -> void:
	var zones := MapZoneLayer.new()
	var leader := ZoneAnchorRecord.new()
	leader.id = &"leader_point"
	leader.role = ZoneAnchorRecord.ROLE_SPAWN
	leader.function = MapSpawnService.PARTY_LEADER
	leader.pos = Vector3(4.5, 0.0, 4.5)
	zones.anchors.append(leader)
	var second := ZoneAnchorRecord.new()
	second.id = &"slot_point"
	second.role = ZoneAnchorRecord.ROLE_SPAWN
	second.function = MapSpawnService.PARTY_SLOT
	second.pos = Vector3(6.5, 0.0, 4.5)
	zones.anchors.append(second)
	var sealed := ZoneAreaRecord.new()
	sealed.id = &"keep_out"
	sealed.role = ZoneAreaRecord.ROLE_OVERLAY
	sealed.deny = [&"visitor"]
	sealed.add_rect(Rect2i(4, 4, 1, 1))
	zones.areas.append(sealed)

	var group := MapSpawnGroup.new()
	group.id = &"camp"
	var leader_slot := MapSpawnGroup.Slot.new()
	leader_slot.id = &"leader"
	leader_slot.anchor_id = &"leader_point"
	leader_slot.tags = [MapSpawnGroup.TAG_LEADER]
	group.slots.append(leader_slot)
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"slot_1"
	slot.anchor_id = &"slot_point"
	slot.order = 1
	group.slots.append(slot)

	var plan := MapSpawnService.new().plan_party(zones, group, 1)
	assert(not plan.ok, "a party whose leader has nowhere to stand does not launch")
	assert(plan.reason.contains("camp"), "the refusal names the group: %s" % plan.reason)


## Rights are part of placement, not an afterthought: a place sealed off for the
## audience being placed is not a place that party may appear (§4.1).
static func _test_rights_deny_a_place() -> void:
	var zones := MapZoneLayer.new()
	var spawn := ZoneAnchorRecord.new()
	spawn.id = &"gate"
	spawn.role = ZoneAnchorRecord.ROLE_SPAWN
	spawn.function = MapSpawnService.PARTY_LEADER
	spawn.pos = Vector3(4.5, 0.0, 4.5)
	zones.anchors.append(spawn)
	var overlay := ZoneAreaRecord.new()
	overlay.id = &"keep_out"
	overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	overlay.deny = [&"visitor"]
	overlay.add_rect(Rect2i(4, 4, 1, 1))
	zones.areas.append(overlay)

	var group := MapSpawnGroup.new()
	group.id = &"gate_party"
	group.fallback = MapSpawnGroup.FALLBACK_FAIL
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"leader"
	slot.anchor_id = &"gate"
	slot.tags = [MapSpawnGroup.TAG_LEADER]
	group.slots.append(slot)

	assert(not MapSpawnService.new().plan_party(zones, group, 1).ok,
		"a visitor may not appear where visitors are denied")
	var staff: Array[StringName] = [&"staff"]
	assert(MapSpawnService.new().plan_party(zones, group, 1, 1.0, staff).ok, "staff may")


## A formation grows onto standable cells only. While nothing configured the
## service, "outside the board" and "under two metres of water" both read as free
## and a party of six walked off the rim of a map with no clearing drawn.
static func _test_the_formation_stays_on_dry_ground_inside_the_board() -> void:
	const BOARD := 8
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD)
	var zones := MapZoneLayer.new()
	var leader := ZoneAnchorRecord.new()
	leader.id = &"leader_point"
	leader.role = ZoneAnchorRecord.ROLE_SPAWN
	leader.function = MapSpawnService.PARTY_LEADER
	# The far corner of the board: every ring around it leaves the map.
	leader.pos = Vector3(3.5, 0.0, 3.5)
	zones.anchors.append(leader)

	var group := MapSpawnGroup.new()
	group.id = &"rim"
	group.spacing = 1.0
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"leader"
	slot.anchor_id = &"leader_point"
	slot.tags = [MapSpawnGroup.TAG_LEADER]
	group.slots.append(slot)

	var service := MapSpawnService.new()
	service.configure(null, terrain, null)
	var plan := service.plan_party(zones, group, 4)
	assert(plan.ok, "the corner still seats four from the cells inside: %s" % plan.reason)
	for placement: MapSpawnService.PartyPlacement in plan.placements:
		var cell := Vector2i(floori(placement.position.x), floori(placement.position.z))
		assert(terrain.is_inside(cell), "member placed off the board at %s" % cell)
