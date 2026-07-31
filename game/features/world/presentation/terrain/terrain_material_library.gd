class_name TerrainMaterialLibrary
extends RefCounted

## Packed texture arrays for terrain tops and cliffs. Stored variants are mapped
## through a tiny 16 x material-count lookup texture, so adding grass colours does
## not reserve empty layers for every unrelated material.

const TEXTURE_SIZE := 512
const PLACEHOLDER_SIZE := 128
const LOOKUP_WIDTH := TerrainMaterialVariants.MAX_VARIANTS

## Where every authored surface texture lives. One directory for the whole array;
## the mesher, the palette swatch and the cliff shader all resolve through it.
const ASSET_DIR := "res://game/features/world/presentation/terrain/assets/"

## Authored 512² surface underlays (albedo in RGB, height map in alpha) keyed by
## material id. The list for a material MUST cover exactly its
## `TerrainMaterialVariants.surface_style_count` styles, and each base name is the
## `<material_id>_<surface_style>` of that style — the test in
## `test_domain_terrain_textures.gd` enforces both, so adding a material or a
## variant without an entry here fails loudly instead of sampling a placeholder.
##
## An empty string means the style is not drawn yet: the layer falls back to a
## procedural placeholder, exactly as it did before this table existed. That is
## the whole point of stage 1 — the file paths are frozen now, and dropping the
## PNG in later (`design_docs/engine/terrain_materials.md` §7.1) lights the layer
## up without touching this file or the layer layout.
const AUTHORED_SURFACE_PATHS: Dictionary = {
	TerrainMaterialCatalog.GRASS: [
		"grass_ground_plain", "grass_ground_lush", "grass_ground_parched", "grass_ground_flowering",
	],
	TerrainMaterialCatalog.GRASS_TALL: [
		"grass_tall_ground_meadow", "grass_tall_ground_fern", "grass_tall_ground_eared",
	],
	TerrainMaterialCatalog.DIRT: ["dirt_plain", "dirt_dark", "dirt_cracked", "dirt_dusty"],
	TerrainMaterialCatalog.STONE: ["stone_grey", "stone_dark", "stone_sandstone", "stone_cooled_lava"],
	TerrainMaterialCatalog.SAND: ["sand_yellow", "sand_white", "sand_coarse"],
	TerrainMaterialCatalog.GRAVEL: ["gravel_river_pebbles", "gravel_crushed"],
	TerrainMaterialCatalog.MUD: ["mud_silty", "mud_puddled"],
	TerrainMaterialCatalog.SCORCHED: ["scorched_smouldering", "scorched_cold"],
	TerrainMaterialCatalog.ICE: ["ice_smooth", "ice_cracked", "ice_hummocks", "ice_dusty"],
	TerrainMaterialCatalog.LUNAR_REGOLITH: ["lunar_regolith_mare_dark", "lunar_regolith_highland_light"],
	TerrainMaterialCatalog.LUNAR_ROCK: ["lunar_rock_breccia", "lunar_rock_light_rock"],
	TerrainMaterialCatalog.MARS_REGOLITH: ["mars_regolith_red", "mars_regolith_ochre"],
	TerrainMaterialCatalog.MARS_ROCK: ["mars_rock_basalt", "mars_rock_layered"],
	TerrainMaterialCatalog.CLAY: ["clay_red", "clay_grey", "clay_dry"],
}

## Auto-rock cliff faces (`terrain_materials.md` §3). Same 512² layout as tops —
## the cliff shader samples the same texture array — indexed by `CLIFF_IDS` order.
const AUTHORED_CLIFF_PATHS: Array[String] = [
	"cliff_rooted_soil", "cliff_wet_clay", "cliff_sand_scree", "cliff_gravel_scree",
	"cliff_layered_rock", "cliff_ice_wall", "cliff_dust_slope",
]

const MATERIAL_COLOURS: Array[Color] = [
	Color(0.32, 0.49, 0.24), Color(0.42, 0.31, 0.20),
	Color(0.45, 0.45, 0.47), Color(0.76, 0.68, 0.45),
	Color(0.52, 0.51, 0.48), Color(0.29, 0.24, 0.18),
	Color(0.24, 0.38, 0.16), Color(0.20, 0.18, 0.17),
	Color(0.74, 0.84, 0.90), Color(0.38, 0.37, 0.36),
	Color(0.48, 0.47, 0.45), Color(0.55, 0.32, 0.20),
	Color(0.36, 0.24, 0.19), Color(0.62, 0.38, 0.26),
]

const GRASS_SWATCHES: Array[Color] = [
	Color(0.42, 0.58, 0.27), Color(0.18, 0.48, 0.17), Color(0.62, 0.49, 0.24),
	Color(0.92, 0.90, 0.78), Color(0.35, 0.52, 0.90), Color(0.82, 0.20, 0.18),
	Color(0.66, 0.38, 0.82), Color(0.94, 0.73, 0.16),
]

const CLIFF_COLOURS: Array[Color] = [
	Color(0.38, 0.30, 0.21), Color(0.31, 0.26, 0.20),
	Color(0.72, 0.63, 0.42), Color(0.49, 0.47, 0.44),
	Color(0.40, 0.39, 0.37), Color(0.70, 0.81, 0.89),
	Color(0.44, 0.40, 0.36),
]

const GRAIN_BY_MATERIAL: Array[int] = [6, 7, 12, 3, 5, 9, 5, 8, 16, 4, 12, 4, 12, 7]
const HEIGHT_CONTRAST_BY_MATERIAL: Array[float] = [
	0.45, 0.5, 0.9, 0.35, 0.8, 0.4, 0.5, 0.5, 0.3, 0.4, 0.85, 0.4, 0.85, 0.5,
]

var _array: Texture2DArray = null
var _normal_array: Texture2DArray = null
var _lookup_texture: ImageTexture = null
var _simple_lookup_texture: ImageTexture = null
var _images: Array[Image] = []
var _authored_layers: Dictionary = {}
var _simple_layers: Dictionary = {}


func texture_array() -> Texture2DArray:
	_ensure_images()
	if _array == null:
		_array = Texture2DArray.new()
		_array.create_from_images(_images)
	return _array


func normal_array() -> Texture2DArray:
	_ensure_images()
	if _normal_array != null:
		return _normal_array
	var normals: Array[Image] = []
	for layer in _images.size():
		normals.append(_normal_from_height(_images[layer]) if _authored_layers.has(layer) else _flat_normal())
	_normal_array = Texture2DArray.new()
	_normal_array.create_from_images(normals)
	return _normal_array


func layer_lookup_texture() -> ImageTexture:
	if _lookup_texture != null:
		return _lookup_texture
	var image := Image.create_empty(LOOKUP_WIDTH, TerrainMaterialCatalog.MATERIAL_COUNT, false, Image.FORMAT_R8)
	for material_index in TerrainMaterialCatalog.MATERIAL_COUNT:
		for variant in LOOKUP_WIDTH:
			var layer := TerrainMaterialVariants.layer_of(material_index, variant)
			image.set_pixel(variant, material_index, Color(float(layer) / 255.0, 0.0, 0.0, 1.0))
	_lookup_texture = ImageTexture.create_from_image(image)
	return _lookup_texture


func simple_layer_lookup_texture() -> ImageTexture:
	if _simple_lookup_texture != null:
		return _simple_lookup_texture
	_ensure_images()
	var image := Image.create_empty(LOOKUP_WIDTH, TerrainMaterialCatalog.MATERIAL_COUNT, false, Image.FORMAT_R8)
	for material_index in TerrainMaterialCatalog.MATERIAL_COUNT:
		for variant in LOOKUP_WIDTH:
			var style := TerrainMaterialVariants.surface_style_of(material_index, variant)
			var key: int = material_index * 16 + style
			var layer: int
			if _simple_layers.has(key):
				layer = int(_simple_layers[key])
			else:
				layer = TerrainMaterialVariants.layer_of(material_index, variant)
			image.set_pixel(variant, material_index, Color(float(layer) / 255.0, 0.0, 0.0, 1.0))
	_simple_lookup_texture = ImageTexture.create_from_image(image)
	return _simple_lookup_texture


func layer_count() -> int:
	return TerrainMaterialVariants.total_layer_count()


static func swatch_of(material_index: int, variant: int = 0) -> Color:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	var clamped := TerrainMaterialVariants.clamp_variant(index, variant)
	if index == TerrainMaterialCatalog.DEFAULT_INDEX:
		return GRASS_SWATCHES[clamped]
	return _tinted(MATERIAL_COLOURS[index], clamped)


func _ensure_images() -> void:
	if not _images.is_empty():
		return
	for material_index in TerrainMaterialCatalog.MATERIAL_COUNT:
		for style in TerrainMaterialVariants.surface_style_count(material_index):
			var path := _authored_path(material_index, style)
			var layer := _images.size()
			if path != "":
				_images.append(_load_authored(path))
				_authored_layers[layer] = true
			else:
				_images.append(_generate_placeholder(material_index, style))
	for material_index in TerrainMaterialCatalog.MATERIAL_COUNT:
		if _authored_path(material_index, 0) == "":
			continue
		for style in TerrainMaterialVariants.surface_style_count(material_index):
			var simple_layer := _images.size()
			_images.append(_generate_placeholder(material_index, style))
			_simple_layers[material_index * 16 + style] = simple_layer
	for cliff_index in TerrainMaterialCatalog.cliff_count():
		var cliff_path := _authored_cliff_path(cliff_index)
		if cliff_path != "":
			_images.append(_load_authored(cliff_path))
			_authored_layers[_images.size() - 1] = true
		else:
			_images.append(_generate(CLIFF_COLOURS[cliff_index], 10, 0.8, 1000 + cliff_index))


## Resolves a material + surface style to its authored PNG, or "" when the style
## is not drawn yet (or the file is missing on disk). "" routes the caller to the
## procedural placeholder, so a not-yet-authored layer never breaks the array.
func _authored_path(material_index: int, style: int) -> String:
	var id := TerrainMaterialCatalog.id_of_index(material_index)
	if not AUTHORED_SURFACE_PATHS.has(id):
		return ""
	var base_names: Array = AUTHORED_SURFACE_PATHS[id]
	if style < 0 or style >= base_names.size() or base_names[style] == "":
		return ""
	var base_name: String = base_names[style]
	var path: String = ASSET_DIR + base_name + ".png"
	return path if ResourceLoader.exists(path) else ""


## Same contract as `_authored_path`, for the cliff face kinds of §3.
func _authored_cliff_path(cliff_index: int) -> String:
	if cliff_index < 0 or cliff_index >= AUTHORED_CLIFF_PATHS.size():
		return ""
	var base_name: String = AUTHORED_CLIFF_PATHS[cliff_index]
	if base_name == "":
		return ""
	var path := ASSET_DIR + base_name + ".png"
	return path if ResourceLoader.exists(path) else ""


func _load_authored(path: String) -> Image:
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != TEXTURE_SIZE or image.get_height() != TEXTURE_SIZE:
		image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	if not image.has_mipmaps():
		image.generate_mipmaps()
	return image


func _generate_placeholder(material_index: int, style: int) -> Image:
	return _generate(
		_tinted(MATERIAL_COLOURS[material_index], style),
		GRAIN_BY_MATERIAL[material_index],
		HEIGHT_CONTRAST_BY_MATERIAL[material_index],
		material_index * 31 + style,
	)


static func _tinted(base: Color, variant: int) -> Color:
	match variant:
		1: return base.darkened(0.14)
		2: return base.lightened(0.12)
		3: return base.lerp(Color(0.62, 0.58, 0.48), 0.18)
	return base


static func _generate(base: Color, grain: int, height_contrast: float, seed_value: int) -> Image:
	var image := Image.create_empty(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value * 7919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / maxf(float(grain), 1.0)
	var detail := FastNoiseLite.new()
	detail.seed = seed_value * 7919 + 13
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 1.0 / maxf(float(grain) * 0.35, 1.0)
	for y in PLACEHOLDER_SIZE:
		for x in PLACEHOLDER_SIZE:
			var coarse := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var fine := detail.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var value := clampf(coarse * 0.7 + fine * 0.3, 0.0, 1.0)
			var albedo := base.lerp(base.lightened(0.35), value * 0.55).darkened((1.0 - value) * 0.18)
			albedo.a = clampf(0.5 + (value - 0.5) * height_contrast * 2.0, 0.0, 1.0)
			image.set_pixel(x, y, albedo)
	image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_CUBIC)
	image.generate_mipmaps()
	return image


static func _flat_normal() -> Image:
	var image := Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, true, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 1.0, 1.0))
	image.generate_mipmaps()
	return image


static func _normal_from_height(source: Image) -> Image:
	var image := Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEXTURE_SIZE:
		var previous_y := (y - 1 + TEXTURE_SIZE) % TEXTURE_SIZE
		var next_y := (y + 1) % TEXTURE_SIZE
		for x in TEXTURE_SIZE:
			var previous_x := (x - 1 + TEXTURE_SIZE) % TEXTURE_SIZE
			var next_x := (x + 1) % TEXTURE_SIZE
			var dx := source.get_pixel(next_x, y).a - source.get_pixel(previous_x, y).a
			var dy := source.get_pixel(x, next_y).a - source.get_pixel(x, previous_y).a
			var normal := Vector3(-dx * 2.4, -dy * 2.4, 1.0).normalized()
			image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, 1.0))
	image.generate_mipmaps()
	return image
