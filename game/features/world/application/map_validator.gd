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
	_validate_coverage(document, terrain, water, errors)
	_validate_entities(document, terrain, errors)
	_validate_scenario(document, errors)
	return errors


## A valid stroke can become invalid after the author reshapes the terrain under
## it. The brush rejects new bad cells, while this cross-layer validation guards
## the saved result without silently deleting authored coverage from a terrain
## command's undo entry.
static func _validate_coverage(
	document: MapDocument,
	terrain: TerrainGrid,
	water: WaterGrid,
	errors: Array[String],
) -> void:
	if document == null or document.coverage == null:
		return
	var service := CoverageService.new()
	service.configure(document.coverage, terrain, water)
	var findings: Dictionary = {}
	for cell: Vector2i in document.coverage.covered_cells():
		var index := document.coverage.index_at(cell)
		var reason := service.coverage_placement_rejection(cell, index)
		if reason == CoverageService.REASON_NONE:
			continue
		var key := "%d:%s" % [index, reason]
		var finding: Dictionary = findings.get(key, {
			"index": index,
			"reason": reason,
			"count": 0,
			"example": cell,
		})
		finding["count"] = int(finding["count"]) + 1
		findings[key] = finding
	for finding: Dictionary in findings.values():
		var title := CoverageCatalog.title_of_index(int(finding["index"]))
		var reason: StringName = finding["reason"]
		var explanation := "на слишком крутом уклоне" \
			if reason == CoverageService.REASON_SLOPE_TOO_STEEP else "на неподходящей поверхности"
		errors.append("покрытие %s: %d клеток %s (например %s)" % [
			title, int(finding["count"]), explanation, finding["example"],
		])


## Launch-time party validation. `validate` stays reusable by the editor, where
## the intended population is not necessarily known; the game supplies its
## actual party size immediately before bootstrapping a session.
## `spawn_override` is the editor's "test from here" launch (`map_editor.md` §12).
## It supplies the party start itself, so demanding authored anchors on top of it
## would make the one feature that exists to skip authoring impossible to use on
## a half-drawn map.
static func validate_party_spawns(document: MapDocument, population: int, spawn_override := false) -> Array[String]:
	var errors: Array[String] = []
	if document == null:
		errors.append("для запуска нужна карта")
		return errors
	if spawn_override:
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
	var occupied: Array[Dictionary] = []
	for entity: MapEntityRecord in document.entities.entities:
		if entity.id == &"" or ids.has(entity.id):
			errors.append("дубликат или пустой id сущности: %s" % entity.id)
			continue
		ids[entity.id] = true
		if terrain == null:
			continue
		# Missing packs are deliberately allowed; when an archetype is present its
		# declared states are authoritative and a typo must not reach runtime.
		var archetype := EntityArchetypeCatalog.get_archetype(entity.archetype_id)
		if archetype == null:
			var fallback_cell := entity.cell(terrain)
			if not terrain.is_inside(fallback_cell):
				errors.append("сущность %s стоит вне доски" % entity.id)
			elif terrain.is_hole(fallback_cell):
				errors.append("сущность %s стоит в вырезе террейна" % entity.id)
			continue
		if not archetype.states.allows_initial_state(entity.initial_state):
			errors.append("сущность %s задаёт неизвестное состояние %s" % [entity.id, entity.initial_state])
		var asset := EntityArchetypeCatalog.asset_of(archetype.id)
		if asset == null:
			continue
		if not asset.is_scale_allowed(entity.scale):
			errors.append("сущность %s задаёт недопустимый масштаб %.3f" % [entity.id, entity.scale])
		if not is_zero_approx(entity.yaw_degrees) and not asset.is_rotation_axis_allowed("y"):
			errors.append("сущность %s вращается вокруг запрещённой оси Y" % entity.id)
		for property_name: Variant in entity.props.keys():
			if archetype.get_property(StringName(property_name)) == null:
				errors.append("сущность %s задаёт неизвестное свойство %s" % [entity.id, property_name])
		var span := asset.placement_cell_span(entity.scale, entity.yaw_degrees)
		var anchor := entity.anchor_position()
		var base_cell := Vector2i(
			int(round(anchor.x / terrain.cell_size - float(span.x) * 0.5)),
			int(round(anchor.z / terrain.cell_size - float(span.y) * 0.5)),
		)
		var cells := Rect2i(base_cell, span)
		var footprint_valid := true
		for x in range(cells.position.x, cells.end.x):
			for z in range(cells.position.y, cells.end.y):
				var footprint_cell := Vector2i(x, z)
				if not terrain.is_inside(footprint_cell):
					errors.append("сущность %s выходит footprint за пределы доски" % entity.id)
					footprint_valid = false
					break
				if terrain.is_hole(footprint_cell):
					errors.append("footprint сущности %s попадает в вырез террейна" % entity.id)
					footprint_valid = false
					break
			if not footprint_valid:
				break
		if asset.claims_cells():
			for previous: Dictionary in occupied:
				if cells.intersects(previous["cells"]):
					errors.append("сущности %s и %s занимают общие клетки" % [previous["id"], entity.id])
			occupied.append({"id": entity.id, "cells": cells})


## Scenario references that need the rest of the document (map_editor.md §11).
## `MapScenario.validate` already caught what the layer can see on its own —
## duplicate ids, undeclared flags — so this adds only the cross-layer rule: a
## trigger addressing an area that no longer exists. A rule pointing at a deleted
## zone never fires, and silence is the one failure an author cannot debug.
static func _validate_scenario(document: MapDocument, errors: Array[String]) -> void:
	errors.append_array(document.scenario.validate())
	for zone_id: StringName in document.scenario.referenced_zones():
		if document.zones.area_by_id(zone_id) == null:
			errors.append("правило ссылается на несуществующую область %s" % zone_id)


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
		if water.is_wet(terrain, cell) and water.is_lava(cell):
			errors.append("точка %s стоит в лаве" % anchor.id)
			return
		# Frozen water is walkable (ice); open water deeper than a ford is not.
		if water.is_wet(terrain, cell) and not water.is_frozen(cell) and water.depth_steps_at(terrain, cell) > WaterGrid.FORD_MAX_DEPTH_STEPS:
			errors.append("точка %s стоит под непроходимой водой" % anchor.id)


## Reachability-grade findings: a map launches with them, but the author very
## likely did not mean them (map_editor.md §11 warnings). Returns nothing when
## `nav_grid` is null — these checks are the editor's "Проверить" button's job,
## not the save path's, and save never has a published navigation field.
static func warnings(document: MapDocument, nav_grid: NavGrid) -> Array[String]:
	var warnings: Array[String] = []
	# Scenario findings need no grids, so they are produced before the navigation
	# guard below: an unreachable objective is a navigation question, but a rule
	# that can never fire is answerable from the document alone.
	_warn_about_scenario(document, warnings)
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


## Scenario problems a map still launches with (map_editor.md §11). Each of them
## produces a rule that quietly does nothing, which is the class of bug an author
## has no way to see from inside the game.
static func _warn_about_scenario(document: MapDocument, warnings: Array[String]) -> void:
	var scenario := document.scenario
	if scenario.is_empty():
		return
	if scenario.victory.is_empty() and scenario.defeat.is_empty() \
			and document.meta.map_kind == MapMeta.MAP_KIND_SCENARIO:
		warnings.append("сценарная карта без условий победы и поражения")
	var written: Dictionary = {}
	for rule: MapRule in scenario.rules:
		for action: MapRuleAction in rule.actions:
			if action.writes_flag():
				written[action.flag] = true
		if not rule.enabled:
			continue
		# `actor` is authored but not yet delivered: the bus identifies agents by
		# a runtime id no map can name, so a rule filtering on one never matches.
		if rule.trigger.actor != &"":
			warnings.append("правило %s фильтрует по actor — на этом этапе такое правило не сработает" % rule.id)
		if rule.actions.is_empty():
			warnings.append("правило %s ничего не делает" % rule.id)
	# A win condition over a flag nothing ever sets cannot be reached. The reverse
	# (a flag written but never read) is normal — an author often declares state
	# before writing the rule that consumes it — so it is not reported.
	for condition: MapRuleCondition in scenario.victory + scenario.defeat:
		for flag_id: StringName in condition.referenced_flags():
			var declared := scenario.flag_by_id(flag_id)
			if declared != null and not written.has(flag_id):
				warnings.append("условие исхода читает флаг %s, который ни одно правило не меняет" % flag_id)


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
