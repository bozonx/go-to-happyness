class_name TestDomainWater
extends RefCounted

## The water layer (design_docs/engine/grid_terrain_system.md §9).
##
## Three rules carry the whole design and every test below is a variation of one
## of them:
##
##   * the BODY owns the type, the bottom never does (§9.2) — a river over gravel
##     is still a river, and a drained channel is not water at all;
##   * depth is DERIVED from the ground (§9.3), so raising a lake bed drains it
##     without anyone rewriting the water layer;
##   * water is passability (§9.7) — a ford is crossable at triple cost, a step
##     deeper is a wall, ice is a floor over both, and lava is neither.

const BOARD_CELLS := 32
const CART := &"cart"


static func run_all() -> void:
	_test_body_defaults_and_flow()
	_test_cells_reference_registered_bodies_only()
	_test_depth_is_derived_from_the_ground()
	_test_flood_fills_the_basin_and_stops_at_the_rim()
	_test_paint_skips_ground_above_the_surface()
	_test_undo_restores_the_layer_exactly()
	_test_freezing_refuses_lava_and_fast_water()
	_test_codec_round_trip()
	_test_document_round_trip_carries_the_registry()
	_test_deep_water_blocks_and_a_ford_costs_more()
	_test_ice_carries_a_walker_before_a_cart()
	_test_lava_is_impassable_at_any_depth()
	_test_committed_water_edits_republish_themselves()
	_test_registry_removal_republishes_and_is_undoable()
	_test_flow_allows_all_water_types()
	_test_level_brush_can_lower_a_lake()
	_test_remove_body_takes_water_away_and_undo_brings_it_back()
	_test_creating_a_body_publishes_nothing()
	_test_border_ocean_floods_only_what_touches_the_rim()
	_test_border_nothing_never_floods()
	_test_border_lava_floods_edge_with_lava()
	_test_access_service_finds_banks_not_water()
	print("    [PASS] Water Layer Tests")


# --- Building blocks ---------------------------------------------------------

static func _terrain() -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	return terrain


static func _water_over(terrain: TerrainGrid) -> WaterGrid:
	var water := WaterGrid.new()
	water.configure(terrain.cell_size, terrain.board_cells)
	return water


static func _nav_over(terrain: TerrainGrid, water: WaterGrid) -> NavGrid:
	var grid := NavGrid.new()
	grid.configure(terrain.cell_size, terrain.board_cells)
	TerrainNavigationPublisher.publish(terrain, grid, water)
	return grid


## A square basin two steps deep with a one-step shelf around it: the shape that
## produces a ford at the rim and open water in the middle from a single level.
static func _dig_basin(terrain: TerrainGrid) -> void:
	for z in range(-4, 5):
		for x in range(-4, 5):
			assert(terrain.set_height(Vector2i(x, z), -1))
	for z in range(-2, 3):
		for x in range(-2, 3):
			assert(terrain.set_height(Vector2i(x, z), -2))


# --- The body owns the type --------------------------------------------------

static func _test_body_defaults_and_flow() -> void:
	var sea := WaterBody.of_type(1, WaterBody.Type.SEA)
	assert(sea.salinity == WaterBody.Salinity.SALT)
	assert(not sea.is_drinkable())
	assert(sea.wave_amplitude > WaterBody.of_type(2, WaterBody.Type.LAKE).wave_amplitude)

	var lava := WaterBody.of_type(3, WaterBody.Type.LAVA)
	assert(lava.is_lava())
	assert(not lava.freezes)

	# Flow is packed per cell and read back whole, and it is what decides freezing:
	# a reach running at strength 2 stays open all winter (§9.6).
	var river := WaterBody.of_type(4, WaterBody.Type.RIVER)
	river.set_flow(Vector2i(1, 1), SlopeCatalog.DIR_S, 2)
	assert(river.flow_direction_at(Vector2i(1, 1)) == SlopeCatalog.DIR_S)
	assert(river.flow_strength_at(Vector2i(1, 1)) == 2)
	assert(river.can_freeze_at(Vector2i(0, 0)))
	assert(not river.can_freeze_at(Vector2i(1, 1)))

	# The registry survives a trip through JSON, flow included.
	river.name = "Тихая"
	var copy := WaterBody.from_dict(river.to_dict())
	assert(copy.type == WaterBody.Type.RIVER)
	assert(copy.name == "Тихая")
	assert(copy.flow_strength_at(Vector2i(1, 1)) == 2)
	# A type earns the enum by changing a mechanic, so there are four and the ids
	# are the ones maps are written with.
	assert(WaterBody.TYPE_IDS.size() == 4)
	assert(not WaterBody.TYPE_IDS.has(&"pond"))


static func _test_cells_reference_registered_bodies_only() -> void:
	var terrain := _terrain()
	var water := _water_over(terrain)
	# A dangling reference is the one state the layer must never reach, so writing
	# one is refused rather than clamped or accepted.
	assert(not water.set_cell(Vector2i(0, 0), 7, 0))
	assert(not water.has_water(Vector2i(0, 0)))

	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	assert(lake.id == WaterBody.MIN_ID)
	assert(water.set_cell(Vector2i(0, 0), lake.id, 0))
	assert(water.body_at(Vector2i(0, 0)) == lake)

	# Dropping a body takes its cells with it, for the same reason.
	assert(water.remove_body(lake.id))
	assert(not water.has_water(Vector2i(0, 0)))


# --- Depth is derived --------------------------------------------------------

static func _test_depth_is_derived_from_the_ground() -> void:
	var terrain := _terrain()
	var water := _water_over(terrain)
	var pond := water.create_body(WaterBody.Type.LAKE, 0)
	assert(terrain.set_height(Vector2i(0, 0), -2))
	assert(water.set_cell(Vector2i(0, 0), pond.id, 0))
	assert(water.depth_steps_at(terrain, Vector2i(0, 0)) == 2)
	assert(water.is_wet(terrain, Vector2i(0, 0)))
	assert(not water.is_ford(terrain, Vector2i(0, 0)))

	# Raise the bottom and the same cell becomes a ford, then dry land — without a
	# single write to the water layer. That is the point of not storing depth.
	assert(terrain.set_height(Vector2i(0, 0), -1))
	assert(water.is_ford(terrain, Vector2i(0, 0)))
	assert(terrain.set_height(Vector2i(0, 0), 0))
	assert(not water.is_wet(terrain, Vector2i(0, 0)))


static func _test_flood_fills_the_basin_and_stops_at_the_rim() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)

	assert(service.flood(Vector2i(0, 0), lake.id, 0))
	# The basin is 9×9 of ground below zero and nothing outside it is below zero,
	# so the fill is exactly the basin — it does not spill over the plain.
	assert(service.last_delta_size() == 81)
	assert(water.is_wet(terrain, Vector2i(4, 4)))
	assert(not water.has_water(Vector2i(5, 5)))
	# Rim one step down, middle two: one level, two depths, one ford ring.
	assert(water.is_ford(terrain, Vector2i(4, 0)))
	assert(not water.is_ford(terrain, Vector2i(0, 0)))


static func _test_paint_skips_ground_above_the_surface() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)

	# A stroke across the bank and the basin wets only the basin: painting water
	# that stands zero deep on dry ground would put a lake on a hillside.
	var cells: Array[Vector2i] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]
	assert(service.paint(cells, lake.id, 0))
	assert(water.has_water(Vector2i(4, 0)))
	assert(not water.has_water(Vector2i(5, 0)))

	# ...and a stroke entirely on such ground is a refusal, not a silent no-op.
	var dry: Array[Vector2i] = [Vector2i(6, 0), Vector2i(7, 0)]
	assert(not service.paint(dry, lake.id, 0))
	assert(service.last_rejection() == WaterService.REASON_NOTHING_TO_DO)


static func _test_undo_restores_the_layer_exactly() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	var before := water.snapshot()

	assert(service.flood(Vector2i(0, 0), lake.id, 0))
	assert(service.set_frozen(service.cells_of_body(lake.id), true, 2))
	assert(service.remove_body(lake.id))
	while service.can_undo():
		assert(service.undo())
	var after := water.snapshot()
	for key: String in before:
		assert(before[key] == after[key])


static func _test_freezing_refuses_lava_and_fast_water() -> void:
	var terrain := _terrain()
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	assert(terrain.set_height(Vector2i(0, 0), -2))
	assert(terrain.set_height(Vector2i(2, 0), -2))

	var lava := service.create_body(WaterBody.Type.LAVA, 0)
	assert(water.set_cell(Vector2i(0, 0), lava.id, 0))
	assert(not service.set_frozen([Vector2i(0, 0)] as Array[Vector2i], true))
	assert(service.last_rejection() == WaterService.REASON_NOT_FREEZABLE)

	var river := service.create_body(WaterBody.Type.RIVER, 0)
	river.set_flow(Vector2i(2, 0), SlopeCatalog.DIR_S, WaterBody.FLOW_STRENGTH_NEVER_FREEZES)
	assert(water.set_cell(Vector2i(2, 0), river.id, 0))
	assert(not service.set_frozen([Vector2i(2, 0)] as Array[Vector2i], true))


# --- Format ------------------------------------------------------------------

static func _test_codec_round_trip() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	for z in range(-2, 3):
		for x in range(-2, 3):
			assert(water.set_cell(Vector2i(x, z), lake.id, 0))
	assert(water.set_frozen(Vector2i(0, 0), true, 2))

	var buffer := MapWaterCodec.encode(water)
	assert(MapWaterCodec.is_valid(buffer))

	var restored := _water_over(terrain)
	# The registry has to be there first: a cell pointing at an unregistered body
	# is refused by the layer and would decode as dry.
	restored.add_body(lake.duplicate_body())
	assert(MapWaterCodec.decode_into(buffer, restored))
	assert(restored.wet_cell_count() == water.wet_cell_count())
	assert(restored.ice_thickness_at(Vector2i(0, 0)) == 2)
	assert(MapWaterCodec.encode(restored) == buffer)

	# An untouched layer writes no file at all, exactly as an untouched ground does.
	assert(MapWaterCodec.encode(_water_over(terrain)).is_empty())
	# ...and a layer of another board is refused rather than half-loaded.
	var other := WaterGrid.new()
	other.configure(1.0, BOARD_CELLS / 2)
	other.add_body(lake.duplicate_body())
	assert(not MapWaterCodec.decode_into(buffer, other))


static func _test_document_round_trip_carries_the_registry() -> void:
	var document := MapDocument.create(&"water_map", "Карта с водой", BOARD_CELLS)
	var river := document.water.create_body(WaterBody.Type.RIVER, -1)
	river.name = "Быстрая"
	river.set_flow(Vector2i(0, 0), SlopeCatalog.DIR_E, 3)

	var restored := MapDocument.from_json(document.to_json())
	assert(restored.water.body_count() == 1)
	var copy := restored.water.body(river.id)
	assert(copy != null and copy.name == "Быстрая")
	assert(copy.type == WaterBody.Type.RIVER)
	assert(copy.flow_strength_at(Vector2i(0, 0)) == 3)
	# The whole document still round-trips byte for byte, water included.
	assert(JSON.stringify(restored.to_json()) == JSON.stringify(document.to_json()))


# --- Water is passability ----------------------------------------------------

static func _test_deep_water_blocks_and_a_ford_costs_more() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	for z in range(-4, 5):
		for x in range(-4, 5):
			assert(water.set_cell(Vector2i(x, z), lake.id, 0))
	var nav := _nav_over(terrain, water)

	var ford := Vector2i(4, 0)
	var deep := Vector2i(0, 0)
	assert(nav.is_walkable(ford))
	assert(not nav.is_walkable(deep))
	# Wading is three times the cost of the same ground dry (§9.7) — a price, not
	# a wall, which is what makes a route round a shallow bay a decision.
	var dry_weight := nav.get_cell_weight(Vector2i(8, 8))
	assert(is_equal_approx(nav.get_cell_weight(ford), dry_weight * WaterGrid.FORD_WEIGHT_MULTIPLIER))


static func _test_ice_carries_a_walker_before_a_cart() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i(0, 0), lake.id, 0))

	var deep := Vector2i(0, 0)
	assert(service.set_frozen([deep] as Array[Vector2i], true, 1))
	var nav := _nav_over(terrain, water)
	# One step of ice: a walker crosses, a cart goes through (§9.6).
	assert(nav.is_walkable(deep))
	assert(not nav.is_walkable(deep, CART))

	assert(service.set_frozen([deep] as Array[Vector2i], true, 2))
	nav = _nav_over(terrain, water)
	assert(nav.is_walkable(deep, CART))

	# A body walks ON the ice, not on the lake bed: the standing height is the
	# surface, which is also what makes the bank a step up rather than a cliff.
	var centre := Vector3(float(deep.x) + 0.5, 0.0, float(deep.y) + 0.5)
	assert(is_equal_approx(nav.height_at(centre), water.surface_metres_at(deep)))


static func _test_lava_is_impassable_at_any_depth() -> void:
	var terrain := _terrain()
	var water := _water_over(terrain)
	var lava := water.create_body(WaterBody.Type.LAVA, 0)
	assert(terrain.set_height(Vector2i(0, 0), -1))
	assert(water.set_cell(Vector2i(0, 0), lava.id, 0))
	var nav := _nav_over(terrain, water)
	# Shallow enough to be a ford if it were water; it is not water (§9.4).
	assert(water.depth_steps_at(terrain, Vector2i(0, 0)) == WaterGrid.FORD_MAX_DEPTH_STEPS)
	assert(not nav.is_walkable(Vector2i(0, 0)))
	# And it never freezes into a bridge.
	assert(not water.set_frozen(Vector2i(0, 0), true))


static func _test_committed_water_edits_republish_themselves() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	publisher.configure(terrain, nav, null, water, service)

	var deep := Vector2i(0, 0)
	assert(nav.is_walkable(deep))
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(deep, lake.id, 0))
	# Nobody republished by hand: the commit did it, which is the guarantee that
	# stops an edited map from routing citizens across a lake.
	assert(not nav.is_walkable(deep))
	assert(service.undo())
	assert(nav.is_walkable(deep))


static func _test_registry_removal_republishes_and_is_undoable() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	publisher.configure(terrain, nav, null, water, service)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i.ZERO, lake.id, 0))
	assert(not nav.is_walkable(Vector2i.ZERO))

	assert(service.remove_body(lake.id))
	assert(nav.is_walkable(Vector2i.ZERO))
	assert(not water.has_body(lake.id))
	assert(service.undo())
	assert(water.has_body(lake.id))
	assert(not nav.is_walkable(Vector2i.ZERO))


static func _test_flow_allows_all_water_types() -> void:
	var terrain := _terrain()
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	assert(terrain.set_height(Vector2i.ZERO, -1))
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i.ZERO, lake.id, 0))
	assert(service.set_flow([Vector2i.ZERO], lake.id, SlopeCatalog.DIR_E, 1))


# --- Level and erase: the two operations Flood cannot express -------------------

## Re-flooding at a lower level reaches fewer cells and leaves the rest standing at
## the old one, so without an absolute level brush a lake could be raised and never
## lowered (`map_editor.md` §5.3).
static func _test_level_brush_can_lower_a_lake() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i.ZERO, lake.id, 0))
	assert(water.height_of(Vector2i.ZERO) == 0)
	assert(water.is_wet(terrain, Vector2i(3, 0)), "the shelf is under water at level 0")

	assert(service.set_body_level(lake.id, -1))
	assert(water.height_of(Vector2i.ZERO) == -1)
	assert(water.body(lake.id).surface_height == -1)
	# The middle is still water — one step of it — and the shelf, which sat exactly at
	# -1, is dry ground again without anyone erasing it.
	assert(water.is_wet(terrain, Vector2i.ZERO))
	assert(not water.is_wet(terrain, Vector2i(3, 0)))

	assert(service.undo())
	assert(water.height_of(Vector2i.ZERO) == 0)
	assert(water.is_wet(terrain, Vector2i(3, 0)))


static func _test_remove_body_takes_water_away_and_undo_brings_it_back() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i.ZERO, lake.id, 0))
	var before := water.snapshot()

	assert(service.remove_body(lake.id))
	assert(not water.has_water(Vector2i.ZERO))
	assert(not water.has_body(lake.id))

	assert(service.undo())
	var after := water.snapshot()
	for key: String in before:
		assert(before[key] == after[key], "erase and its undo must be byte-exact in %s" % key)


# --- Registry edits publish only what they reach -------------------------------

## Creating a body touches no cell, so it must not republish the board. It used to,
## and on the standard 256×256 preset that was 2.5 s per click on the palette
## (§10.5).
static func _test_creating_a_body_publishes_nothing() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var nav := NavGrid.new()
	var publisher := TerrainNavigationPublisher.new()
	publisher.configure(terrain, nav, null, water, service)

	# Appended to, never reassigned: a GDScript lambda captures locals by value, so
	# `seen = cells` inside it would write to a copy and this test would pass blind.
	var seen: Array = []
	service.registry_changed.connect(func(cells: Array[Vector2i]) -> void: seen.append(cells))
	var topology_before := nav.topology_revision()
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(lake != null)
	assert(seen.size() == 1, "creating a body is still a registry event")
	assert((seen[0] as Array).is_empty(), "but an empty body reaches no cell")
	assert(nav.topology_revision() == topology_before, "and therefore moves no topology")

	# Removing one, on the other hand, drains its cells and must say exactly which.
	assert(service.flood(Vector2i.ZERO, lake.id, 0))
	var wet := water.wet_cell_count()
	assert(wet > 0)
	assert(service.remove_body(lake.id))
	assert(seen.size() == 2)
	assert((seen[1] as Array).size() == wet)
	assert(nav.topology_revision() != topology_before, "draining a lake IS a topology change")


# --- The border is a property of the map file ----------------------------------

static func _bordered(kind: StringName, level: int) -> Dictionary:
	var terrain := _terrain()
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var meta := MapMeta.new()
	meta.border_kind = kind
	meta.border_level = level
	var border := BorderOceanService.new()
	border.configure(service, terrain, water, meta)
	return {"terrain": terrain, "water": water, "service": service, "border": border}


## Digging a channel from the rim lets the sea in; digging a pit in the middle of
## the board does not, however deep it is. That asymmetry is the whole rule
## (`map_editor.md` §6.1).
static func _test_border_ocean_floods_only_what_touches_the_rim() -> void:
	var world := _bordered(MapMeta.BORDER_OCEAN, 0)
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var border: BorderOceanService = world["border"]

	# A flat board at zero has no lowland at all, so there is no sea and no empty
	# registry entry invented for one.
	assert(not border.apply())
	assert(border.border_body_id() == WaterBody.NO_BODY)

	# A closed pit in the middle stays dry: it is not connected to the sea.
	assert(terrain.set_height(Vector2i(0, 0), -3))
	assert(not border.apply())
	assert(not water.is_wet(terrain, Vector2i(0, 0)))

	# A trench from the rim inward floods, and only along itself.
	var rim := terrain.min_cell().x
	for x in range(rim, 1):
		assert(terrain.set_height(Vector2i(x, 0), -1))
	assert(border.apply())
	assert(border.border_body_id() != WaterBody.NO_BODY)
	assert(water.is_wet(terrain, Vector2i(rim, 0)))
	assert(water.is_wet(terrain, Vector2i(0, 0)), "the pit is connected now, so it fills")
	assert(not water.is_wet(terrain, Vector2i(0, 5)), "and untouched ground does not")


static func _test_border_nothing_never_floods() -> void:
	var world := _bordered(MapMeta.BORDER_NOTHING, 0)
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var border: BorderOceanService = world["border"]
	var rim := terrain.min_cell().x
	for x in range(rim, 1):
		assert(terrain.set_height(Vector2i(x, 0), -2))
	assert(not border.apply())
	assert(not water.has_water(Vector2i(rim, 0)), "the board simply ends; digging at it digs a pit")


## A lava border follows the same edge-fill rule as ocean, but the body it creates
## is lava, not sea. The type is what makes it impassable at any depth (§9.4).
static func _test_border_lava_floods_edge_with_lava() -> void:
	var world := _bordered(MapMeta.BORDER_LAVA, 0)
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var border: BorderOceanService = world["border"]
	var rim := terrain.min_cell().x
	for x in range(rim, 1):
		assert(terrain.set_height(Vector2i(x, 0), -1))
	assert(border.apply())
	assert(border.border_body_id() != WaterBody.NO_BODY, "a lava border creates a body")
	var body := water.body(border.border_body_id())
	assert(body != null and body.is_lava(), "the border body is lava")
	assert(water.is_wet(terrain, Vector2i(rim, 0)), "lava reached the exposed edge")
	assert(border.is_border_body(body.id), "is_border_body recognises it")
	print("  border lava fill ok")


# --- Drinking water comes from the water layer and nowhere else -----------------

static func _test_access_service_finds_banks_not_water() -> void:
	var terrain := _terrain()
	_dig_basin(terrain)
	var water := _water_over(terrain)
	var service := WaterService.new()
	service.configure(water, terrain)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	assert(service.flood(Vector2i.ZERO, lake.id, 0))

	var access := WaterAccessService.new()
	access.configure(water, terrain)
	var positions := access.source_positions()
	assert(not positions.is_empty())
	for position: Vector3 in positions:
		var cell := terrain.cell_from_position(position)
		assert(not water.is_wet(terrain, cell), "an access point is the bank, never the water")

	# Salt water is not drinkable, so a sea leaves no access points at all (§9.2).
	var sea_terrain := _terrain()
	_dig_basin(sea_terrain)
	var sea_water := _water_over(sea_terrain)
	var sea_service := WaterService.new()
	sea_service.configure(sea_water, sea_terrain)
	var sea := sea_service.create_body(WaterBody.Type.SEA, 0)
	assert(sea_service.flood(Vector2i.ZERO, sea.id, 0))
	var sea_access := WaterAccessService.new()
	sea_access.configure(sea_water, sea_terrain)
	assert(not sea_access.has_source())


## A session with no map still needs water, and it gets a dug basin in the real
## grids rather than the prop-plus-blocked-cells arrangement it used to get.
