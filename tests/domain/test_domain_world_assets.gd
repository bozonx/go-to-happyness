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
	_test_natural_assets_are_authorable()
	_test_random_appearance_stays_inside_declared_range()
	_test_random_appearance_leaves_fixed_controls_alone()
	print("    [PASS] Natural Asset Variation Tests")
	_test_generator_fill_is_covered()
	_test_water_bound_assets_require_water()
	_test_plants_declare_only_the_seasons_they_have()
	print("    [PASS] World Fill Coverage Tests")


# --- Natural assets and variation ---------------------------------------------

## The first batch of natural fill. Each one has to be findable, drawable and
## varied — an asset that exists but has nothing to vary would put a dead
## "Разброс" switch in the editor.
static func _test_natural_assets_are_authorable() -> void:
	for asset_id: StringName in [
		&"tree", &"conifer_tree", &"bush", &"grass_source",
		&"forage_source", &"boulder", &"ore_deposit", &"rabbit",
	]:
		var asset := WorldAssetCatalog.get_asset(asset_id)
		assert(asset != null, "Отсутствует природный ассет %s" % asset_id)
		assert(not asset.scene_path.is_empty(), "%s без сцены" % asset_id)
		assert(not asset.description.is_empty(), "%s без описания для автора" % asset_id)
		assert(asset.has_varying_controls(), "%s нечем варьировать" % asset_id)
		# Yaw only: a tilted tree is a bug, not a variation.
		assert(asset.rotation_axes == ["y"], "%s должен вращаться только по Y" % asset_id)

	# A bush yields branches and nothing else; wood belongs to trees.
	var bush := WorldAssetCatalog.get_asset(&"bush")
	assert(bush.supported_capabilities == [&"branch_source"])
	var tree := WorldAssetCatalog.get_asset(&"tree")
	assert(tree.supported_capabilities.has(&"wood_source"))
	assert(tree.supported_capabilities.has(&"branch_source"))

	# A spruce keeps its needles: declaring an autumn variant it cannot honour is
	# how a seasonal pass ends up painting evergreens orange.
	var conifer := WorldAssetCatalog.get_asset(&"conifer_tree")
	assert(conifer.state_variants.has("winter"))
	assert(not conifer.state_variants.has("autumn"))
	assert(tree.state_variants.has("autumn"))
	# Branch exhaustion asks the asset what "spent" looks like.
	for tree_id: StringName in [&"tree", &"conifer_tree"]:
		assert(WorldAssetCatalog.get_asset(tree_id).state_variants.has("withered"),
			"%s must declare the withered look the foraging service asks for" % tree_id)


## Everything the world generator is asked to place has to be in the library, or
## the generator's rule for it is a rule about nothing. The list is therefore the
## generation brief itself, checked as a list rather than trusted per commit.
##
## The claims are the ones a missing asset would silently break: it must be
## findable, drawable, describable to the author, and — for the scattered ones —
## it must have something to vary, or a forest becomes a row of clones.
static func _test_generator_fill_is_covered() -> void:
	var scattered: Array[StringName] = [
		# Растительность
		&"tree", &"conifer_tree", &"birch_tree", &"dead_tree", &"stump", &"bush",
		&"fern", &"grass_source", &"forage_source", &"reeds", &"cactus",
		&"palm_tree", &"acacia_tree", &"moss_patch",
		# Камни и минералы
		&"boulder", &"ore_deposit", &"rock_cluster", &"stone_outcrop",
		&"clay_pit", &"sand_patch",
		# Животные
		&"rabbit", &"deer", &"boar", &"wolf", &"bird",
		# Руины и следы людей
		&"ruin_wall", &"menhir", &"bones", &"abandoned_cart", &"crate_pile",
		&"well", &"signpost", &"sunken_boat",
	]
	for asset_id: StringName in scattered:
		var asset := WorldAssetCatalog.get_asset(asset_id)
		assert(asset != null, "Генератору нечем расставить «%s»" % asset_id)
		assert(not asset.scene_path.is_empty(), "%s без сцены" % asset_id)
		assert(not asset.description.is_empty(), "%s без описания для автора" % asset_id)
		assert(asset.has_varying_controls(), "%s нечем варьировать" % asset_id)
		assert(asset.rotation_axes == ["y"], "%s должен вращаться только по Y" % asset_id)

	# Атмосферные эффекты — исключение из правила «есть чем варьироваться»:
	# форму им задаёт погода и свойства сущности, а не контролы внешнего вида.
	for effect_id: StringName in [&"fireflies", &"smoke_vent", &"waterfall_mist", &"dust_devil"]:
		var effect := WorldAssetCatalog.get_asset(effect_id)
		assert(effect != null, "Отсутствует атмосферный эффект «%s»" % effect_id)
		assert(effect.category == &"ambient")
		assert(effect.scope == WorldAssetDef.SCOPE_MAP, "эффекту не место в чертеже здания")

	# Крупные препятствия обязаны перекрывать проход: скала, через которую житель
	# проходит насквозь, — это не «упрощение», это дыра в навигации.
	for blocking_id: StringName in [
		&"stone_outcrop", &"cactus", &"ruin_wall", &"menhir", &"well", &"abandoned_cart",
	]:
		var blocker := WorldAssetCatalog.get_asset(blocking_id)
		assert(blocker.blocking_navigation, "%s обязан быть препятствием" % blocking_id)
		assert(blocker.collision_policy == WorldAssetDef.COLLISION_SCENE)

	# А осыпь — нет: через россыпь камней и песок переступают.
	for walkable_id: StringName in [&"rock_cluster", &"sand_patch", &"moss_patch", &"bones"]:
		assert(not WorldAssetCatalog.get_asset(walkable_id).blocking_navigation,
			"%s не должен перегораживать дорогу" % walkable_id)


## Вода — единственная поверхность, которую ассет может *требовать*, и требуют её
## ровно двое. Ошибка здесь не видна на глаз: камыш с политикой `allow` молча
## расселся бы по сухому лугу, и предупредить об этом было бы некому.
static func _test_water_bound_assets_require_water() -> void:
	for wet_id: StringName in [&"reeds", &"sunken_boat"]:
		var policy := WorldAssetCatalog.get_asset(wet_id).placement_policy()
		assert(policy.submerged == AssetPlacementPolicy.SUBMERGED_REQUIRE,
			"%s обязан требовать воду" % wet_id)
		assert(not policy.allows_surface(AssetPlacementPolicy.SURFACE_GROUND))
		assert(policy.warnings_for({
			"surface": AssetPlacementPolicy.SURFACE_SHALLOW, "submerged": false,
		}).size() == 1)

	# Птица летает и над водой, но не *под* ней: разрешение стоять над поверхностью
	# и требование быть погружённым — разные вещи.
	var bird := WorldAssetCatalog.get_asset(&"bird").placement_policy()
	assert(bird.allows_surface(AssetPlacementPolicy.SURFACE_WATER))
	assert(bird.submerged != AssetPlacementPolicy.SUBMERGED_REQUIRE)
	assert(bird.vertical_offset > 0.0, "птица держится над поверхностью")


## Растение объявляет те состояния, которые у него действительно есть. Пальма,
## объявившая зиму, — это разрешение сезонному проходу присыпать её снегом.
static func _test_plants_declare_only_the_seasons_they_have() -> void:
	var palm := WorldAssetCatalog.get_asset(&"palm_tree")
	assert(not palm.state_variants.has("winter"))
	assert(not palm.state_variants.has("autumn"))
	assert(palm.state_variants.has("withered"))

	var birch := WorldAssetCatalog.get_asset(&"birch_tree")
	assert(birch.state_variants.has("autumn") and birch.state_variants.has("winter"))

	# Сухостой сезонов не знает вовсе — он уже мёртв; знает он, отчего умер.
	var dead := WorldAssetCatalog.get_asset(&"dead_tree")
	assert(not dead.state_variants.has("autumn"))
	assert(dead.state_variants.has("burnt"))

	# Куст даёт ветки, пень — древесину, и ни один из них не даёт того, чего у
	# него нет: способности объявляются, а не выводятся из категории.
	assert(WorldAssetCatalog.get_asset(&"stump").supported_capabilities == [&"wood_source"])
	assert(WorldAssetCatalog.get_asset(&"reeds").supported_capabilities == [&"grass_source"])
	assert(WorldAssetCatalog.get_asset(&"fern").supported_capabilities.is_empty())


static func _test_random_appearance_stays_inside_declared_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var boulder := WorldAssetCatalog.get_asset(&"boulder")
	var size_control := boulder.get_control("rock_size")
	var minimum := float(size_control["min"])
	var maximum := float(size_control["max"])
	var seen_distinct := false
	var previous: Variant = null
	for index in 40:
		var drawn := boulder.random_appearance(rng)
		assert(drawn.has("rock_size"))
		var value := float(drawn["rock_size"])
		assert(value >= minimum and value <= maximum,
			"Разброс вышел за объявленные границы: %f" % value)
		# Colours are stored JSON-safe, or a varied boulder could not be saved.
		assert(drawn["rock_color"] is String)
		if previous != null and not is_equal_approx(float(previous), value):
			seen_distinct = true
		previous = value
	assert(seen_distinct, "Разброс обязан давать разные значения")


static func _test_random_appearance_leaves_fixed_controls_alone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	# A campfire varies nothing: randomising it would light fires the author left
	# cold. The brush must therefore offer it nothing to randomise.
	var campfire := WorldAssetCatalog.get_asset(&"campfire")
	assert(not campfire.has_varying_controls())
	assert(campfire.random_appearance(rng).is_empty())

	# A tree's snow flag is authored, not drawn: a forest must not sprout random
	# snow caps in July.
	var tree := WorldAssetCatalog.get_asset(&"tree")
	for index in 20:
		assert(not tree.random_appearance(rng).has("has_snow"))


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
