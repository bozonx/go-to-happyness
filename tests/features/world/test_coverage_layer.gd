class_name TestCoverageLayer
extends RefCounted

## Built coverage, end to end (design_docs/engine/map_editor.md §5.2, §15 "Тесты").
##
## The claims asserted here are the ones the design makes and the ones that would
## silently rot otherwise: that a stroke crossing its own path is the same as a
## single stamp, that erasing coverage reveals the ground rather than repainting
## it, that a trail under a road survives the road, that the layer survives a save,
## and that the map — not a second owner — seeds routing with what was paved.

const TEST_ROOT := "user://test_coverage_maps"
const BOARD_CELLS := 16


static func run_all() -> void:
	_test_catalog_is_data_not_branches()
	_test_legacy_ids_resolve_to_the_same_surface()
	print("    [PASS] Coverage Catalog Tests")
	_test_stamp_is_idempotent_over_its_own_path()
	_test_stroke_is_continuous_between_samples()
	print("    [PASS] Coverage Rasterizer Tests")
	_test_erase_reveals_the_ground()
	_test_service_undo_restores_index_and_detail()
	_test_unknown_coverage_is_refused()
	print("    [PASS] Coverage Service Tests")
	_test_layer_round_trips_through_the_package()
	_test_map_without_coverage_writes_no_layer()
	print("    [PASS] Coverage Codec Tests")
	_test_map_seeds_the_road_network()
	_test_road_over_trail_leaves_the_trail_underneath()
	print("    [PASS] Coverage Navigation Tests")
	_cleanup()


# --- Catalog ------------------------------------------------------------------

## A surface is a record, so a pack can add one without a line of GDScript. The
## registered entry has to behave exactly like a shipped one — including keeping
## its index, which is the saved form.
static func _test_catalog_is_data_not_branches() -> void:
	CoverageCatalog.clear_registered()
	var before := CoverageCatalog.count()
	var index := CoverageCatalog.register({
		CoverageCatalog.FIELD_ID: &"pack:test.deck/alien",
		CoverageCatalog.FIELD_TITLE: "инопланетный настил",
		CoverageCatalog.FIELD_WEIGHT: 0.5,
		CoverageCatalog.FIELD_PROFILES: [TravelerProfile.PEDESTRIAN],
		CoverageCatalog.FIELD_MIN_ERA: CoverageCatalog.ERA_TENT,
		CoverageCatalog.FIELD_FLAGS: CoverageCatalog.FLAG_NO_WEAR,
	})
	assert(index == before, "a registered surface appends after the shipped ones")
	assert(CoverageCatalog.count() == before + 1)
	assert(is_equal_approx(CoverageCatalog.weight_of_index(index), 0.5))
	assert(CoverageCatalog.supports_profile_index(index, TravelerProfile.PEDESTRIAN))
	assert(not CoverageCatalog.supports_profile_index(index, TravelerProfile.HEAVY_VEHICLE))
	assert(not CoverageCatalog.supports_wear_index(index), "NO_WEAR keeps the wear brush away")
	# Registering the same id twice must not mint a second index for one surface.
	assert(CoverageCatalog.register({CoverageCatalog.FIELD_ID: &"pack:test.deck/alien"}) == CoverageCatalog.NONE_INDEX)
	CoverageCatalog.clear_registered()
	assert(CoverageCatalog.count() == before)


static func _test_legacy_ids_resolve_to_the_same_surface() -> void:
	assert(CoverageCatalog.index_of_id(&"stone") == CoverageCatalog.index_of_id(CoverageCatalog.STONE))
	assert(CoverageCatalog.index_of_id(&"nonsense") == CoverageCatalog.NONE_INDEX)
	assert(RoadType.STONE == CoverageCatalog.STONE, "RoadType names the canonical id")
	assert(is_equal_approx(RoadType.traversal_weight(&"dirt"), CoverageCatalog.weight_of_id(CoverageCatalog.DIRT)))


# --- Rasterizer ---------------------------------------------------------------

## The brush stamps an absolute value. A drag overlaps its own path, so a brush
## defined as "one step better than what is here" would lay a staircase from dirt
## to asphalt along a single stroke.
static func _test_stamp_is_idempotent_over_its_own_path() -> void:
	var layer := _layer()
	var service := _service(layer)
	var stone := CoverageCatalog.index_of_id(CoverageCatalog.STONE)
	var cells := CoverageRasterizer.stamp(Vector2i.ZERO, 1, layer)
	assert(service.paint(cells, stone))
	var after_first := layer.index_at(Vector2i.ZERO)
	# Three more passes over the same ground, as a slow drag would produce.
	service.paint(cells, stone)
	service.paint(CoverageRasterizer.stamp(Vector2i(1, 0), 1, layer), stone)
	service.paint(cells, stone)
	assert(layer.index_at(Vector2i.ZERO) == after_first, "repainting the same surface changes nothing")
	assert(layer.index_at(Vector2i.ZERO) == stone)


static func _test_stroke_is_continuous_between_samples() -> void:
	var layer := _layer()
	# Two cursor samples six cells apart: what a fast drag actually delivers.
	var cells := CoverageRasterizer.stroke([Vector2i(-3, 0), Vector2i(3, 0)] as Array[Vector2i], 1, layer)
	for x in range(-3, 4):
		assert(cells.has(Vector2i(x, 0)), "a fast drag must not lay a dotted road")
	# Width 3 is a centre line plus one cell either side.
	var wide := CoverageRasterizer.stroke([Vector2i.ZERO, Vector2i.ZERO] as Array[Vector2i], 3, layer)
	assert(wide.has(Vector2i(1, 1)) and wide.has(Vector2i(-1, -1)))
	assert(not wide.has(Vector2i(2, 0)))


# --- Service ------------------------------------------------------------------

## Erasing coverage reveals the ground that was under it. It must not touch the
## terrain material: coverage is a layer, which is the whole reason it is not a
## material index.
static func _test_erase_reveals_the_ground() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	var layer := _layer()
	var service := CoverageService.new()
	service.configure(layer, terrain)
	var material_before := terrain.material_index_at(Vector2i.ZERO)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	assert(service.paint(cells, CoverageCatalog.index_of_id(CoverageCatalog.ASPHALT)))
	assert(service.erase(cells))
	assert(not layer.has_coverage(Vector2i.ZERO))
	assert(terrain.material_index_at(Vector2i.ZERO) == material_before, "erasing coverage repaints no ground")
	assert(not service.erase(cells), "erasing bare ground is nothing to do")


static func _test_service_undo_restores_index_and_detail() -> void:
	var layer := _layer()
	var service := _service(layer)
	var dirt := CoverageCatalog.index_of_id(CoverageCatalog.DIRT)
	var stone := CoverageCatalog.index_of_id(CoverageCatalog.STONE)
	var cells: Array[Vector2i] = [Vector2i(2, 2)]
	assert(service.paint(cells, dirt, TerrainDetailCodec.pack(0, TerrainDetailCodec.MAX_WEAR, 0)))
	assert(layer.wear_at(Vector2i(2, 2)) == TerrainDetailCodec.MAX_WEAR)
	assert(service.paint(cells, stone))
	assert(service.undo())
	# The worn dirt comes back, wear included: index and detail are one state.
	assert(layer.index_at(Vector2i(2, 2)) == dirt)
	assert(layer.wear_at(Vector2i(2, 2)) == TerrainDetailCodec.MAX_WEAR)
	assert(service.redo() and layer.index_at(Vector2i(2, 2)) == stone)


static func _test_unknown_coverage_is_refused() -> void:
	var layer := _layer()
	var service := _service(layer)
	assert(not service.paint([Vector2i.ZERO] as Array[Vector2i], 250))
	assert(service.last_rejection() == CoverageService.REASON_UNKNOWN_COVERAGE)
	# The era gate applies to a settlement, never to an author: the editor passes
	# no era and may pave a stone square in the tent age.
	assert(not service.paint([Vector2i.ZERO] as Array[Vector2i], CoverageCatalog.index_of_id(CoverageCatalog.STONE), 0, CoverageCatalog.ERA_TENT))
	assert(service.last_rejection() == CoverageService.REASON_ERA_LOCKED)
	assert(service.paint([Vector2i.ZERO] as Array[Vector2i], CoverageCatalog.index_of_id(CoverageCatalog.STONE)))


# --- Package ------------------------------------------------------------------

static func _test_layer_round_trips_through_the_package() -> void:
	var document := MapDocument.create(&"paved", "Мощёная", BOARD_CELLS)
	var service := CoverageService.new()
	service.configure(document.coverage, document.terrain)
	service.paint(
		CoverageRasterizer.stroke([Vector2i(-4, 0), Vector2i(4, 0)] as Array[Vector2i], 3, document.coverage),
		CoverageCatalog.index_of_id(CoverageCatalog.STONE),
		TerrainDetailCodec.pack(1, 1, 0),
	)
	var encoded := MapCoverageCodec.encode(document.coverage)
	assert(not encoded.is_empty())
	assert(MapCoverageCodec.is_valid(encoded))

	var reopened := MapDocument.create(&"paved", "Мощёная", BOARD_CELLS)
	assert(MapCoverageCodec.decode_into(encoded, reopened.coverage))
	assert(reopened.coverage.covered_cells().size() == document.coverage.covered_cells().size())
	assert(reopened.coverage.index_at(Vector2i.ZERO) == document.coverage.index_at(Vector2i.ZERO))
	assert(reopened.coverage.variant_at(Vector2i.ZERO) == 1)
	assert(reopened.coverage.wear_at(Vector2i.ZERO) == 1)
	assert(MapCoverageCodec.encode(reopened.coverage) == encoded, "byte-for-byte on the second trip")

	# A layer of a different board is refused rather than half-decoded.
	var other := CoverageLayer.new()
	other.configure(1.0, BOARD_CELLS * 2)
	assert(not MapCoverageCodec.decode_into(encoded, other))

	# ...and through the real package on disk, so `surface.bin` is actually written.
	var package_service := MapDocumentService.new()
	package_service.dev_mode = false
	package_service.project_root = TEST_ROOT
	package_service.project_source = &"pack:test_author.coverage"
	var path := package_service.save_map_to(document, TEST_ROOT.path_join("paved.gdmap"))
	assert(not path.is_empty(), package_service.last_error)
	assert(FileAccess.file_exists(path.path_join(MapDocumentService.SURFACE_BIN)))
	var loaded := package_service.load_package(path)
	assert(loaded != null)
	assert(loaded.coverage.index_at(Vector2i.ZERO) == document.coverage.index_at(Vector2i.ZERO))
	# What the map uses, it declares.
	var declares_coverage := false
	for reference: Dictionary in loaded.meta.required_content:
		if String(reference.get("kind", "")) == "coverage":
			declares_coverage = true
	assert(declares_coverage, "a paved map lists the surfaces it uses")


static func _test_map_without_coverage_writes_no_layer() -> void:
	var document := MapDocument.create(&"bare", "Голая", BOARD_CELLS)
	assert(MapCoverageCodec.encode(document.coverage).is_empty())
	var package_service := MapDocumentService.new()
	package_service.project_root = TEST_ROOT
	package_service.project_source = &"pack:test_author.coverage"
	var path := package_service.save_map_to(document, TEST_ROOT.path_join("bare.gdmap"))
	assert(not path.is_empty(), package_service.last_error)
	assert(not FileAccess.file_exists(path.path_join(MapDocumentService.SURFACE_BIN)))


# --- Navigation ---------------------------------------------------------------

## The seeding rule of §5.2.3: the map publishes what the author paved, and the
## road service is the one write-owner of road weights from then on.
static func _test_map_seeds_the_road_network() -> void:
	var document := MapDocument.create(&"paved", "Мощёная", BOARD_CELLS)
	var service := CoverageService.new()
	service.configure(document.coverage, document.terrain)
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	assert(service.paint(cells, CoverageCatalog.index_of_id(CoverageCatalog.STONE)))

	var grid := NavGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	var roads := RoadNetworkService.new()
	roads.configure(grid)
	var publisher := CoverageNavigationPublisher.new()
	publisher.configure(document.coverage, roads, service)

	assert(roads.road_type_at(Vector2i.ZERO) == CoverageCatalog.STONE)
	var paved := grid.get_cell_weight(Vector2i.ZERO)
	assert(paved < grid.get_cell_weight(Vector2i(5, 5)), "a road is cheaper than grass")
	assert(is_equal_approx(paved, CoverageCatalog.weight_of_id(CoverageCatalog.STONE)))
	# A vehicle may not use pedestrian-only coverage as a corridor.
	assert(is_finite(roads.road_weight_for_profile(Vector2i.ZERO, CoverageCatalog.CART)))
	var trail_index := CoverageCatalog.index_of_id(CoverageCatalog.TRAIL)
	assert(not CoverageCatalog.supports_profile_index(trail_index, CoverageCatalog.CART))

	# An edit after seeding reaches the grid without a reload: the publisher
	# follows the service it was configured with.
	assert(service.erase(cells))
	assert(roads.road_type_at(Vector2i.ZERO).is_empty())
	assert(grid.get_cell_weight(Vector2i.ZERO) > paved)


## Coverage and the desire-line layer are independent: a road laid over an unfaded
## trail hides it, and removing the road brings the trail back rather than the raw
## grass. That priority is the reason coverage is a layer at all.
static func _test_road_over_trail_leaves_the_trail_underneath() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	var cell := Vector2i(3, 3)
	grid.set_profile_cell_weight(NavGrid.PEDESTRIAN_PROFILE, cell, 1.4)
	var trail_weight := grid.get_cell_weight(cell)

	var roads := RoadNetworkService.new()
	roads.configure(grid)
	assert(roads.complete_cells([cell] as Array[Vector2i], CoverageCatalog.STONE))
	assert(grid.get_cell_weight(cell) < trail_weight, "the road wins while it is there")
	assert(roads.remove_cells([cell] as Array[Vector2i]))
	assert(is_equal_approx(grid.get_cell_weight(cell), trail_weight), "the trail was never destroyed")


# --- Helpers ------------------------------------------------------------------

static func _layer() -> CoverageLayer:
	var layer := CoverageLayer.new()
	layer.configure(1.0, BOARD_CELLS)
	return layer


static func _service(layer: CoverageLayer) -> CoverageService:
	var service := CoverageService.new()
	service.configure(layer, null)
	return service


static func _cleanup() -> void:
	var directory := DirAccess.open(TEST_ROOT)
	if directory == null:
		return
	for entry: String in directory.get_directories():
		var package := TEST_ROOT.path_join(entry)
		var inner := DirAccess.open(package)
		if inner != null:
			for file: String in inner.get_files():
				DirAccess.remove_absolute(package.path_join(file))
		DirAccess.remove_absolute(package)
	DirAccess.remove_absolute(TEST_ROOT)
