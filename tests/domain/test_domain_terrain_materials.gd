class_name TestDomainTerrainMaterials
extends RefCounted

## The material catalog, its variants and the detail byte
## (design_docs/engine/terrain_materials.md §10).
##
## These check PROPERTIES, not contents. The catalog will grow — that is what the
## design says it is for — so a test counting thirteen entries would fail on the
## first legitimate addition and teach everyone to edit tests instead of reading
## them. What must never change is checked exactly: the index of every material
## that exists today, because an index is a byte in a save (§2.6).


static func run_all() -> void:
	_test_every_material_has_a_valid_repose_class()
	_test_indices_are_dense_unique_and_frozen()
	_test_every_material_declares_a_cliff_face()
	_test_nav_weights_never_undercut_a_road()
	_test_soil_is_declared_for_every_material()
	print("    [PASS] Terrain Material Catalog Tests")
	_test_variant_changes_only_the_texture_layer()
	_test_variant_budget_and_layer_layout()
	_test_procedural_variant_is_deterministic_and_in_range()
	print("    [PASS] Terrain Material Variant Tests")
	_test_detail_byte_round_trips_all_256_values()
	_test_detail_fields_are_independent()
	_test_wear_changes_weight_only_where_declared()
	_test_snow_multiplies_whatever_is_under_it()
	print("    [PASS] Terrain Detail Byte Tests")


# --- Catalog ------------------------------------------------------------------

static func _test_every_material_has_a_valid_repose_class() -> void:
	for index in TerrainMaterialCatalog.count():
		var repose := TerrainMaterialCatalog.repose_class_of_index(index)
		assert(SlopeCatalog.is_valid_class(repose))
		# A material has to hold *something*: repose `flat` would mean the ground
		# collapses to a plane under its own weight.
		assert(repose > SlopeCatalog.CLASS_FLAT)
		# And the cascade reads it as a number of steps per cell, never as an id.
		assert(TerrainMaterialCatalog.repose_steps_per_cell_of_index(index) > 0.0)
	# The spot checks of §4.2 of the parent document.
	assert(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.MUD) == SlopeCatalog.CLASS_MODERATE)
	assert(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.GRASS_TALL) == SlopeCatalog.CLASS_STEEP)
	assert(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.MARS_ROCK) == SlopeCatalog.CLASS_PRE_CLIFF)
	# The glacier is the only surface that stands vertically on its own.
	assert(TerrainMaterialCatalog.repose_class_of(TerrainMaterialCatalog.ICE) == SlopeCatalog.CLASS_CLIFF)


## §2.6: after the one renumbering that freed index 4 for `gravel`, an index is
## permanent. This snapshot is the contract — a failure here means old saves would
## silently load different ground.
static func _test_indices_are_dense_unique_and_frozen() -> void:
	var frozen := {
		TerrainMaterialCatalog.GRASS: 0,
		TerrainMaterialCatalog.DIRT: 1,
		TerrainMaterialCatalog.STONE: 2,
		TerrainMaterialCatalog.SAND: 3,
		TerrainMaterialCatalog.GRAVEL: 4,
		TerrainMaterialCatalog.MUD: 5,
		TerrainMaterialCatalog.GRASS_TALL: 6,
		TerrainMaterialCatalog.SCORCHED: 7,
		TerrainMaterialCatalog.ICE: 8,
		TerrainMaterialCatalog.LUNAR_REGOLITH: 9,
		TerrainMaterialCatalog.LUNAR_ROCK: 10,
		TerrainMaterialCatalog.MARS_REGOLITH: 11,
		TerrainMaterialCatalog.MARS_ROCK: 12,
	}
	for material_id: StringName in frozen:
		assert(TerrainMaterialCatalog.index_of(material_id) == int(frozen[material_id]))
		assert(TerrainMaterialCatalog.id_of_index(int(frozen[material_id])) == material_id)

	var seen: Dictionary = {}
	for index in TerrainMaterialCatalog.count():
		var entry := TerrainMaterialCatalog.entry_of_index(index)
		assert(int(entry["index"]) == index)
		assert(not seen.has(entry["id"]))
		seen[entry["id"]] = true
	assert(seen.size() == TerrainMaterialCatalog.count())

	# `snow` was retired: it is a state of the surface, not a material, and asking
	# for it must fail rather than resolve to whatever now sits at index 4.
	assert(not TerrainMaterialCatalog.has_material(&"snow"))
	assert(TerrainMaterialCatalog.index_of(&"snow") == -1)
	assert(TerrainMaterialCatalog.id_of_index(4) == TerrainMaterialCatalog.GRAVEL)
	# Rejected candidates from §2.5 stayed rejected.
	for rejected: StringName in [&"dirt_dry", &"lava_cooled", &"grass_swamp", &"seabed", &"cobblestone"]:
		assert(not TerrainMaterialCatalog.has_material(rejected))


static func _test_every_material_declares_a_cliff_face() -> void:
	for index in TerrainMaterialCatalog.count():
		var cliff := TerrainMaterialCatalog.cliff_material_of_index(index)
		assert(cliff != &"")
		assert(TerrainMaterialCatalog.CLIFF_IDS.has(cliff))
		var cliff_index := TerrainMaterialCatalog.cliff_index_of_index(index)
		assert(TerrainMaterialCatalog.CLIFF_IDS[cliff_index] == cliff)
	# §3: a face is the rock under the surface, so grass and tall grass share one,
	# and rock of any planet is layered rock — but mud and ice do not join them.
	assert(
		TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.GRASS)
		== TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.GRASS_TALL)
	)
	assert(
		TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.STONE)
		== TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.MARS_ROCK)
	)
	assert(
		TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.MUD)
		!= TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.GRASS)
	)
	assert(TerrainMaterialCatalog.cliff_material_of(TerrainMaterialCatalog.ICE) == TerrainMaterialCatalog.CLIFF_ICE_WALL)


## §6.5: no natural surface may be cheaper than the baseline, or A* prefers it to
## a built road — and ice, the tempting one, is exactly 1.0.
static func _test_nav_weights_never_undercut_a_road() -> void:
	for index in TerrainMaterialCatalog.count():
		assert(TerrainMaterialCatalog.nav_weight_of_index(index) >= 1.0)
		for wear in TerrainDetailCodec.MAX_WEAR + 1:
			assert(TerrainMaterialCatalog.nav_weight_at_wear(index, wear) >= 1.0)
	assert(is_equal_approx(TerrainMaterialCatalog.nav_weight_of(TerrainMaterialCatalog.ICE), 1.0))
	assert(TerrainMaterialCatalog.nav_weight_of(TerrainMaterialCatalog.MUD) > TerrainMaterialCatalog.nav_weight_of(TerrainMaterialCatalog.GRASS))


static func _test_soil_is_declared_for_every_material() -> void:
	for index in TerrainMaterialCatalog.count():
		assert(TerrainMaterialCatalog.soil_of_index(index) != &"")
	assert(TerrainMaterialCatalog.soil_of(TerrainMaterialCatalog.GRASS) == TerrainMaterialCatalog.SOIL)
	assert(TerrainMaterialCatalog.soil_of(TerrainMaterialCatalog.SCORCHED) == TerrainMaterialCatalog.SOIL_ASH)
	# Both regoliths dig the same, which is why they are not four materials.
	assert(
		TerrainMaterialCatalog.soil_of(TerrainMaterialCatalog.LUNAR_REGOLITH)
		== TerrainMaterialCatalog.soil_of(TerrainMaterialCatalog.MARS_REGOLITH)
	)


# --- Variants -----------------------------------------------------------------

## §4: the whole justification for variants existing. If any of these four numbers
## moved with the variant, it would be a material, and the catalog would double
## with every biome.
static func _test_variant_changes_only_the_texture_layer() -> void:
	for index in TerrainMaterialCatalog.count():
		var repose := TerrainMaterialCatalog.repose_class_of_index(index)
		var weight := TerrainMaterialCatalog.nav_weight_of_index(index)
		var soil := TerrainMaterialCatalog.soil_of_index(index)
		var cliff := TerrainMaterialCatalog.cliff_material_of_index(index)
		var layers: Dictionary = {}
		for variant in TerrainMaterialVariants.variant_count(index):
			assert(TerrainMaterialCatalog.repose_class_of_index(index) == repose)
			assert(is_equal_approx(TerrainMaterialCatalog.nav_weight_of_index(index), weight))
			assert(TerrainMaterialCatalog.soil_of_index(index) == soil)
			assert(TerrainMaterialCatalog.cliff_material_of_index(index) == cliff)
			var layer := TerrainMaterialVariants.layer_of(index, variant)
			assert(not layers.has(layer))
			layers[layer] = true


static func _test_variant_budget_and_layer_layout() -> void:
	var seen: Dictionary = {}
	for index in TerrainMaterialCatalog.count():
		var count := TerrainMaterialVariants.variant_count(index)
		assert(count >= 1 and count <= TerrainMaterialVariants.MAX_VARIANTS)
		for variant in count:
			var layer := TerrainMaterialVariants.layer_of(index, variant)
			assert(layer == index * TerrainMaterialVariants.MAX_VARIANTS + variant)
			assert(layer < TerrainMaterialVariants.CLIFF_LAYER_BASE)
			assert(not seen.has(layer))
			seen[layer] = true
		# A variant past the budget is clamped, never sampled off the end of the
		# array: a stale save must not point at an empty layer.
		assert(TerrainMaterialVariants.clamp_variant(index, 15) == count - 1)
		assert(TerrainMaterialVariants.layer_of(index, 15) == index * TerrainMaterialVariants.MAX_VARIANTS + count - 1)
	# Face kinds live in the same array, after the materials — one binding for the
	# whole world (§7.1).
	for cliff_index in TerrainMaterialCatalog.cliff_count():
		var layer := TerrainMaterialVariants.cliff_layer_of(cliff_index)
		assert(layer >= TerrainMaterialVariants.CLIFF_LAYER_BASE)
		assert(layer < TerrainMaterialVariants.total_layer_count())
		assert(not seen.has(layer))
		seen[layer] = true


static func _test_procedural_variant_is_deterministic_and_in_range() -> void:
	for index in TerrainMaterialCatalog.count():
		for x in 8:
			var cell := Vector2i(x, x * 3 - 5)
			var variant := TerrainMaterialVariants.procedural_variant(index, cell)
			assert(variant >= 0 and variant < TerrainMaterialVariants.variant_count(index))
			# Same cell, same look — that is what lets a generated map store no
			# variants at all (§4).
			assert(TerrainMaterialVariants.procedural_variant(index, cell) == variant)


# --- Detail byte ---------------------------------------------------------------

## §5, §10: reversible for ALL 256 values, not for a hand-picked few. The byte is
## what the save format writes, and an asymmetric codec loses surface state on
## every load.
static func _test_detail_byte_round_trips_all_256_values() -> void:
	for detail in 256:
		var variant := TerrainDetailCodec.variant_of(detail)
		var wear := TerrainDetailCodec.wear_of(detail)
		var snow := TerrainDetailCodec.snow_depth_of(detail)
		assert(variant >= 0 and variant <= TerrainDetailCodec.MAX_VARIANT)
		# Wear has a spare code point: the field is two bits and the design uses
		# three of the four. The codec must still round-trip it, or a byte from a
		# future build would come back as a different surface.
		assert(wear >= 0 and wear <= TerrainDetailCodec.WEAR_MASK)
		assert(snow >= 0 and snow <= TerrainDetailCodec.MAX_SNOW_DEPTH)
		assert(TerrainDetailCodec.pack(variant, wear, snow) == detail)


static func _test_detail_fields_are_independent() -> void:
	var detail := TerrainDetailCodec.pack(3, 1, 2)
	assert(TerrainDetailCodec.variant_of(TerrainDetailCodec.with_wear(detail, 2)) == 3)
	assert(TerrainDetailCodec.snow_depth_of(TerrainDetailCodec.with_wear(detail, 2)) == 2)
	assert(TerrainDetailCodec.wear_of(TerrainDetailCodec.with_variant(detail, 9)) == 1)
	assert(TerrainDetailCodec.variant_of(TerrainDetailCodec.with_variant(detail, 9)) == 9)
	assert(TerrainDetailCodec.snow_depth_of(TerrainDetailCodec.with_snow_depth(detail, 0)) == 0)
	# Out-of-range writes clamp into the field instead of bleeding into the next
	# one — a wear of 7 must not become snow.
	assert(TerrainDetailCodec.wear_of(TerrainDetailCodec.with_wear(detail, 7)) == TerrainDetailCodec.MAX_WEAR)
	assert(TerrainDetailCodec.snow_depth_of(TerrainDetailCodec.with_wear(detail, 7)) == 2)


## §6.1: wear moves the weight only for materials that declared it does. For
## everything else it is a picture, and saying so is what keeps a trodden cell
## from becoming a navigation update.
static func _test_wear_changes_weight_only_where_declared() -> void:
	var tall := TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.GRASS_TALL)
	assert(TerrainMaterialCatalog.wear_changes_weight(tall))
	assert(is_equal_approx(TerrainMaterialCatalog.nav_weight_at_wear(tall, 0), 2.0))
	assert(is_equal_approx(TerrainMaterialCatalog.nav_weight_at_wear(tall, 1), 1.5))
	assert(is_equal_approx(TerrainMaterialCatalog.nav_weight_at_wear(tall, 2), 1.0))
	for material_id: StringName in [TerrainMaterialCatalog.GRASS, TerrainMaterialCatalog.MUD, TerrainMaterialCatalog.STONE]:
		var index := TerrainMaterialCatalog.index_of(material_id)
		assert(not TerrainMaterialCatalog.wear_changes_weight(index))
		for wear in TerrainDetailCodec.MAX_WEAR + 1:
			assert(is_equal_approx(
				TerrainMaterialCatalog.nav_weight_at_wear(index, wear),
				TerrainMaterialCatalog.nav_weight_of_index(index),
			))
	# Grass grows back, rock does not — ever (§6.1).
	assert(TerrainMaterialCatalog.recovers_from_wear(TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.GRASS)))
	assert(not TerrainMaterialCatalog.recovers_from_wear(TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.STONE)))


## §6.2: snow multiplies the surface under it rather than replacing it — which is
## the arithmetic reason it can be a state and not a material.
static func _test_snow_multiplies_whatever_is_under_it() -> void:
	var mud := TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.MUD)
	var grass := TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.GRASS)
	assert(is_equal_approx(TerrainMaterialCatalog.surface_weight(grass, 0, 0), 1.0))
	assert(is_equal_approx(TerrainMaterialCatalog.surface_weight(grass, 0, 3), 2.2))
	assert(is_equal_approx(TerrainMaterialCatalog.surface_weight(mud, 0, 1), 2.0 * 1.4))
	# Deeper snow is never cheaper than shallower snow.
	for depth in TerrainDetailCodec.MAX_SNOW_DEPTH:
		assert(
			TerrainMaterialCatalog.surface_weight(grass, 0, depth + 1)
			> TerrainMaterialCatalog.surface_weight(grass, 0, depth)
		)
