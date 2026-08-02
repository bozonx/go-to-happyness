class_name TerrainMaterialLibrary
extends RefCounted

## Packed texture arrays for terrain tops and cliffs
## (design_docs/engine/terrain_materials.md §7.1).
##
## ## The layout is owned by the domain
##
## `TerrainMaterialVariants` defines the one array layout — surface styles in
## catalog order, then the cliff faces — and this file's only job is to fill
## exactly `TOTAL_LAYER_COUNT` layers in exactly that order. It may not insert a
## block of its own: it did once, for the simplified render mode, and because
## nothing compared the two the cliff shader spent every frame sampling ground
## placeholders instead of rock. The simplified mode now has its OWN small array
## with the SAME layout, so a layer index means one thing everywhere.
##
## Stored variants reach a layer through a tiny 16 × material-count lookup
## texture, so adding grass colours does not reserve empty layers for stone.
##
## ## Nothing here is computed per texel at load time
##
## Normal maps are authored assets (`<name>_n.png`), baked offline by
## `tools/bake_terrain_normals.gd` from the height map in each albedo's alpha.
## Deriving them at runtime was a GDScript loop over 262 144 texels per layer,
## measured at 4.8 seconds in the middle of loading a map. A style with no baked
## normal falls back to a flat one rather than paying that cost lazily.

const TEXTURE_SIZE := 512
## Baked normals are half the albedo's resolution on purpose: a normal map is a
## low-frequency signal next to the colour it accompanies, nobody can see the
## difference at this camera height, and it is the difference between four and
## one megabyte of repository per layer.
const NORMAL_TEXTURE_SIZE := 256
## The simplified render mode is a readability aid, not a shipping look, so its
## array is a sixteenth of the memory and never resized up to match the real one.
const SIMPLE_TEXTURE_SIZE := 128
const LOOKUP_WIDTH := TerrainMaterialVariants.MAX_VARIANTS

## Where every authored surface texture lives. One directory for the whole array;
## the mesher, the palette swatch and the cliff shader all resolve through it.
const ASSET_DIR := "res://game/features/world/presentation/terrain/assets/"

## Suffix of the baked normal map belonging to an authored surface or cliff.
const NORMAL_SUFFIX := "_n"

## Authored 512² surface underlays (albedo in RGB, height map in alpha) keyed by
## material id. The list for a material MUST cover exactly its
## `TerrainMaterialVariants.surface_style_count` styles, and each base name is the
## `<material_id>_<surface_style>` of that style — the test in
## `test_domain_terrain_textures.gd` enforces both, so adding a material or a
## variant without an entry here fails loudly instead of sampling a placeholder.
##
## An empty string means the style is not drawn yet: the layer falls back to a
## procedural placeholder. That is deliberate — the file paths are frozen, and
## dropping the PNG in later lights the layer up without touching this file or
## the layer layout.
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
	TerrainMaterialCatalog.CLAY: ["clay_red", "clay_grey"],
}

## Auto-rock cliff faces (`terrain_materials.md` §3). Same 512² layout as tops —
## the cliff shader samples the same texture array — indexed by `CLIFF_IDS` order.
const AUTHORED_CLIFF_PATHS: Array[String] = [
	"cliff_rooted_soil", "cliff_wet_clay", "cliff_sand_scree", "cliff_gravel_scree",
	"cliff_layered_rock", "cliff_ice_wall", "cliff_dust_slope",
]

## Presentation-only tables, one entry per catalog material. Sizes are asserted
## against the catalog in `test_domain_terrain_textures.gd`: a new material must
## not silently inherit the colour of whichever entry happens to sit at its index.
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
var _simple_array: Texture2DArray = null
var _lookup_texture: ImageTexture = null


func texture_array() -> Texture2DArray:
	if _array == null:
		_array = _build_array(_albedo_images())
	return _array


func normal_array() -> Texture2DArray:
	if _normal_array == null:
		_normal_array = _build_array(_normal_images())
	return _normal_array


## The simplified render mode: the same layout at a sixteenth of the resolution,
## procedural throughout. It exists so the author can read shape and material
## boundaries without the authored detail, which is why it never loads a PNG.
func simple_texture_array() -> Texture2DArray:
	if _simple_array == null:
		_simple_array = _build_array(_simple_images())
	return _simple_array


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


func layer_count() -> int:
	return TerrainMaterialVariants.TOTAL_LAYER_COUNT


static func swatch_of(material_index: int, variant: int = 0) -> Color:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	var clamped := TerrainMaterialVariants.clamp_variant(index, variant)
	if index == TerrainMaterialCatalog.DEFAULT_INDEX:
		return GRASS_SWATCHES[clamped]
	return _tinted(MATERIAL_COLOURS[index], clamped)


# --- Layer assembly -----------------------------------------------------------

## Walks the layout of `TerrainMaterialVariants` exactly once and calls back for
## each layer. Every array this class builds goes through it, which is what makes
## "the three arrays have identical layouts" a property of the code rather than a
## thing to remember.
static func _for_each_layer(surface: Callable, cliff: Callable) -> Array[Image]:
	var images: Array[Image] = []
	for material_index in TerrainMaterialCatalog.MATERIAL_COUNT:
		for style in TerrainMaterialVariants.surface_style_count(material_index):
			images.append(surface.call(material_index, style))
	for cliff_index in TerrainMaterialCatalog.cliff_count():
		images.append(cliff.call(cliff_index))
	return images


func _albedo_images() -> Array[Image]:
	return _for_each_layer(
		func(material_index: int, style: int) -> Image:
			var path := authored_surface_path(material_index, style)
			if path != "":
				return _load_authored(path, TEXTURE_SIZE)
			return _generate_placeholder(material_index, style, TEXTURE_SIZE),
		func(cliff_index: int) -> Image:
			var path := authored_cliff_path(cliff_index)
			if path != "":
				return _load_authored(path, TEXTURE_SIZE)
			return _generate(CLIFF_COLOURS[cliff_index], 10, 0.8, 1000 + cliff_index, TEXTURE_SIZE),
	)


func _normal_images() -> Array[Image]:
	return _for_each_layer(
		func(material_index: int, style: int) -> Image:
			return _load_normal(authored_surface_path(material_index, style)),
		func(cliff_index: int) -> Image:
			return _load_normal(authored_cliff_path(cliff_index)),
	)


func _simple_images() -> Array[Image]:
	return _for_each_layer(
		func(material_index: int, style: int) -> Image:
			return _generate_placeholder(material_index, style, SIMPLE_TEXTURE_SIZE),
		func(cliff_index: int) -> Image:
			return _generate(CLIFF_COLOURS[cliff_index], 10, 0.8, 1000 + cliff_index, SIMPLE_TEXTURE_SIZE),
	)


## `Texture2DArray` demands one format, one size and one mip chain from every
## layer. When they already agree — the normal case, because the whole array
## comes from one import preset — the images go through untouched and the GPU
## keeps the compressed data the importer produced.
##
## They disagree only when a style has no authored PNG and fell back to a
## procedural placeholder. Matching a placeholder to a compressed neighbour would
## mean guessing which compressor the importer chose, so the mismatch is resolved
## the other way: everything drops to plain RGBA8 at the largest size present.
## That costs memory exactly while a texture is missing, which is a state worth
## noticing rather than hiding.
static func _build_array(images: Array[Image]) -> Texture2DArray:
	var built := Texture2DArray.new()
	if images.is_empty():
		return built
	if not _layers_agree(images):
		_flatten_to_rgba8(images)
	built.create_from_images(images)
	return built


static func _layers_agree(images: Array[Image]) -> bool:
	var reference := images[0]
	for index in range(1, images.size()):
		var image := images[index]
		if (
			image.get_format() != reference.get_format()
			or image.get_width() != reference.get_width()
			or image.get_height() != reference.get_height()
			or image.has_mipmaps() != reference.has_mipmaps()
		):
			return false
	return true


static func _flatten_to_rgba8(images: Array[Image]) -> void:
	var size := 0
	for image: Image in images:
		size = maxi(size, image.get_width())
	for index in images.size():
		var flattened := images[index].duplicate() as Image
		if flattened.is_compressed():
			flattened.decompress()
		if flattened.get_format() != Image.FORMAT_RGBA8:
			flattened.convert(Image.FORMAT_RGBA8)
		if flattened.get_width() != size or flattened.get_height() != size:
			flattened.resize(size, size, Image.INTERPOLATE_LANCZOS)
		if not flattened.has_mipmaps():
			flattened.generate_mipmaps()
		images[index] = flattened


# --- Paths --------------------------------------------------------------------

## Resolves a material + surface style to its authored PNG, or "" when the style
## is not drawn yet (or the file is missing on disk). "" routes the caller to the
## procedural placeholder, so a not-yet-authored layer never breaks the array.
static func authored_surface_path(material_index: int, style: int) -> String:
	var id := TerrainMaterialCatalog.id_of_index(material_index)
	if not AUTHORED_SURFACE_PATHS.has(id):
		return ""
	var base_names: Array = AUTHORED_SURFACE_PATHS[id]
	if style < 0 or style >= base_names.size() or base_names[style] == "":
		return ""
	var path: String = ASSET_DIR + String(base_names[style]) + ".png"
	return path if ResourceLoader.exists(path) else ""


## Same contract as `authored_surface_path`, for the cliff face kinds of §3.
static func authored_cliff_path(cliff_index: int) -> String:
	if cliff_index < 0 or cliff_index >= AUTHORED_CLIFF_PATHS.size():
		return ""
	var base_name: String = AUTHORED_CLIFF_PATHS[cliff_index]
	if base_name == "":
		return ""
	var path := ASSET_DIR + base_name + ".png"
	return path if ResourceLoader.exists(path) else ""


## The baked normal map belonging to an albedo, whether or not it exists yet.
static func normal_path_of(albedo_path: String) -> String:
	if albedo_path == "":
		return ""
	return albedo_path.get_basename() + NORMAL_SUFFIX + ".png"


# --- Images -------------------------------------------------------------------

## Loads an authored texture as-is. No `convert` and no `generate_mipmaps`: the
## import settings already decide the format and the mip chain, and redoing both
## at runtime for every layer was most of the two seconds this used to cost. Only
## a file whose size disagrees with the array is touched.
static func _load_authored(path: String, size: int) -> Image:
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	if image.get_width() == size and image.get_height() == size:
		return image
	var resized := image.duplicate() as Image
	if resized.is_compressed():
		resized.decompress()
	resized.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return resized


## The baked normal of an albedo, or a flat one when it has not been baked.
static func _load_normal(albedo_path: String) -> Image:
	var path := normal_path_of(albedo_path)
	if path != "" and ResourceLoader.exists(path):
		return (load(path) as Texture2D).get_image()
	return _flat_normal()


static func _flat_normal() -> Image:
	var image := Image.create_empty(NORMAL_TEXTURE_SIZE, NORMAL_TEXTURE_SIZE, true, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 1.0, 1.0))
	image.generate_mipmaps()
	return image


static func _generate_placeholder(material_index: int, style: int, size: int) -> Image:
	return _generate(
		_tinted(MATERIAL_COLOURS[material_index], style),
		GRAIN_BY_MATERIAL[material_index],
		HEIGHT_CONTRAST_BY_MATERIAL[material_index],
		material_index * 31 + style,
		size,
	)


static func _tinted(base: Color, variant: int) -> Color:
	match variant:
		1: return base.darkened(0.14)
		2: return base.lightened(0.12)
		3: return base.lerp(Color(0.62, 0.58, 0.48), 0.18)
	return base


## Procedural noise, written straight into the byte buffer. It is generated at the
## resolution it will be USED at: the old version always built 128² and then
## resized up to 512², which is four megabytes of interpolation to recover detail
## the source never had.
static func _generate(base: Color, grain: int, height_contrast: float, seed_value: int, size: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value * 7919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var scale := float(size) / 128.0
	noise.frequency = 1.0 / maxf(float(grain) * scale, 1.0)
	var detail := FastNoiseLite.new()
	detail.seed = seed_value * 7919 + 13
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 1.0 / maxf(float(grain) * scale * 0.35, 1.0)
	var pixels := PackedByteArray()
	pixels.resize(size * size * 4)
	var offset := 0
	for y in size:
		for x in size:
			var coarse := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var fine := detail.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var value := clampf(coarse * 0.7 + fine * 0.3, 0.0, 1.0)
			var albedo := base.lerp(base.lightened(0.35), value * 0.55).darkened((1.0 - value) * 0.18)
			pixels[offset] = int(clampf(albedo.r, 0.0, 1.0) * 255.0)
			pixels[offset + 1] = int(clampf(albedo.g, 0.0, 1.0) * 255.0)
			pixels[offset + 2] = int(clampf(albedo.b, 0.0, 1.0) * 255.0)
			pixels[offset + 3] = int(clampf(0.5 + (value - 0.5) * height_contrast * 2.0, 0.0, 1.0) * 255.0)
			offset += 4
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, pixels)
	image.generate_mipmaps()
	return image


## Central difference over the height map in the source's alpha, on the raw byte
## buffers. **This is a baking-time function** — `tools/bake_terrain_normals.gd`
## is its only caller — and it stays here because the packing rule it inverts
## (alpha carries height, §7.1) is this file's rule.
static func normal_from_height(source: Image, size: int) -> Image:
	var heights := source
	if heights.is_compressed():
		heights = heights.duplicate() as Image
		heights.decompress()
	if heights.get_format() != Image.FORMAT_RGBA8:
		if heights == source:
			heights = heights.duplicate() as Image
		heights.convert(Image.FORMAT_RGBA8)
	if heights.get_width() != size or heights.get_height() != size:
		if heights == source:
			heights = heights.duplicate() as Image
		heights.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var data := heights.get_data()
	var normals := PackedByteArray()
	normals.resize(size * size * 4)
	var inverse := 1.0 / 255.0
	for y in size:
		var row := y * size
		var previous_row := ((y - 1 + size) % size) * size
		var next_row := ((y + 1) % size) * size
		for x in size:
			var previous_x := (x - 1 + size) % size
			var next_x := (x + 1) % size
			# RGBA8: alpha is the fourth byte of each texel, and alpha is where the
			# authored height map lives (§7.1).
			var dx := float(data[(row + next_x) * 4 + 3] - data[(row + previous_x) * 4 + 3]) * inverse
			var dy := float(data[(next_row + x) * 4 + 3] - data[(previous_row + x) * 4 + 3]) * inverse
			var normal := Vector3(-dx * 2.4, -dy * 2.4, 1.0).normalized()
			var offset := (row + x) * 4
			normals[offset] = int(normal.x * 127.5 + 127.5)
			normals[offset + 1] = int(normal.y * 127.5 + 127.5)
			normals[offset + 2] = int(normal.z * 127.5 + 127.5)
			normals[offset + 3] = 255
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, normals)
