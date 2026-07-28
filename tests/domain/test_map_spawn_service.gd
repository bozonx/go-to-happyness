class_name TestMapSpawnService
extends RefCounted

## Domain tests for the spawn operation (active_zones.md §15): that authored
## `spawn` anchors become positions in a stable order, and that a layer with no
## spawns falls back to whatever the caller drew with — the citizen factory's
## hardcoded entrance anchor today.


static func run_all() -> void:
	_test_spawn_anchors_become_positions()
	_test_empty_layer_returns_fallback()
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
	zones.anchors.append(first)
	var second := ZoneAnchorRecord.new()
	second.id = &"reinforcements"
	second.role = ZoneAnchorRecord.ROLE_SPAWN
	second.pos = Vector3(10.5, 0.0, 8.5)
	zones.anchors.append(second)

	var service := MapSpawnService.new()
	var positions := service.spawn_positions(zones)
	assert(positions.size() == 2)
	assert(positions[0] == Vector3(2.5, 0.0, 3.5))
	assert(positions[1] == Vector3(10.5, 0.0, 8.5))
	assert(service.first_spawn_position(zones, Vector3.ZERO) == Vector3(2.5, 0.0, 3.5))


## A layer with no `spawn` anchor falls back to the caller's default, so a map
## that authors none behaves like the no-map board always did.
static func _test_empty_layer_returns_fallback() -> void:
	var zones := MapZoneLayer.new()
	var service := MapSpawnService.new()
	assert(service.spawn_positions(zones).is_empty())
	var fallback := Vector3(-21.5, 0.0, 1.5)
	assert(service.first_spawn_position(zones, fallback) == fallback)


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
