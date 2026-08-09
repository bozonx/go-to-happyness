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
	_validate_placements(document, terrain, nav_grid, errors)
	_validate_scenario(document, errors)
	_validate_starts(document, errors)
	return errors


## Buildings standing on the map (`building_placement.md` §14).
##
## Everything here is a launch blocker, and each of them is a map that opens fine
## in the editor: a footprint half off the board, two buildings on one column, a
## blueprint that is no longer installed, an entrance nobody can walk to. The last
## one is the reason this check exists at all — a walled-in door is invisible, the
## building looks placed and works as scenery.
static func _validate_placements(
	document: MapDocument, terrain: TerrainGrid, nav_grid: NavGrid, errors: Array[String],
) -> void:
	var ids: Dictionary = {}
	var claimed: Array[Dictionary] = []
	var placement_obstacles: Dictionary = {}
	for placed: MapPlacementRecord in document.placements.placements:
		for occupied: Vector2i in BuildingPlacementService.footprint_of(placed).cells():
			placement_obstacles[occupied] = placed.id
	for record: MapPlacementRecord in document.placements.placements:
		if record.id == &"" or ids.has(record.id):
			errors.append("дубликат или пустой id размещения: %s" % record.id)
			continue
		ids[record.id] = true
		var blueprint := BuildingPlacementService.blueprint_of(record)
		if blueprint == null:
			errors.append("размещение %s ссылается на отсутствующий чертёж %s (роль %s)" % [
				record.id, record.blueprint_id(), record.blueprint_role()])
			continue
		if record.state not in blueprint.known_placement_states():
			errors.append("размещение %s объявляет состояние %s, которого нет у чертежа" % [
				record.id, record.state])
		var footprint := BuildingFootprint.of(blueprint, record.cell, record.orientation)
		if terrain != null:
			if record.level_value != PlacementLevel.quantize(record.level_value):
				errors.append("здание %s хранит уровень площадки вне шага террасы" % record.id)
			var blueprint_is_current := record.blueprint_revision().is_empty() \
				or record.blueprint_revision() == blueprint.revision_id()
			var ground_mismatch := false
			var border_too_high := false
			var max_border_drop := PlacementPolicy.editor().max_border_drop
			for cell: Vector2i in footprint.cells():
				if not terrain.is_inside(cell):
					errors.append("здание %s выходит за пределы доски" % record.id)
					break
				if terrain.is_hole(cell) and not footprint.is_cut_out(cell):
					errors.append("пятно здания %s попадает в вырез террейна" % record.id)
					break
				if blueprint_is_current and not footprint.is_cut_out(cell) \
						and terrain.height_of(cell) != record.level_value + footprint.relative_height(cell):
					ground_mismatch = true
				for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
					var neighbour := cell + SlopeCatalog.direction_offset(direction)
					if footprint.contains(neighbour) or not terrain.is_inside(neighbour) \
							or terrain.is_hole(neighbour):
						continue
					if absi(terrain.height_of(cell) - terrain.height_of(neighbour)) \
							> max_border_drop:
						border_too_high = true
			if ground_mismatch:
				errors.append("рельеф под зданием %s не совпадает с сохранённым уровнем площадки" % record.id)
			if border_too_high:
				errors.append("перепад по границе здания %s больше допустимого" % record.id)
		for previous: Dictionary in claimed:
			if (previous["rect"] as Rect2i).intersects(footprint.rect()):
				errors.append("здания %s и %s занимают общие клетки" % [previous["id"], record.id])
		claimed.append({"id": record.id, "rect": footprint.rect()})
		var other_obstacles := placement_obstacles.duplicate()
		for own_cell: Vector2i in footprint.cells():
			if other_obstacles.get(own_cell, &"") == record.id:
				other_obstacles.erase(own_cell)
		for warning: String in BuildingPlacementService.entrance_warnings(
				footprint, nav_grid, "здание %s" % record.id, other_obstacles):
			errors.append(warning)


## Dangling references between the three things a start option ties together
## (`map_start.md` §13). Each of them produces a map that opens fine in the editor
## and fails at launch, which is the worst place to find out.
static func _validate_starts(document: MapDocument, errors: Array[String]) -> void:
	var start := document.meta.start
	if start.default_start != &"" and start.start_by_id(start.default_start) == null:
		errors.append("default_start ссылается на несуществующий вариант %s" % start.default_start)
	var ids: Dictionary = {}
	for option: MapStartOption in start.starts:
		if ids.has(option.id):
			errors.append("дублирующийся id варианта старта: %s" % option.id)
		ids[option.id] = true
		if option.spawn_group == &"":
			# Naming the gesture, not the record. An author who has never opened the
			# start dialog does not know what a spawn group is, and the map they are
			# looking at is missing a *point*, which is a thing they can put down.
			errors.append(
				"вариант старта %s не называет группу появления: поставьте точку старта партии "
				% option.id + "(режим «Зоны и точки» → W → роль spawn → функция «лидер партии»)")
		elif document.zones.spawn_group_by_id(option.spawn_group) == null:
			errors.append("вариант старта %s ссылается на несуществующую группу появления %s" % [
				option.id, option.spawn_group])
		if option.camera != &"":
			var camera := document.zones.anchor_by_id(option.camera)
			if camera == null:
				errors.append("вариант старта %s ссылается на несуществующую камеру %s" % [
					option.id, option.camera])
			elif MapSpawnService.canonical_function(camera.function) != MapSpawnService.CAMERA_START:
				errors.append("камера %s варианта %s не несёт функцию %s" % [
					option.camera, option.id, MapSpawnService.CAMERA_START])
	for entity: MapEntityRecord in document.entities.entities:
		for option_id: StringName in entity.starts:
			if not ids.has(option_id):
				errors.append("сущность %s привязана к несуществующему варианту старта %s" % [
					entity.id, option_id])


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


## Launch-time party validation (`map_start.md` §4.3, §13). `validate` stays
## reusable by the editor, where the intended population is not necessarily known;
## the game supplies its actual party size immediately before bootstrapping.
##
## This replaces the rule that a map must carry exactly `population - 1`
## companion anchors. That rule made the geometry own the party size, and its
## error message named anchors the player had never seen. What is checked now is
## whether the chosen entrance's group can hold the chosen party — a question
## about a clearing, which is a thing an author can look at and fix.
##
## `spawn_override` is the editor's "test from here" launch (`map_editor.md` §12).
## It replaces the whole group (§4.5), so demanding authored places on top of it
## would make the one feature that exists to skip authoring unusable on a
## half-drawn map.
static func validate_party_capacity(
	document: MapDocument,
	start_option: StringName,
	population: int,
	spawn_override := false,
) -> Array[String]:
	var errors: Array[String] = []
	if document == null:
		errors.append("для запуска нужна карта")
		return errors
	if spawn_override:
		return errors
	var option := document.meta.start.start_by_id(start_option)
	if option == null:
		option = document.meta.start.default_option(document.meta.start.game_definition)
	if option == null:
		errors.append(
			"карта не объявляет ни одного варианта старта: поставьте точку старта партии "
			+ "(режим «Зоны и точки» → W → роль spawn → функция «лидер партии») "
			+ "или заведите вариант в «Старт»")
		return errors
	var group := document.zones.spawn_group_by_id(option.spawn_group)
	if group == null:
		errors.append("вариант старта %s ссылается на несуществующую группу появления %s" % [
			option.id, option.spawn_group])
		return errors
	var service := MapSpawnService.new()
	# The document's own grids, so the check answers the question it claims to:
	# while nothing configured the service, "does the party fit" ignored holes,
	# lava, deep water and the rim of the board entirely, and the first thing the
	# author saw was settlers standing in a lake.
	service.configure(null, document.terrain, document.water)
	var plan := service.plan_party(document.zones, group, population, document.meta.cell_size)
	if not plan.ok:
		errors.append(plan.reason)
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
		if entity.scale <= 0.0:
			errors.append("сущность %s задаёт небезопасный масштаб %.3f" % [entity.id, entity.scale])
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


## An anchor a unit stands on must stand on real, dry, passable ground — a spawn
## in a hole, under deep water, or on lava is a map that cannot start (§8.1, §11).
##
## **`poi` is exempt, and that is the whole point of the role.** `core:camera_start`
## is authored as a `poi` precisely so an establishing shot may look from over the
## water, off a cliff or past the rim of the board (`map_start.md` §4.1) — while
## this rule applied to every role indiscriminately, the design's own example was
## an error the author could not clear.
##
## Off the board is an error rather than a silent pass, for the same reason: a
## spawn nobody can reach is exactly what "outside the board" means, and returning
## early was how it left the check unnoticed.
static func _validate_anchor_place(anchor: ZoneAnchorRecord, terrain: TerrainGrid, water: WaterGrid, errors: Array[String]) -> void:
	if anchor.role == ZoneAnchorRecord.ROLE_POI:
		return
	# Coordinates are centred on the world origin, exactly like TerrainGrid and
	# NavGrid. Never reintroduce a 0..N editor coordinate check here.
	var cell := anchor.cell()
	if terrain == null:
		return
	if not terrain.is_inside(cell):
		errors.append("точка %s стоит за краем доски" % anchor.id)
		return
	if terrain.is_hole(cell):
		errors.append("точка %s стоит в вырезе террейна" % anchor.id)
		return
	if water != null:
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
	_warn_about_starts(document, warnings)
	_warn_about_placements(document, warnings)
	if nav_grid == null:
		return warnings
	_warn_about_separated_buildings(document, nav_grid, warnings)
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


## Start findings a map still launches with (`map_start.md` §13). Missing
## `default_start` is deliberately not an error: the map runs, and the obligation
## it creates falls on the menu, which has to ask.
static func _warn_about_starts(document: MapDocument, warnings: Array[String]) -> void:
	var start := document.meta.start
	if start.starts.size() > 1 and start.default_start == &"":
		warnings.append("несколько вариантов старта и не выбран стартовый по умолчанию")
	for group: MapSpawnGroup in document.zones.spawn_groups:
		if group.area_id == &"" and group.slots.size() < group.capacity:
			warnings.append("группа %s без области вмещает %d из объявленных %d" % [
				group.id, group.slots.size(), group.capacity])


## Placement findings a map still launches with (`building_placement.md` §14).
## The document carries its own grids, so these need no published navigation and
## run on the save path too.
static func _warn_about_placements(document: MapDocument, warnings: Array[String]) -> void:
	var terrain := document.terrain
	var water := document.water
	var footprints: Array[Dictionary] = []
	for record: MapPlacementRecord in document.placements.placements:
		var blueprint := BuildingPlacementService.blueprint_of(record)
		if blueprint == null:
			continue
		if not record.blueprint_revision().is_empty() \
				and record.blueprint_revision() != blueprint.revision_id():
			warnings.append("чертёж здания %s изменился с момента постановки" % record.id)
		var footprint := BuildingFootprint.of(blueprint, record.cell, record.orientation)
		if terrain == null:
			continue
		var submerged := false
		var walled := false
		for cell: Vector2i in footprint.cells():
			if not terrain.is_inside(cell):
				continue
			if water != null and water.is_wet(terrain, cell):
				submerged = true
			walled = walled or _edge_is_walled(terrain, footprint, cell)
		if submerged and blueprint.expects_surface == BuildingBlueprint.SURFACE_GROUND:
			warnings.append("здание %s стоит в воде вопреки объявленной опоре чертежа" % record.id)
		elif not submerged and blueprint.expects_surface == BuildingBlueprint.SURFACE_WATER:
			warnings.append("здание %s стоит на суше вопреки объявленной опоре чертежа" % record.id)
		if walled:
			warnings.append("у здания %s есть граница без выезда" % record.id)
		for previous: Dictionary in footprints:
			if (previous["rect"] as Rect2i).grow(1).intersects(footprint.rect()):
				warnings.append("между зданиями %s и %s нет минимального зазора в 1 клетку" % [
					previous["id"], record.id])
		footprints.append({"id": record.id, "rect": footprint.rect()})
		for entity: MapEntityRecord in document.entities.entities:
			var entity_cell := entity.cell(terrain)
			if not footprint.contains(entity_cell):
				continue
			if water != null and water.is_wet(terrain, entity_cell):
				warnings.append("объект %s под зданием %s оказался в воде или лаве" % [entity.id, record.id])
			else:
				warnings.append("объект %s остаётся под пятном здания %s" % [entity.id, record.id])


## An edge of a pad that drops to lower ground with no ramp climbing back up to
## it is a retaining wall — normal in a town, and the absence of a way out.
static func _edge_is_walled(terrain: TerrainGrid, footprint: BuildingFootprint, cell: Vector2i) -> bool:
	for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
		var neighbour := cell + SlopeCatalog.direction_offset(direction)
		if footprint.contains(neighbour) or not terrain.is_inside(neighbour) or terrain.is_hole(neighbour):
			continue
		if terrain.height_of(cell) <= terrain.height_of(neighbour):
			continue
		var climbs_here := terrain.is_ramp_cell(neighbour) \
			and terrain.slope_direction_of(neighbour) == SlopeCatalog.opposite_direction(direction)
		if not climbs_here:
			return true
	return false


## A building that cuts the only way to another one (§14). Checked as one
## question — are all the entrances on this map on one connected component of the
## routing field — because that is what an author means by "the settlement is cut
## in two", and it is n-1 queries instead of n².
static func _warn_about_separated_buildings(
	document: MapDocument, nav_grid: NavGrid, warnings: Array[String],
) -> void:
	var reference := Vector2i.MIN
	var reference_id: StringName = &""
	for record: MapPlacementRecord in document.placements.placements:
		var footprint := BuildingPlacementService.footprint_of(record)
		for approach: Vector2i in footprint.door_approach_cells():
			if not nav_grid.is_board_cell(approach) or not nav_grid.is_walkable(approach):
				continue
			if reference == Vector2i.MIN:
				reference = approach
				reference_id = record.id
				break
			if not nav_grid.are_cells_connected(reference, approach):
				warnings.append("к зданию %s нет прохода от здания %s" % [record.id, reference_id])
			break


static func _warn_if_anchor_unreachable(anchor: ZoneAnchorRecord, nav_grid: NavGrid, warnings: Array[String]) -> void:
	# A `poi` is not stood on (see `_validate_anchor_place`): warning that the
	# start camera hangs over impassable water is noise about the intended case.
	if anchor.role == ZoneAnchorRecord.ROLE_POI:
		return
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
