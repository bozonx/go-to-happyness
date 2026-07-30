class_name TestDomainWorldAssets
extends RefCounted

## The shared asset library of both editors (design_docs/engine/map_fill_mode.md §3).
##
## Two claims are load-bearing and therefore asserted here rather than assumed.
## First, `scope` filters the palette and *only* the palette: an asset hidden from
## one editor is still resolvable by id, or a map referencing it would stop
## opening. Second, the placement policy warns and never refuses — the moment it
## starts returning a verdict instead of a list of reasons, the author loses the
## ability to place a thing the editor merely disapproves of.


static func run_all() -> void:
	_test_scope_filters_the_palette_only()
	_test_catalog_queries_respect_scope()
	print("    [PASS] World Asset Scope Tests")
	_test_policy_warns_about_surface_slope_and_water()
	_test_policy_defaults_are_permissive()
	_test_policy_round_trips_through_json()
	_test_policy_ignores_values_it_does_not_know()
	print("    [PASS] Asset Placement Policy Tests")


# --- Scope --------------------------------------------------------------------

static func _test_scope_filters_the_palette_only() -> void:
	var both := WorldAssetDef.new(&"both_asset", "Оба")
	assert(both.scope == WorldAssetDef.SCOPE_BOTH)
	assert(both.is_in_scope(WorldAssetDef.SCOPE_BUILDING))
	assert(both.is_in_scope(WorldAssetDef.SCOPE_MAP))
	assert(both.is_in_scope(&""))

	var map_only := WorldAssetDef.new(&"cliff", "Утёс")
	map_only.scope = WorldAssetDef.SCOPE_MAP
	assert(map_only.is_in_scope(WorldAssetDef.SCOPE_MAP))
	assert(not map_only.is_in_scope(WorldAssetDef.SCOPE_BUILDING))
	# An unfiltered query still sees it: hiding from a palette must never mean
	# becoming unresolvable.
	assert(map_only.is_in_scope(&""))


static func _test_catalog_queries_respect_scope() -> void:
	var all_assets := WorldAssetCatalog.get_all_assets()
	assert(not all_assets.is_empty())
	# Map-only assets exist and are legitimate: the natural and ambient fill
	# (trees, grass, forage, rabbits, fireflies) belongs on the map, never inside
	# a building blueprint. So every building-scope asset also appears in the
	# map scope, but the map scope may carry more — the building query is a
	# subset, not the whole catalogue.
	var building_assets := WorldAssetCatalog.get_all_assets(WorldAssetDef.SCOPE_BUILDING)
	var map_assets := WorldAssetCatalog.get_all_assets(WorldAssetDef.SCOPE_MAP)
	assert(map_assets.size() == all_assets.size(), "every asset is at least map-scope")
	assert(building_assets.size() <= map_assets.size(), "building scope is a subset of map scope")
	for asset: WorldAssetDef in building_assets:
		assert(asset.is_in_scope(WorldAssetDef.SCOPE_MAP), "a building asset must also be map-placeable")

	var building_counts := WorldAssetCatalog.category_counts(WorldAssetDef.SCOPE_BUILDING)
	var unfiltered_counts := WorldAssetCatalog.category_counts()
	for category_id: StringName in unfiltered_counts.keys():
		# A category may have more map-only assets than building ones (vegetation,
		# creatures, ambient), but never the other way around.
		assert(int(building_counts[category_id]) <= int(unfiltered_counts[category_id]))

	var scoped := WorldAssetCatalog.filter_assets(&"", &"", WorldAssetDef.SCOPE_MAP)
	assert(scoped.size() == all_assets.size())
	assert(WorldAssetCatalog.all_tags(WorldAssetDef.SCOPE_MAP) == WorldAssetCatalog.all_tags())

	# The new map-fill categories exist and belong to the world group.
	for category_id: StringName in [&"vegetation", &"rocks_minerals", &"creatures", &"world_props"]:
		assert(WorldAssetCatalog.CATEGORIES.has(category_id))
		assert(WorldAssetCatalog.group_of_category(category_id) == &"world")


# --- Placement policy ---------------------------------------------------------

static func _test_policy_warns_about_surface_slope_and_water() -> void:
	var policy := AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_GENTLE
	)
	assert(policy.warnings_for({
		"surface": AssetPlacementPolicy.SURFACE_GROUND,
		"slope_class": SlopeCatalog.CLASS_SHALLOW,
		"submerged": false,
	}).is_empty())
	# Water, a cliff and a flooded cell each earn one complaint, and all three at
	# once earn three: the policy reports every broken invariant, not the first.
	assert(policy.warnings_for({
		"surface": AssetPlacementPolicy.SURFACE_WATER,
		"slope_class": SlopeCatalog.CLASS_CLIFF,
		"submerged": true,
	}).size() == 3)

	var reeds := AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_SHALLOW],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_REQUIRE
	)
	assert(reeds.warnings_for({
		"surface": AssetPlacementPolicy.SURFACE_SHALLOW, "submerged": true,
	}).is_empty())
	assert(reeds.warnings_for({
		"surface": AssetPlacementPolicy.SURFACE_SHALLOW, "submerged": false,
	}).size() == 1)


static func _test_policy_defaults_are_permissive() -> void:
	# An asset that declares nothing must still be placeable anywhere sane, and it
	# must not need a null check at every call site.
	var asset := WorldAssetDef.new(&"bare", "Без политики")
	assert(asset.placement == null)
	var policy := asset.placement_policy()
	assert(policy != null)
	assert(asset.placement == policy)
	assert(policy.allows_surface(AssetPlacementPolicy.SURFACE_GROUND))
	assert(policy.allows_slope_class(SlopeCatalog.CLASS_CLIFF))
	assert(policy.warnings_for({"surface": AssetPlacementPolicy.SURFACE_GROUND}).is_empty())

	# Built-ins carry real policies, so the fill mode has something to check.
	var campfire := WorldAssetCatalog.get_asset(&"campfire")
	assert(campfire.placement != null)
	assert(not campfire.placement.allows_slope_class(SlopeCatalog.CLASS_STEEP))
	assert(not campfire.placement.allows_surface(AssetPlacementPolicy.SURFACE_WATER))


static func _test_policy_round_trips_through_json() -> void:
	var policy := AssetPlacementPolicy.new()
	policy.surfaces = [AssetPlacementPolicy.SURFACE_SHALLOW, AssetPlacementPolicy.SURFACE_ICE]
	policy.max_slope_class = SlopeCatalog.CLASS_MODERATE
	policy.align_to_normal = AssetPlacementPolicy.ALIGN_FULL
	policy.submerged = AssetPlacementPolicy.SUBMERGED_ALLOW
	policy.vertical_offset = 0.25
	policy.footprint_cells = Vector2i(2, 3)
	policy.scatter_allowed = true
	policy.scatter_default_density = 0.4
	policy.scatter_min_spacing_m = 1.2

	var restored := AssetPlacementPolicy.from_dict(policy.to_dict())
	assert(restored.surfaces == policy.surfaces)
	assert(restored.max_slope_class == policy.max_slope_class)
	assert(restored.align_to_normal == policy.align_to_normal)
	assert(restored.submerged == policy.submerged)
	assert(is_equal_approx(restored.vertical_offset, policy.vertical_offset))
	assert(restored.footprint_cells == policy.footprint_cells)
	assert(restored.scatter_allowed)
	assert(is_equal_approx(restored.scatter_default_density, 0.4))
	assert(is_equal_approx(restored.scatter_min_spacing_m, 1.2))
	assert(restored.to_dict() == policy.to_dict())


static func _test_policy_ignores_values_it_does_not_know() -> void:
	# A pack authored by a later build has to open here (§11): unknown enum values
	# fall back to the default instead of failing the load.
	var restored := AssetPlacementPolicy.from_dict({
		"surface": ["ground", "quicksand"],
		"max_slope_class": 99,
		"align_to_normal": "sideways",
		"submerged": "maybe",
		"footprint_cells": [0, -4],
	})
	assert(restored.surfaces == [AssetPlacementPolicy.SURFACE_GROUND])
	assert(restored.max_slope_class == SlopeCatalog.CLASS_CLIFF)
	assert(restored.align_to_normal == AssetPlacementPolicy.ALIGN_PARTIAL)
	assert(restored.submerged == AssetPlacementPolicy.SUBMERGED_FORBID)
	# A footprint always covers at least one cell; zero cells is not a placement.
	assert(restored.footprint_cells == Vector2i.ONE)

	# A surface list that survives nothing keeps the default rather than becoming
	# "allowed nowhere", which would make the asset unplaceable instead of odd.
	var only_unknown := AssetPlacementPolicy.from_dict({"surface": ["quicksand"]})
	assert(only_unknown.surfaces == [AssetPlacementPolicy.SURFACE_GROUND])
