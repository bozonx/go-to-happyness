extends SceneTree

const SimHelper = preload("res://tests/helpers/simulation_test_helper.gd")

## The vertical example for the active-zone runtime (active_zones.md §17): one
## map authored with a region, an overlay, a spawn anchor and a patrol route,
## lifted into a real settlement session. It proves the four layers built in
## isolation compose: the registry adopts the layer's zones, the overlay's cost
## reaches NavGrid, the spawn anchor places a citizen, and crossing the region's
## footprint publishes `area_entered` on the bus. If any seam is wrong, this is
## the one test that catches it — the unit tests prove the parts, this proves
## the whole.
##
## No shipped map carries zones yet, so the map is authored in memory and fed to
## a simulation the way `setup_simulation` feeds `green_valley`, minus the helper
## (which hardcodes the default config). The body mirrors that helper's setup so
## the session reaches the same ready state.

func _init() -> void:
	var simulation := await _setup_with_zone_map(self)

	# 1. The registry adopted every authored area: one region, one overlay.
	assert(simulation.map_zone_registry != null)
	assert(simulation.map_zone_registry.state(&"gate_yard") != null, "region adopted")
	assert(simulation.map_zone_registry.state(&"forest") != null, "overlay adopted")

	# 2. The overlay's cost reached the navigation grid: a forest cell is pricier
	#    than the grass beside it (overlay weight 2.0 × surface 2.0 = 4.0).
	var forest_weight: float = simulation.nav_grid.get_cell_weight(Vector2i(2, 2))
	var grass_weight: float = simulation.nav_grid.get_cell_weight(Vector2i(10, 10))
	assert(forest_weight > grass_weight, "forest overlay priced in NavGrid: %f vs %f" % [forest_weight, grass_weight])

	# 3. The authored hero spawn placed a citizen in its column:
	#    at least one citizen stands in the spawn cell's column.
	var spawn_cell := Vector2i(6, 6)
	var any_at_spawn := false
	for citizen in simulation.citizens:
		if simulation.cell_from_position(citizen.global_position) == spawn_cell:
			any_at_spawn = true
			break
	assert(any_at_spawn, "a citizen spawned at the spawn anchor")

	# 4. Crossing the region's footprint publishes area_entered on the bus. The
	#    bus is wired with no consumers, so this attaches one for the test and
	#    walks a citizen into the region via the presence tracker directly — the
	#    same call `guard_citizen_positions` makes every tick.
	var entered := [false]
	simulation.zone_event_bus.configure({
		"area_entered": func(_event: ZoneEvent): entered[0] = true,
		"area_exited": func(_event: ZoneEvent): pass,
		"owner_changed": func(_event: ZoneEvent): pass,
		"zone_flag_changed": func(_event: ZoneEvent): pass,
		"slot_reserved": func(_event: ZoneEvent): pass,
		"slot_released": func(_event: ZoneEvent): pass,
	})
	var first_citizen: Citizen = simulation.citizens[0]
	simulation.zone_presence_tracker.on_citizen_cell_changed(first_citizen.ai_id, Vector2i(12, 12), ActorTags.of(first_citizen))
	assert(entered[0], "entering the gate_yard region published area_entered")

	# 4b. The board is centred on the origin, so half of every map lies in negative
	#     cells. A `0 … board_cells` bounds check in the cost and presence indexes
	#     silently dropped every zone drawn there: the editor showed them, the
	#     runtime did not have them. Both layers are checked west of the origin.
	var west_weight: float = simulation.nav_grid.get_cell_weight(Vector2i(-6, -6))
	assert(west_weight > grass_weight,
		"an overlay west of the origin prices its cells too: %f vs %f" % [west_weight, grass_weight])
	var west_entered := [false]
	simulation.zone_event_bus.configure({
		"area_entered": func(event: ZoneEvent): west_entered[0] = event.subject_id == &"west_camp",
		"area_exited": func(_event: ZoneEvent): pass,
		"owner_changed": func(_event: ZoneEvent): pass,
		"zone_flag_changed": func(_event: ZoneEvent): pass,
		"slot_reserved": func(_event: ZoneEvent): pass,
		"slot_released": func(_event: ZoneEvent): pass,
	})
	simulation.zone_presence_tracker.on_citizen_cell_changed(
		first_citizen.ai_id, Vector2i(-10, -10), ActorTags.of(first_citizen))
	assert(west_entered[0], "a region west of the origin publishes area_entered too")

	# 5. The patrol route's stops resolve and its single edge is walkable — the
	#    validator's reachability check agrees the map is sound.
	var warnings := MapValidator.warnings(simulation.launch_config.map_document, simulation.nav_grid)
	var route_warning := warnings.any(func(m: String) -> bool: return m.find("patrol") > 0)
	assert(not route_warning, "patrol route is walkable: %s" % "; ".join(warnings))

	await SimHelper.cleanup_simulation(self, simulation)
	print("--- test_zone_vertical_example.gd PASSED ---")
	quit()


## Builds a settlement session backed by an in-memory map authored with a region
## (gate_yard, cells 11..13²), an overlay (forest, cost 2.0, cells 2..3²), a
## spawn anchor (6,6) and a two-stop patrol route. Mirrors `setup_simulation`
## but substitutes the document, so the bootstrap's zone phase has real zones to
## adopt instead of an empty layer.
func _setup_with_zone_map(tree: SceneTree) -> Node:
	return await SimHelper.setup_simulation(tree, _zone_map())


func _zone_map() -> MapDocument:
	var document := MapDocument.create(&"zone_demo", "Zone Demo", 32)

	var gate_yard := ZoneAreaRecord.new()
	gate_yard.id = &"gate_yard"
	gate_yard.role = ZoneAreaRecord.ROLE_REGION
	gate_yard.add_rect(Rect2i(11, 11, 3, 3)) # cells (11,11)..(13,13)
	document.zones.areas.append(gate_yard)

	var forest := ZoneAreaRecord.new()
	forest.id = &"forest"
	forest.role = ZoneAreaRecord.ROLE_OVERLAY
	forest.effects = {ZoneEffects.KEY_COST: 2.0}
	forest.add_rect(Rect2i(2, 2, 2, 2)) # cells (2,2)..(3,3)
	document.zones.areas.append(forest)

	# The same two kinds of area west of the origin. A board of 32 runs -16…15, so
	# these are ordinary cells — and they were the ones both indexes threw away.
	var west_camp := ZoneAreaRecord.new()
	west_camp.id = &"west_camp"
	west_camp.role = ZoneAreaRecord.ROLE_REGION
	west_camp.add_rect(Rect2i(-12, -12, 4, 4)) # cells (-12,-12)..(-9,-9)
	document.zones.areas.append(west_camp)

	var west_thicket := ZoneAreaRecord.new()
	west_thicket.id = &"west_thicket"
	west_thicket.role = ZoneAreaRecord.ROLE_OVERLAY
	west_thicket.effects = {ZoneEffects.KEY_COST: 2.0}
	west_thicket.add_rect(Rect2i(-7, -7, 3, 3)) # cells (-7,-7)..(-5,-5)
	document.zones.areas.append(west_thicket)

	var spawn := ZoneAnchorRecord.new()
	spawn.id = &"hero_start"
	spawn.role = ZoneAnchorRecord.ROLE_SPAWN
	spawn.pos = Vector3(6.5, 0.0, 6.5)
	spawn.function = MapSpawnService.HERO_START
	document.zones.anchors.append(spawn)
	for index in 3:
		var companion := ZoneAnchorRecord.new()
		companion.id = StringName("companion_%d" % index)
		companion.role = ZoneAnchorRecord.ROLE_SPAWN
		companion.function = MapSpawnService.COMPANION_START
		companion.pos = Vector3(7.5 + float(index), 0.0, 6.5)
		document.zones.anchors.append(companion)
	var backpack := MapEntityRecord.new()
	backpack.id = &"starter_backpack"
	backpack.archetype_id = &"core:starter_backpack"
	backpack.position = Vector3(6.5, 0.0, 7.5)
	document.entities.entities.append(backpack)

	# Two waypoints inside the gate_yard region, adjacent and walkable.
	var post_a := ZoneAnchorRecord.new()
	post_a.id = &"post_a"
	post_a.role = ZoneAnchorRecord.ROLE_WAYPOINT
	post_a.pos = Vector3(11.5, 0.0, 11.5)
	document.zones.anchors.append(post_a)
	var post_b := ZoneAnchorRecord.new()
	post_b.id = &"post_b"
	post_b.role = ZoneAnchorRecord.ROLE_WAYPOINT
	post_b.pos = Vector3(12.5, 0.0, 11.5)
	document.zones.anchors.append(post_b)

	var patrol := ZoneRouteRecord.new()
	patrol.id = &"patrol"
	patrol.stops = [&"post_a", &"post_b"]
	document.zones.routes.append(patrol)

	return document
