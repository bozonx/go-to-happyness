class_name MapValidator
extends RefCounted

## Cross-cutting map validation that needs the runtime grids
## (design_docs/engine/active_zones.md §8.1, map_editor.md §11).
##
## `MapZoneLayer.validate` already enforces the structural rules — duplicate
## ids, the role gate, bounds, route references, the owner y-range. Those need
## nothing but the layer itself. The rules here need the terrain, water and
## navigation grids: a spawn point sitting in a hole, under impassable water, or
## a hero-mode map with no `hero_start`. They are kept separate because they
## cannot run at authoring time without the published grids, and folding them
## into the layer would couple pure data to the world.
##
## Two grades, mirroring §11: `validate` returns launch-blocking errors (a map
## with them will not start); `warnings` returns things a map will launch with
## but the author very likely did not mean. Reachability lives in `warnings`
## because it needs a published `NavGrid`, which the save path does not have —
## the editor's "Проверить" button supplies one, save calls `validate` with
## `nav_grid = null` and reachability is silently skipped.

## Runs every cross-cutting check and returns the launch-blocking errors.
## `nav_grid` may be null — reachability checks are skipped then, which is how
## the map editor validates before the navigation field is published.
static func validate(document: MapDocument, terrain: TerrainGrid, water: WaterGrid, nav_grid: NavGrid) -> Array[String]:
	var errors: Array[String] = []
	for anchor in document.zones.anchors:
		_validate_anchor_place(anchor, terrain, water, errors)
	_validate_entities(document, terrain, errors)
	_validate_hero_start(document, errors)
	return errors


## Launch-time party validation. `validate` stays reusable by the editor, where
## the intended population is not necessarily known; the game supplies its
## actual party size immediately before bootstrapping a session.
static func validate_party_spawns(document: MapDocument, population: int) -> Array[String]:
	var errors: Array[String] = []
	if document == null:
		errors.append("для запуска нужна карта")
		return errors
	var spawns := MapSpawnService.new()
	if spawns.hero_spawn_position(document.zones) == Vector3.INF:
		errors.append("карта требует spawn-точку с function core:hero_start")
	var expected_companions := maxi(population - 1, 0)
	if spawns.companion_spawn_positions(document.zones).size() < expected_companions:
		errors.append("карта требует %d spawn-точек с function core:companion_start" % expected_companions)
	return errors


static func _validate_entities(document: MapDocument, terrain: TerrainGrid, errors: Array[String]) -> void:
	var ids: Dictionary = {}
	for entity: MapEntityRecord in document.entities.entities:
		if entity.id == &"" or ids.has(entity.id):
			errors.append("дубликат или пустой id сущности: %s" % entity.id)
			continue
		ids[entity.id] = true
		if terrain == null:
			continue
		var cell := entity.cell(terrain)
		if not terrain.is_inside(cell):
			errors.append("сущность %s стоит вне доски" % entity.id)
			continue
		if terrain.is_hole(cell):
			errors.append("сущность %s стоит в вырезе террейна" % entity.id)
			continue
		# Missing packs are deliberately allowed; when an archetype is present its
		# declared states are authoritative and a typo must not reach runtime.
		var archetype := EntityArchetypeCatalog.get_archetype(entity.archetype_id)
		if archetype != null and not archetype.states.allows_initial_state(entity.initial_state):
			errors.append("сущность %s задаёт неизвестное состояние %s" % [entity.id, entity.initial_state])


## An anchor must stand on real, dry, passable ground — a spawn in a hole, under
## deep water, or on lava is a map that cannot start (§8.1, §11).
static func _validate_anchor_place(anchor: ZoneAnchorRecord, terrain: TerrainGrid, water: WaterGrid, errors: Array[String]) -> void:
	# Coordinates are centred on the world origin, exactly like TerrainGrid and
	# NavGrid. Never reintroduce a 0..N editor coordinate check here.
	var cell := anchor.cell()
	if terrain == null or not terrain.is_inside(cell):
		return
	if terrain != null and terrain.is_hole(cell):
		errors.append("точка %s стоит в вырезе террейна" % anchor.id)
		return
	if water != null and terrain != null:
		if water.is_lava(cell):
			errors.append("точка %s стоит в лаве" % anchor.id)
			return
		# Frozen water is walkable (ice); open water deeper than a ford is not.
		if water.has_water(cell) and not water.is_frozen(cell) and water.depth_steps_at(terrain, cell) > WaterGrid.FORD_MAX_DEPTH_STEPS:
			errors.append("точка %s стоит под непроходимой водой" % anchor.id)


## A hero-mode map must name where the hero appears (map_editor.md §11). The
## gate is `mode_id == hero`, not `hero_control != none`: `hero_control` defaults
## to third-person for every mode, so the looser check would demand a spawn on
## every settlement map too.
static func _validate_hero_start(document: MapDocument, errors: Array[String]) -> void:
	if document.meta.start.mode_id != MapStart.MODE_HERO:
		return
	if document.meta.start.hero_control() == MapStart.HERO_CONTROL_NONE:
		return
	for anchor in document.zones.anchors:
		if anchor.role == ZoneAnchorRecord.ROLE_SPAWN and anchor.function == MapSpawnService.HERO_START:
			return
	errors.append("hero-режим карты требует хотя бы одну spawn-точку (hero_start)")


## Reachability-grade findings: a map launches with them, but the author very
## likely did not mean them (map_editor.md §11 warnings). Returns nothing when
## `nav_grid` is null — these checks are the editor's "Проверить" button's job,
## not the save path's, and save never has a published navigation field.
static func warnings(document: MapDocument, nav_grid: NavGrid) -> Array[String]:
	var warnings: Array[String] = []
	if nav_grid == null:
		return warnings
	# An anchor standing on an impassable cell is reachable only by teleport.
	# A spawn there is already an error in `validate` (hole/water); this catches
	# the navigation-blocked case — a waypoint on a cliff, a slot behind a wall.
	for anchor in document.zones.anchors:
		_warn_if_anchor_unreachable(anchor, nav_grid, warnings)
	# A route whose consecutive stops are not connected by NavGrid cannot be
	# walked. The route record already verified each stop exists; this checks the
	# ground between them. `once`/`loop`/`pingpong` differ in traversal, not in
	# whether each edge is walkable, so a single forward pass covers them.
	for route in document.zones.routes:
		_warn_if_route_breaks(route, document, nav_grid, warnings)
	return warnings


static func _warn_if_anchor_unreachable(anchor: ZoneAnchorRecord, nav_grid: NavGrid, warnings: Array[String]) -> void:
	var cell := anchor.cell()
	if not nav_grid.is_board_cell(cell):
		return
	# `is_walkable` folds in water/lava/cliff passability for the pedestrian
	# profile; a cell that fails it is one no agent can stand on.
	if not nav_grid.is_walkable(cell):
		warnings.append("точка %s стоит на непроходимой клетке" % anchor.id)


static func _warn_if_route_breaks(route: ZoneRouteRecord, document: MapDocument, nav_grid: NavGrid, warnings: Array[String]) -> void:
	if route.stops.size() < 2:
		return
	var previous: Vector2i = Vector2i.MIN
	for index in route.stops.size():
		var anchor := document.zones.anchor_by_id(route.stops[index])
		if anchor == null:
			return # `MapZoneLayer.validate` already flagged the dangling stop.
		var cell := anchor.cell()
		if index > 0 and not nav_grid.are_cells_connected(previous, cell):
			warnings.append("маршрут %s: остановки %s и %s не связаны проходимым путём" % [route.id, route.stops[index - 1], route.stops[index]])
			return # one broken edge per route is enough; the author fixes forward
		previous = cell
