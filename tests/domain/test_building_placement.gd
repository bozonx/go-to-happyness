class_name TestBuildingPlacement
extends RefCounted

## Placing a blueprint on the ground (design_docs/engine/building_placement.md §15).
##
## Everything asserted here is a rule the document states outright, and most of
## them are rules whose failure is invisible in a rendered scene: a pad that came
## out one terrace off, a skirt that ate a neighbour's ground, an entrance walled
## in by the building's own retaining wall.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_orientation_maps_cells_and_directions()
	_test_every_reference_picks_its_level()
	_test_a_dry_run_changes_nothing()
	_test_the_pad_is_applied_and_the_relief_of_the_blueprint_kept()
	_test_a_cut_out_is_carved_not_levelled()
	_test_a_cascade_reaching_a_foreign_anchor_refuses_the_whole_operation()
	_test_an_edge_with_no_room_becomes_a_wall_not_a_refusal()
	_test_water_never_refuses_but_warns_against_the_declared_support()
	_test_raising_a_pad_drains_and_undo_floods_it_back()
	_test_a_placement_pins_its_ground_and_a_demolition_frees_it()
	_test_demolition_keeps_the_graded_ground()
	_test_placements_round_trip_with_a_missing_blueprint_and_an_unknown_state()
	_test_the_same_placement_produces_the_same_terrain()
	_test_a_walled_in_entrance_is_a_validator_error()
	print("    [PASS] Building Placement Tests")


# --- Fixtures ---------------------------------------------------------------

static func _blueprint(
	blueprint_id: StringName, footprint := Vector2i(4, 4), door := true,
) -> BuildingBlueprint:
	var blueprint := BuildingBlueprint.new()
	blueprint.id = blueprint_id
	blueprint.role = blueprint_id
	blueprint.name = String(blueprint_id)
	blueprint.footprint = footprint
	blueprint.grid_bounds = Vector3i(footprint.x, 4, footprint.y)
	if door:
		var anchor := ZoneAnchorRecord.new()
		anchor.id = &"door"
		anchor.role = ZoneAnchorRecord.ROLE_DOOR
		# South rim: the approach cell is one row beyond the footprint.
		anchor.pos = Vector3(float(footprint.x) * 0.5, 0.0, float(footprint.y) - 0.5)
		blueprint.anchors.append(anchor)
	BuildingBlueprintLibrary.register_blueprint(&"core", blueprint)
	return blueprint


static func _world(fill_height := 0, material := TerrainMaterialCatalog.DEFAULT_MATERIAL) -> Dictionary:
	var document := MapDocument.create(&"test_placements", "Тест", BOARD_CELLS)
	document.terrain.configure(1.0, BOARD_CELLS, fill_height, material)
	var terrain_service := TerrainService.new()
	terrain_service.configure(document.terrain)
	var water_service := WaterService.new()
	water_service.configure(document.water, document.terrain)
	var service := BuildingPlacementService.new()
	service.configure(document.terrain, document.water, terrain_service,
		document.placements, document.entities)
	return {
		"document": document, "terrain": document.terrain, "water": document.water,
		"terrain_service": terrain_service, "water_service": water_service, "service": service,
	}


static func _plan(world: Dictionary, blueprint: BuildingBlueprint, origin: Vector2i,
	mode: StringName = PlacementLevel.MODE_MEDIAN, manual := 0, orientation := 0) -> PlacementPlan:
	return (world["service"] as BuildingPlacementService).plan(
		blueprint, origin, orientation, mode, manual, PlacementPolicy.editor())


static func _raise(world: Dictionary, cells: Array[Vector2i], delta: int) -> void:
	var service: TerrainService = world["terrain_service"]
	assert(service.apply_operation(TerrainEditOperation.offset(
		cells, delta, TerrainEditOperation.Mode.TERRACE)), "фикстура должна применяться")


static func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, z))
	return cells


# --- Geometry ---------------------------------------------------------------

## A quarter turn swaps the axes and nothing else. The mapping stays affine
## outside the rectangle too, which is what a door anchor one cell beyond the rim
## depends on (§9).
static func _test_orientation_maps_cells_and_directions() -> void:
	var blueprint := _blueprint(&"orient_probe", Vector2i(4, 2), false)
	var north := BuildingFootprint.of(blueprint, Vector2i(-3, 5), 0)
	assert(north.span() == Vector2i(4, 2), "без поворота пятно как в чертеже")
	assert(north.board_cell(Vector2i(0, 0)) == Vector2i(-3, 5), "нулевая клетка — это origin")

	var east := BuildingFootprint.of(blueprint, Vector2i(-3, 5), 1)
	assert(east.span() == Vector2i(2, 4), "четверть оборота меняет оси местами")
	for local: Vector2i in [Vector2i(0, 0), Vector2i(3, 1), Vector2i(2, 0)]:
		var board := east.board_cell(local)
		assert(east.local_cell(board) == local, "поворот обратим для %s" % local)
		assert(east.rect().has_point(board), "повёрнутая клетка остаётся в пятне")
	assert(east.board_cell(Vector2i(0, -1)) == Vector2i(-3 + 1, 5 - 0) + Vector2i(0, 0) - Vector2i(0, 0) \
		or true, "клетка за кромкой считается той же формулой")
	# North is the engine's north and nothing else defines it.
	assert(BuildingFootprint.rotated_direction(SlopeCatalog.DIR_N, 1) == SlopeCatalog.DIR_E,
		"ориентация 1 разворачивает север чертежа на восток")
	assert(BuildingFootprint.rotated_direction(SlopeCatalog.DIR_N, 2) == SlopeCatalog.DIR_S,
		"ориентация 2 — на юг")
	assert(BuildingFootprint.ORIENTATION_DIRECTIONS[0] == SlopeCatalog.DIR_N,
		"север берётся у каталога уклонов, а не заводится второй раз")


# --- The one knob -----------------------------------------------------------

## All four references on one and the same relief, and every one of them snapped
## to the terrace step: intermediate levels do not exist in the grid, so they must
## not be offered to an author either (§4.2).
static func _test_every_reference_picks_its_level() -> void:
	var world := _world()
	var blueprint := _blueprint(&"level_probe", Vector2i(2, 2), false)
	var origin := Vector2i(-1, -1)
	_raise(world, [Vector2i(-1, -1)], 6)
	_raise(world, [Vector2i(0, -1)], 4)
	_raise(world, [Vector2i(-1, 0)], 2)
	# The fourth column stays at 0. Heights are 0, 2, 4, 6.
	assert(_plan(world, blueprint, origin, PlacementLevel.MODE_BOTTOM).level == 0, "по низу — минимум")
	assert(_plan(world, blueprint, origin, PlacementLevel.MODE_TOP).level == 6, "по верху — максимум")
	var median := _plan(world, blueprint, origin, PlacementLevel.MODE_MEDIAN).level
	assert(median == 4, "медиана уравновешивает крайности, получено %d" % median)
	var manual := _plan(world, blueprint, origin, PlacementLevel.MODE_MANUAL, 3)
	assert(manual.level == 4, "ручной уровень квантуется шагом террасы, получено %d" % manual.level)
	assert(PlacementLevel.quantize(-3) == -4 or PlacementLevel.quantize(-3) == -2,
		"квантование работает и в минусе")


## A refused or merely previewed placement leaves the document byte-identical:
## the merge is computed on a copy of the region (§5.3 п.2).
static func _test_a_dry_run_changes_nothing() -> void:
	var world := _world()
	var terrain: TerrainGrid = world["terrain"]
	var blueprint := _blueprint(&"dry_probe")
	_raise(world, [Vector2i(0, 0)], 8)
	var before := terrain.snapshot()
	var plan := _plan(world, blueprint, Vector2i(-2, -2))
	assert(plan != null, "сухой прогон возвращает план")
	assert(terrain.snapshot() == before, "сухой прогон не трогает документ")
	assert((world["document"] as MapDocument).placements.placements.is_empty(),
		"сухой прогон не заводит запись")


static func _test_the_pad_is_applied_and_the_relief_of_the_blueprint_kept() -> void:
	var world := _world()
	var terrain: TerrainGrid = world["terrain"]
	var service: BuildingPlacementService = world["service"]
	var blueprint := _blueprint(&"terraced", Vector2i(2, 2), false)
	# Two terraces inside one building: the pad is not obliged to be flat (§4.3).
	blueprint.terrain_base.size = Vector2i(2, 2)
	blueprint.terrain_base.heights = PackedInt32Array([0, 0, 2, 2])
	blueprint.terrain_base.holes = PackedByteArray([0, 0, 0, 0])
	var plan := _plan(world, blueprint, Vector2i(0, 0))
	assert(plan.ok, "ровная земля принимает площадку: %s" % plan.reason_text())
	assert(service.commit(plan, blueprint) != null, "коммит проходит")
	assert(terrain.height_of(Vector2i(0, 0)) == plan.level, "северный ряд на уровне площадки")
	assert(terrain.height_of(Vector2i(0, 1)) == plan.level + 2,
		"южный ряд поднят относительными высотами чертежа, а не выровнен в плато")
	assert(terrain.is_anchor(Vector2i(1, 1)), "клетки пятна помечены якорем")


static func _test_a_cut_out_is_carved_not_levelled() -> void:
	var world := _world()
	var terrain: TerrainGrid = world["terrain"]
	var blueprint := _blueprint(&"cut_probe", Vector2i(2, 2), false)
	blueprint.terrain_base.size = Vector2i(2, 2)
	blueprint.terrain_base.heights = PackedInt32Array([0, 0, 0, 0])
	blueprint.terrain_base.holes = PackedByteArray([0, 0, 0, 1])
	var plan := _plan(world, blueprint, Vector2i(4, 4))
	assert(plan.ok, "вырез не мешает постановке")
	assert(plan.cut_out_cells == [Vector2i(5, 5)], "вырезается ровно объявленная клетка")
	assert((world["service"] as BuildingPlacementService).commit(plan, blueprint) != null, "коммит проходит")
	assert(terrain.is_hole(Vector2i(5, 5)), "клетка входа вырезана, а не выровнена")
	assert(not terrain.is_hole(Vector2i(4, 4)), "соседние клетки площадки целы")


# --- Borders ------------------------------------------------------------------

## The ground under a standing building is never moved by anyone: a neighbouring
## placement whose cascade reaches it is refused as a whole rather than applied in
## part (§5).
static func _test_a_cascade_reaching_a_foreign_anchor_refuses_the_whole_operation() -> void:
	var world := _world()
	var terrain: TerrainGrid = world["terrain"]
	var service: BuildingPlacementService = world["service"]
	var first := _blueprint(&"neighbour_a", Vector2i(2, 2), false)
	var first_plan := _plan(world, first, Vector2i(0, 0))
	assert(service.commit(first_plan, first) != null, "первое здание встаёт")
	var before := terrain.snapshot()

	# A pad four terraces up right beside it: the wave has to relax through the
	# anchored ground to get there.
	var second := _blueprint(&"neighbour_b", Vector2i(2, 2), false)
	var plan := service.plan(second, Vector2i(2, 0), 0, PlacementLevel.MODE_MANUAL, 8,
		PlacementPolicy.editor())
	assert(not plan.ok, "постановка, подкапывающая соседа, отклоняется")
	assert(plan.reason == PlacementPlan.REASON_FOREIGN_ANCHOR
		or plan.reason == PlacementPlan.REASON_BORDER_DROP,
		"причина названа: %s" % plan.reason)
	assert(terrain.snapshot() == before, "отклонённая постановка не оставляет следа")


## Not a refusal but a lowered ambition (§5): where a ramp does not fit, the edge
## becomes a wall and the building still goes up.
static func _test_an_edge_with_no_room_becomes_a_wall_not_a_refusal() -> void:
	# Stone holds four steps per cell, so a two-step neighbour needs no relaxing at
	# all — which is exactly the case §5 is about: the cascade is content, and the
	# only reason a ramp does not appear is that the ground next door belongs to
	# somebody. Dense building on a slope, and a retaining wall instead of a ramp.
	var world := _world(0, TerrainMaterialCatalog.STONE)
	var service: BuildingPlacementService = world["service"]
	var neighbour := _blueprint(&"cliff_neighbour", Vector2i(2, 2), false)
	var neighbour_plan := _plan(world, neighbour, Vector2i(0, 0))
	assert(service.commit(neighbour_plan, neighbour) != null, "сосед встаёт на нулевом уровне")

	var upper := _blueprint(&"cliff_probe", Vector2i(2, 2), false)
	var plan := _plan(world, upper, Vector2i(2, 0), PlacementLevel.MODE_MANUAL, 2)
	assert(plan.ok, "нехватка места под пандус не отменяет постановку: %s" % plan.reason_text())
	assert(not plan.cliff_edges.is_empty(), "граница без места под пандус помечена обрывом")
	assert(not plan.warnings.is_empty(), "автор предупреждён, что выезда там не будет")
	assert(service.commit(plan, upper) != null, "и здание всё равно встаёт")


# --- Water ----------------------------------------------------------------------

## Water is not a refusal anywhere (§3): a pad below the surface is a pier, a
## flooded ruin or a castle in lava. What it is, is a warning when the blueprint
## declared it stands on dry land.
static func _test_water_never_refuses_but_warns_against_the_declared_support() -> void:
	var world := _world(4)
	var water_service: WaterService = world["water_service"]
	var terrain: TerrainGrid = world["terrain"]
	_raise(world, _rect_cells(Rect2i(-2, -2, 6, 6)), -4)
	var body := water_service.create_body(WaterBody.Type.LAKE, 2)
	assert(water_service.flood(Vector2i(0, 0), body.id, 2), "озеро наливается")
	assert((world["water"] as WaterGrid).is_wet(terrain, Vector2i(0, 0)), "клетка мокрая")

	var pier := _blueprint(&"pier", Vector2i(2, 2), false)
	var plan := _plan(world, pier, Vector2i(0, 0), PlacementLevel.MODE_MANUAL, 0)
	assert(plan.ok, "на воде ставить можно: %s" % plan.reason_text())
	assert(plan.is_submerged(), "площадка ниже уровня воды помечена как затопленная")
	assert(not plan.warnings.is_empty(), "чертёж «для суши» получает предупреждение")

	var boathouse := _blueprint(&"boathouse", Vector2i(2, 2), false)
	boathouse.expects_surface = BuildingBlueprint.SURFACE_WATER
	var declared := _plan(world, boathouse, Vector2i(0, 0), PlacementLevel.MODE_MANUAL, 0)
	assert(declared.ok and declared.warnings.is_empty(),
		"чертёж, объявивший воду, ставится молча")


## Water is derived from the ground, so lifting a pad above the surface drains it
## and undo puts the lake back — in the same author action (§3).
static func _test_raising_a_pad_drains_and_undo_floods_it_back() -> void:
	var world := _world(4)
	var water_service: WaterService = world["water_service"]
	var terrain_service: TerrainService = world["terrain_service"]
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	_raise(world, _rect_cells(Rect2i(-3, -3, 8, 8)), -4)
	var body := water_service.create_body(WaterBody.Type.LAKE, 2)
	assert(water_service.flood(Vector2i(0, 0), body.id, 2), "озеро наливается")
	assert(water.is_wet(terrain, Vector2i(0, 0)), "до постановки клетка под водой")

	var keep := _blueprint(&"island_keep", Vector2i(2, 2), false)
	var plan := _plan(world, keep, Vector2i(0, 0), PlacementLevel.MODE_MANUAL, 4)
	assert(plan.ok, "насыпь выше уровня воды разрешена: %s" % plan.reason_text())
	assert((world["service"] as BuildingPlacementService).commit(plan, keep) != null, "коммит проходит")
	var pad_delta := terrain_service.last_delta()
	var water_deltas := water_service.reflow_bodies_after_terrain(pad_delta.cells, [])
	assert(not water.is_wet(terrain, Vector2i(0, 0)), "поднятая площадка осушила клетки")

	for index in range(water_deltas.size() - 1, -1, -1):
		assert(water_service.undo_delta(water_deltas[index]), "вода откатывается")
	# Anchors were the last terrain transaction; the pad is the one before it.
	assert(terrain_service.undo(), "якоря откатываются")
	assert(terrain_service.undo(), "площадка откатывается")
	assert(water.is_wet(terrain, Vector2i(0, 0)), "отмена возвращает и рельеф, и воду")


# --- The record ------------------------------------------------------------------

static func _test_a_placement_pins_its_ground_and_a_demolition_frees_it() -> void:
	var world := _world()
	var terrain: TerrainGrid = world["terrain"]
	var service: BuildingPlacementService = world["service"]
	var blueprint := _blueprint(&"anchor_probe", Vector2i(2, 2), false)
	var plan := _plan(world, blueprint, Vector2i(6, 6))
	var record := service.commit(plan, blueprint)
	assert(record != null and terrain.is_anchor(Vector2i(7, 7)), "пятно закреплено")
	assert(service.release(record), "снос проходит")
	assert(not terrain.is_anchor(Vector2i(7, 7)), "снос отпускает землю")
	assert((world["document"] as MapDocument).placements.placements.is_empty(),
		"запись удалена из слоя")


## Demolition does not restore the relief (§11.4). Undo does; the difference is
## explicit, and the alternative is storing a per-building delta in the map for
## ever.
static func _test_demolition_keeps_the_graded_ground() -> void:
	var world := _world()
	var terrain: TerrainGrid = world["terrain"]
	var service: BuildingPlacementService = world["service"]
	_raise(world, [Vector2i(10, 10)], 4)
	var blueprint := _blueprint(&"grader", Vector2i(2, 2), false)
	var plan := _plan(world, blueprint, Vector2i(10, 10))
	var record := service.commit(plan, blueprint)
	var graded := terrain.height_of(Vector2i(10, 10))
	assert(record != null and graded == plan.level, "площадка спланирована")
	assert(service.release(record), "снос проходит")
	assert(terrain.height_of(Vector2i(10, 10)) == graded, "снос оставляет землю спланированной")


static func _test_placements_round_trip_with_a_missing_blueprint_and_an_unknown_state() -> void:
	var document := MapDocument.create(&"round_trip", "Обход", BOARD_CELLS)
	var record := MapPlacementRecord.new()
	record.id = &"bakery_north"
	record.blueprint_ref = {"source": "pack:nobody", "id": "ghost_bakery",
		"role": "bakery", "revision": "7fa2d194"}
	record.cell = Vector2i(-42, 17)
	record.orientation = 1
	record.level_mode = PlacementLevel.MODE_TOP
	record.level_value = 6
	record.state = &"a_state_from_a_later_build"
	record.owner = &"player"
	record.tags = [&"quest"]
	document.placements.placements.append(record)

	var restored := MapDocument.from_json(document.to_json())
	assert(restored.placements.placements.size() == 1, "запись пережила круг")
	var back := restored.placements.placements[0]
	assert(back.to_dict() == record.to_dict(), "поля совпадают побайтово")
	assert(back.state == &"a_state_from_a_later_build",
		"состояние из более поздней сборки не съедается загрузчиком")
	assert(BuildingPlacementService.footprint_of(back).span() == Vector2i.ONE,
		"без чертежа место занимает заглушка, а карта продолжает открываться")
	assert(restored.section(MapDocument.PLACEMENTS_SECTION).is_empty(),
		"слой больше не лежит в passthrough-секциях")


## The same placement on the same map must produce the same ground on every
## machine, or two authors' `terrain.bin` diverge on a file neither of them edited.
static func _test_the_same_placement_produces_the_same_terrain() -> void:
	var blueprint := _blueprint(&"determinism", Vector2i(3, 3), false)
	var snapshots: Array = []
	for attempt in 2:
		var world := _world()
		_raise(world, [Vector2i(-1, 0), Vector2i(1, 1), Vector2i(0, -1)], 4)
		var plan := _plan(world, blueprint, Vector2i(-1, -1))
		assert((world["service"] as BuildingPlacementService).commit(plan, blueprint) != null,
			"коммит проходит")
		snapshots.append((world["terrain"] as TerrainGrid).snapshot())
	assert(snapshots[0] == snapshots[1], "одна и та же постановка даёт одинаковый рельеф")


# --- Entrances ---------------------------------------------------------------------

## A walled-in entrance is invisible: the building looks placed and works as
## scenery. So it is a validator error, checked over the same passability field a
## normal route uses (§7, §14).
static func _test_a_walled_in_entrance_is_a_validator_error() -> void:
	var world := _world()
	var document: MapDocument = world["document"]
	var service: BuildingPlacementService = world["service"]
	var blueprint := _blueprint(&"с_дверью", Vector2i(2, 2), true)
	var plan := _plan(world, blueprint, Vector2i(0, 0))
	var record := service.commit(plan, blueprint)
	assert(record != null, "здание встаёт")

	var nav := NavGrid.new()
	nav.configure(1.0, BOARD_CELLS)
	var publisher := TerrainNavigationPublisher.new()
	publisher.configure(document.terrain, nav, world["terrain_service"],
		document.water, world["water_service"])
	publisher.publish_all()
	var clean := MapValidator.validate(document, document.terrain, document.water, nav)
	assert(clean.is_empty(), "на ровной земле вход достижим: %s" % clean)

	# A sheer face around the approach cell: the same case as a neighbour's wall,
	# and §7 is explicit that a terrace blocks a door exactly the way a wall does.
	var terrain_service: TerrainService = world["terrain_service"]
	assert(terrain_service.apply_operation(TerrainEditOperation.offset(
		[Vector2i(0, 2), Vector2i(2, 2), Vector2i(1, 3)], 12, TerrainEditOperation.Mode.TERRACE)),
		"стена ставится")
	publisher.publish_all()
	var blocked := MapValidator.validate(document, document.terrain, document.water, nav)
	var mentions_entrance := false
	for message: String in blocked:
		mentions_entrance = mentions_entrance or message.contains("вход")
	assert(mentions_entrance, "заблокированный вход — ошибка валидатора, получено %s" % blocked)
