extends SceneTree

const VillageTerritoryScript = preload("res://game/features/buildings/domain/village_territory.gd")
const VillageTerritoryServiceScript = preload("res://game/features/buildings/application/village_territory_service.gd")


func _init() -> void:
	_test_territory_basic()
	_test_territory_campfire_radius()
	_test_territory_house_expansion()
	_test_territory_post_expansion()
	_test_territory_removal()
	_test_territory_perimeter()
	_test_campfire_limits()
	_test_catalog_flags()
	_test_service_no_campfire()
	_test_service_campfire_placement()
	_test_service_outside_territory()
	_test_service_campfire_limit()
	_test_service_warehouse_anywhere()
	_test_service_foreign_territory()
	print("All village territory tests passed.")
	quit(0)


func _test_territory_basic() -> void:
	var t := VillageTerritoryScript.new()
	assert(t.is_empty(), "New territory should be empty")
	assert(not t.is_inside(Vector2i(0, 0)), "Empty territory should not contain any cell")
	assert(not t.has_campfire(), "Empty territory should have no campfire")
	assert(t.campfire_count() == 0, "Empty territory should have 0 campfires")


func _test_territory_campfire_radius() -> void:
	var t := VillageTerritoryScript.new()
	t.add_anchor(Vector2i(0, 0), "campfire")
	assert(t.has_campfire(), "Territory with campfire anchor should have_campfire")
	assert(t.campfire_count() == 1, "Should have 1 campfire")
	assert(t.is_inside(Vector2i(0, 0)), "Center cell should be inside")
	assert(t.is_inside(Vector2i(11, 0)), "Cell at radius 11 should be inside campfire r=12")
	assert(not t.is_inside(Vector2i(13, 0)), "Cell at radius 13 should be outside campfire r=12")


func _test_territory_house_expansion() -> void:
	var t := VillageTerritoryScript.new()
	t.add_anchor(Vector2i(0, 0), "campfire")
	t.add_anchor(Vector2i(15, 0), "house")
	assert(t.is_inside(Vector2i(15, 0)), "House center should be inside")
	assert(t.is_inside(Vector2i(22, 0)), "Cell at house radius edge should be inside")
	# Gap between campfire r=12 and house r=8 at distance 15: 12+8=20 > 15, so no gap
	assert(t.is_inside(Vector2i(7, 0)), "Midpoint between campfire and house should be inside")


func _test_territory_post_expansion() -> void:
	var t := VillageTerritoryScript.new()
	t.add_anchor(Vector2i(0, 0), "campfire")
	t.add_anchor(Vector2i(9, 0), "boundary_post")
	assert(t.is_inside(Vector2i(9, 0)), "Post center should be inside")
	assert(t.is_inside(Vector2i(13, 0)), "Cell at post radius edge should be inside")


func _test_territory_removal() -> void:
	var t := VillageTerritoryScript.new()
	t.add_anchor(Vector2i(0, 0), "campfire")
	t.add_anchor(Vector2i(15, 0), "house")
	assert(t.is_inside(Vector2i(15, 0)))
	t.remove_anchor(Vector2i(15, 0))
	assert(not t.is_inside(Vector2i(22, 0)), "House area should be gone after removal")
	assert(t.is_inside(Vector2i(0, 0)), "Campfire area should remain")


func _test_territory_perimeter() -> void:
	var t := VillageTerritoryScript.new()
	t.add_anchor(Vector2i(0, 0), "campfire")
	var perimeter := t.perimeter_cells()
	assert(perimeter.size() > 0, "Perimeter should not be empty for non-empty territory")
	# All perimeter cells should be inside the territory
	for cell in perimeter:
		assert(t.is_inside(cell), "Perimeter cell should be inside territory")


func _test_campfire_limits() -> void:
	assert(VillageTerritoryScript.campfire_limit_for_era(0) == 1, "Tent era should allow 1 campfire")
	assert(VillageTerritoryScript.campfire_limit_for_era(1) == 2, "Earth era should allow 2 campfires")
	assert(VillageTerritoryScript.campfire_limit_for_era(5) == 6, "Brick era should allow 6 campfires")
	assert(VillageTerritoryScript.campfire_limit_for_era(-1) == 1, "Invalid era should default to 1")


func _test_catalog_flags() -> void:
	assert(BuildingCatalog.is_campfire("campfire"), "campfire should be is_campfire")
	assert(BuildingCatalog.is_campfire("brick_city_hall"), "brick_city_hall should be is_campfire")
	assert(not BuildingCatalog.is_campfire("house"), "house should not be is_campfire")
	assert(BuildingCatalog.expands_village_area("campfire"), "campfire expands village area")
	assert(BuildingCatalog.expands_village_area("boundary_post"), "boundary_post expands village area")
	assert(not BuildingCatalog.expands_village_area("warehouse"), "warehouse does not expand village area")
	assert(not BuildingCatalog.requires_village_area("campfire"), "campfire does not require village area")
	assert(not BuildingCatalog.requires_village_area("warehouse"), "warehouse does not require village area")
	assert(BuildingCatalog.requires_village_area("house"), "house requires village area")
	assert(BuildingCatalog.requires_village_area("boundary_post"), "boundary_post requires village area")


func _make_service(era: int) -> RefCounted:
	var registry := BuildingRegistry.new()
	var service := VillageTerritoryServiceScript.new()
	service.configure(registry, era)
	return service


func _test_service_no_campfire() -> void:
	var service := _make_service(0)
	assert(service.placement_reason("house", Vector2i(0, 0)) == service.REASON_NO_CAMPFIRE, \
		"House without campfire should be REASON_NO_CAMPFIRE")
	assert(service.placement_reason("campfire", Vector2i(50, 50)) == service.REASON_OK, \
		"First campfire should be placeable anywhere")
	assert(service.placement_reason("warehouse", Vector2i(50, 50)) == service.REASON_OK, \
		"Warehouse should be placeable without campfire")


func _test_service_campfire_placement() -> void:
	var service := _make_service(0)
	# Simulate campfire at origin
	service.on_building_added(Vector2i(0, 0), "campfire")
	assert(service.has_campfire(), "Service should have campfire after adding")
	# House inside territory should be OK
	assert(service.placement_reason("house", Vector2i(5, 0)) == service.REASON_OK, \
		"House inside territory should be OK")
	# Second campfire in tent era should be rejected (limit=1)
	assert(service.placement_reason("campfire", Vector2i(50, 50)) == service.REASON_CAMPFIRE_LIMIT, \
		"Second campfire in tent era should hit limit")


func _test_service_outside_territory() -> void:
	var service := _make_service(0)
	service.on_building_added(Vector2i(0, 0), "campfire")
	assert(service.placement_reason("house", Vector2i(30, 30)) == service.REASON_OUTSIDE_TERRITORY, \
		"House far from territory should be REASON_OUTSIDE_TERRITORY")


func _test_service_campfire_limit() -> void:
	var service := _make_service(1)  # Earth era: limit=2
	service.on_building_added(Vector2i(0, 0), "campfire")
	assert(service.placement_reason("campfire", Vector2i(50, 50)) == service.REASON_OK, \
		"Second campfire in earth era should be OK (limit=2)")
	service.on_building_added(Vector2i(50, 50), "campfire")
	assert(service.placement_reason("campfire", Vector2i(100, 100)) == service.REASON_CAMPFIRE_LIMIT, \
		"Third campfire in earth era should hit limit")


func _test_service_warehouse_anywhere() -> void:
	var service := _make_service(0)
	service.on_building_added(Vector2i(0, 0), "campfire")
	assert(service.placement_reason("warehouse", Vector2i(100, 100)) == service.REASON_OK, \
		"Warehouse should be placeable outside territory")


func _test_service_foreign_territory() -> void:
	var service := _make_service(0)
	service.on_building_added(Vector2i(0, 0), "campfire")
	# Add foreign territory overlapping the edge of own territory
	var foreign := VillageTerritoryScript.new()
	foreign.add_anchor(Vector2i(11, 0), "campfire")
	service.add_foreign_territory(foreign)
	# Cell (11,0) is inside own territory (r=12 from origin) and inside foreign territory
	assert(service.placement_reason("house", Vector2i(11, 0)) == service.REASON_FOREIGN_TERRITORY, \
		"House in foreign territory should be REASON_FOREIGN_TERRITORY")
	# Warehouse at foreign-only cell should also be blocked
	assert(service.placement_reason("warehouse", Vector2i(14, 0)) == service.REASON_FOREIGN_TERRITORY, \
		"Warehouse in foreign territory should be REASON_FOREIGN_TERRITORY")
