class_name TestDomainTerrainTextures
extends RefCounted

## Authored texture registry
## (design_docs/engine/terrain_materials.md §7.1, stage 1 of the texture rollout).
##
## `TerrainMaterialLibrary` reads authored 512² surface underlays and cliff faces
## from a fixed table of file names (`AUTHORED_SURFACE_PATHS` /
## `AUTHORED_CLIFF_PATHS`). Stage 1 froze those names; stage 2 drops the PNGs in.
## These tests are the contract between the two stages and between an author and
## the array builder: a wrong count, a renamed style or a path outside the asset
## directory must fail here, not in a shader at runtime.
##
## Properties only — never the pixel contents. The library falling back to a
## procedural placeholder for a not-yet-drawn style is correct on purpose, so no
## test asserts that every authored file exists on disk.


static func run_all() -> void:
	_test_surface_table_covers_every_style()
	_test_surface_base_names_match_catalog()
	_test_cliff_table_matches_catalog()
	_test_all_paths_live_in_one_asset_directory()
	_test_every_authored_base_name_is_unique()
	_test_presentation_tables_are_catalog_sized()
	_test_built_arrays_match_the_domain_layout()
	print("    [PASS] Terrain Texture Registry Tests")


## The list under a material id must hold exactly `surface_style_count` entries:
## one slot per packed layer. Too few would index a placeholder as a real style;
## too many would be dead rows that no variant ever reaches.
static func _test_surface_table_covers_every_style() -> void:
	assert(TerrainMaterialLibrary.AUTHORED_SURFACE_PATHS.size() == TerrainMaterialCatalog.MATERIAL_COUNT)
	for index in TerrainMaterialCatalog.count():
		var id: StringName = TerrainMaterialCatalog.id_of_index(index)
		assert(TerrainMaterialLibrary.AUTHORED_SURFACE_PATHS.has(id))
		var base_names: Array = TerrainMaterialLibrary.AUTHORED_SURFACE_PATHS[id]
		var expected := TerrainMaterialVariants.surface_style_count(index)
		assert(base_names.size() == expected)
		# Grass and grass_tall already carry authored PNGs (stage 0); every later
		# material is allowed a not-yet-drawn style, encoded as an empty string.
		for entry in base_names:
			assert(typeof(entry) == TYPE_STRING)


## Each non-empty base name follows `<material_id>_<suffix>`. The suffix is the
## author's label for that surface underlay; it is NOT the variant name, because
## several variants can share one underlay — the five flower colours all sit on
## the single `grass_ground_flowering` floor (design §4). What the contract
## requires is the material prefix (so a stone texture never lands under sand)
## and a non-empty style suffix, not a duplicate of the variant spelling.
static func _test_surface_base_names_match_catalog() -> void:
	for index in TerrainMaterialCatalog.count():
		var id: StringName = TerrainMaterialCatalog.id_of_index(index)
		var prefix := String(id) + "_"
		var base_names: Array = TerrainMaterialLibrary.AUTHORED_SURFACE_PATHS[id]
		for style_index in base_names.size():
			var base_name: String = base_names[style_index]
			if base_name == "":
				continue
			assert(base_name.begins_with(prefix))
			# There must be a style suffix after the material id; `grass_` alone
			# would collide across every style of grass.
			assert(base_name.length() > prefix.length())


## Cliff paths align with `CLIFF_IDS`: one row per face kind, in order.
static func _test_cliff_table_matches_catalog() -> void:
	assert(TerrainMaterialLibrary.AUTHORED_CLIFF_PATHS.size() == TerrainMaterialCatalog.cliff_count())
	for index in TerrainMaterialCatalog.cliff_count():
		var id: StringName = TerrainMaterialCatalog.CLIFF_IDS[index]
		var base_name: String = TerrainMaterialLibrary.AUTHORED_CLIFF_PATHS[index]
		assert(base_name == String(id))


## Every resolved path must share the single asset directory: scattered texture
## trees are how a material ends up sampling the wrong layer after a move. A base
## name with a slash or a `..` would escape it, so each one is a bare file name.
static func _test_all_paths_live_in_one_asset_directory() -> void:
	assert(TerrainMaterialLibrary.ASSET_DIR.begins_with("res://"))
	assert(TerrainMaterialLibrary.ASSET_DIR.ends_with("/assets/"))
	for index in TerrainMaterialCatalog.count():
		var id: StringName = TerrainMaterialCatalog.id_of_index(index)
		for base_name in TerrainMaterialLibrary.AUTHORED_SURFACE_PATHS[id]:
			if base_name == "":
				continue
			assert(_is_bare_file_name(base_name))
	for base_name in TerrainMaterialLibrary.AUTHORED_CLIFF_PATHS:
		assert(_is_bare_file_name(base_name))


static func _is_bare_file_name(base_name: String) -> bool:
	if base_name.is_empty():
		return false
	if base_name.contains("/") or base_name.contains("\\"):
		return false
	if base_name.contains(".."):
		return false
	return true


## No two authored base names may collide across the whole array: a duplicate
## would mean two layers sharing one texture, and a packed layer index points at
## exactly one. Grass and grass_tall already share the "ground" word, so the
## material prefix is what keeps them apart — this asserts it does.
static func _test_every_authored_base_name_is_unique() -> void:
	var seen: Dictionary = {}
	for index in TerrainMaterialCatalog.count():
		var id: StringName = TerrainMaterialCatalog.id_of_index(index)
		for base_name in TerrainMaterialLibrary.AUTHORED_SURFACE_PATHS[id]:
			if base_name == "":
				continue
			assert(not seen.has(base_name))
			seen[base_name] = true
	for base_name in TerrainMaterialLibrary.AUTHORED_CLIFF_PATHS:
		assert(base_name != "")
		assert(not seen.has(base_name))
		seen[base_name] = true


## Presentation keeps a few per-material tables of its own — swatch colour, noise
## grain, height contrast. They are indexed by catalog index, so a material added
## without extending them would silently inherit whatever sits at its number.
static func _test_presentation_tables_are_catalog_sized() -> void:
	assert(TerrainMaterialLibrary.MATERIAL_COLOURS.size() == TerrainMaterialCatalog.MATERIAL_COUNT)
	assert(TerrainMaterialLibrary.GRAIN_BY_MATERIAL.size() == TerrainMaterialCatalog.MATERIAL_COUNT)
	assert(TerrainMaterialLibrary.HEIGHT_CONTRAST_BY_MATERIAL.size() == TerrainMaterialCatalog.MATERIAL_COUNT)
	assert(TerrainMaterialLibrary.CLIFF_COLOURS.size() == TerrainMaterialCatalog.cliff_count())
	# The grass swatches are the palette's per-variant colours, not a per-material
	# table, so they follow the variant count of grass instead of the catalog.
	assert(
		TerrainMaterialLibrary.GRASS_SWATCHES.size()
		== TerrainMaterialVariants.variant_count(TerrainMaterialCatalog.index_of(TerrainMaterialCatalog.GRASS))
	)


## **The invariant this whole file exists for.** `TerrainMaterialVariants` defines
## the layer layout and the mesher writes cliff layer numbers into vertex data
## from it; the library has to fill exactly those layers, in exactly that order.
##
## It did not. Extra layers for the simplified render mode were appended in the
## middle of the array, pushing all seven cliff faces past the numbers the mesher
## was sending — so every vertical face in the game sampled a procedural ground
## placeholder instead of rock, and nothing failed, because nothing compared the
## two. Building the real arrays here costs about a tenth of a second and closes
## that hole.
static func _test_built_arrays_match_the_domain_layout() -> void:
	var expected := TerrainMaterialVariants.TOTAL_LAYER_COUNT
	assert(expected == TerrainMaterialVariants.SURFACE_LAYER_COUNT + TerrainMaterialCatalog.cliff_count())
	assert(TerrainMaterialVariants.CLIFF_LAYER_OFFSET == TerrainMaterialVariants.SURFACE_LAYER_COUNT)
	for cliff_index in TerrainMaterialCatalog.cliff_count():
		var layer := TerrainMaterialVariants.cliff_layer_of(cliff_index)
		assert(layer >= TerrainMaterialVariants.SURFACE_LAYER_COUNT and layer < expected)

	var library := TerrainMaterialLibrary.new()
	assert(library.layer_count() == expected)
	assert(library.texture_array().get_layers() == expected, "the albedo array is the layout, not a superset of it")
	assert(library.normal_array().get_layers() == expected)
	# The simplified mode is its own array with the SAME layout, so a layer index
	# means one thing everywhere and no lookup has to be redirected.
	assert(library.simple_texture_array().get_layers() == expected)
