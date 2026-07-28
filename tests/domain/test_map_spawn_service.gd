class_name TestMapSpawnService
extends RefCounted

## Domain tests for the spawn operation (active_zones.md §15): launch roles are
## explicit, so a generic spawn can never silently become a hero fallback.


static func run_all() -> void:
	_test_spawn_anchors_become_positions()
	_test_launch_roles_are_explicit()
	_test_non_spawn_anchors_are_ignored()
	print("    [PASS] Map Spawn Service Tests")


## `spawn` anchors surface in authoring order, so two authored points land where
## the author drew them.
static func _test_spawn_anchors_become_positions() -> void:
	var zones := MapZoneLayer.new()
	var first := ZoneAnchorRecord.new()
	first.id = &"hero_start"
	first.role = ZoneAnchorRecord.ROLE_SPAWN
	first.pos = Vector3(2.5, 0.0, 3.5)
	first.function = MapSpawnService.HERO_START
	zones.anchors.append(first)
	var second := ZoneAnchorRecord.new()
	second.id = &"reinforcements"
	second.role = ZoneAnchorRecord.ROLE_SPAWN
	second.pos = Vector3(10.5, 0.0, 8.5)
	second.function = MapSpawnService.COMPANION_START
	zones.anchors.append(second)

	var service := MapSpawnService.new()
	var positions := service.spawn_positions(zones)
	assert(positions.size() == 2)
	assert(positions[0] == Vector3(2.5, 0.0, 3.5))
	assert(positions[1] == Vector3(10.5, 0.0, 8.5))
	assert(service.hero_spawn_position(zones) == Vector3(2.5, 0.0, 3.5))
	assert(service.companion_spawn_positions(zones) == [Vector3(10.5, 0.0, 8.5)])


## Missing roles have no hidden fallback at launch.
static func _test_launch_roles_are_explicit() -> void:
	var zones := MapZoneLayer.new()
	var service := MapSpawnService.new()
	assert(service.spawn_positions(zones).is_empty())
	assert(service.hero_spawn_position(zones) == Vector3.INF)
	assert(service.companion_spawn_positions(zones).is_empty())


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
