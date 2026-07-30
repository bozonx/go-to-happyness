class_name TerrainMaterialLibrary
extends RefCounted

## The one texture binding of the whole world (design_docs/engine/terrain_materials.md §7.1).
##
## Every material × variant is a layer of a single `Texture2DArray`, at
## `layer = material_index * MAX_VARIANTS + variant`, and the auto-rock face kinds
## (§3) follow them in the same array. One `sampler2DArray`, one binding, for the
## ground shader and the cliff shader alike — a surface per material would be
## hundreds of draw calls on an empty map (§7.2).
##
## The **alpha channel carries the height map of the texture**, not opacity. That
## is what height-based blending (§7.3) reads: without it the boundary between two
## materials is a muddy gradient instead of grass growing through the cracks of
## stone.
##
## Layers are generated procedurally here. The design budgets BC7 512² art (~20 MB
## for the world); this class produces stand-ins with the same layout, so the
## shader path, the blending and the layer arithmetic are the real thing and only
## the pixels are placeholders. Dropping authored textures in later means filling
## `_image_for_layer` from files — no other code changes, because the layout is
## derived from the catalog rather than written down twice.

## Placeholder resolution. Authored art is 512² (§7.1); the generator is only
## asked for enough pixels to judge blending and tiling.
const TEXTURE_SIZE := 128

## Base albedo per material index, and how far a variant may push it. A variant
## must never read as a different material — that is the whole point of §4.
const MATERIAL_COLOURS: Array[Color] = [
	Color(0.32, 0.49, 0.24),  # grass
	Color(0.42, 0.31, 0.20),  # dirt
	Color(0.45, 0.45, 0.47),  # stone
	Color(0.76, 0.68, 0.45),  # sand
	Color(0.52, 0.51, 0.48),  # gravel
	Color(0.29, 0.24, 0.18),  # mud
	Color(0.36, 0.47, 0.21),  # grass_tall
	Color(0.20, 0.18, 0.17),  # scorched
	Color(0.74, 0.84, 0.90),  # ice
	Color(0.38, 0.37, 0.36),  # lunar_regolith
	Color(0.48, 0.47, 0.45),  # lunar_rock
	Color(0.55, 0.32, 0.20),  # mars_regolith
	Color(0.36, 0.24, 0.19),  # mars_rock
	Color(0.62, 0.38, 0.26),  # clay
]

## Face kinds, in `TerrainMaterialCatalog.CLIFF_IDS` order.
const CLIFF_COLOURS: Array[Color] = [
	Color(0.38, 0.30, 0.21),  # rooted soil
	Color(0.31, 0.26, 0.20),  # wet clay
	Color(0.72, 0.63, 0.42),  # sand scree
	Color(0.49, 0.47, 0.44),  # gravel scree
	Color(0.40, 0.39, 0.37),  # layered rock
	Color(0.70, 0.81, 0.89),  # ice wall
	Color(0.44, 0.40, 0.36),  # dust slope
]

## Grain size of the generated noise per material, in texels. Sand is fine, gravel
## is chunky; it is the cheapest way to make placeholder layers distinguishable
## while blending is being judged.
const GRAIN_BY_MATERIAL: Array[int] = [6, 7, 12, 3, 5, 9, 5, 8, 16, 4, 12, 4, 12, 7]

## How strongly the generated height map varies. High-contrast height makes the
## blend edge interlock (stone through grass); flat height makes it a soft fade.
const HEIGHT_CONTRAST_BY_MATERIAL: Array[float] = [
	0.45, 0.5, 0.9, 0.35, 0.8, 0.4, 0.5, 0.5, 0.3, 0.4, 0.85, 0.4, 0.85, 0.5,
]

var _array: Texture2DArray = null


## The array, built on first use. Cached: it is the same for every chunk and every
## shader in the world.
func texture_array() -> Texture2DArray:
	if _array != null:
		return _array
	var images: Array[Image] = []
	for layer in TerrainMaterialVariants.total_layer_count():
		images.append(_image_for_layer(layer))
	_array = Texture2DArray.new()
	_array.create_from_images(images)
	return _array


func layer_count() -> int:
	return TerrainMaterialVariants.total_layer_count()


## Colour of a material+variant as flat data — for the lab HUD, the material
## picker and anything else that wants a swatch without a texture.
static func swatch_of(material_index: int, variant: int = 0) -> Color:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	return _tinted(MATERIAL_COLOURS[index], TerrainMaterialVariants.clamp_variant(index, variant))


func _image_for_layer(layer: int) -> Image:
	if layer >= TerrainMaterialVariants.CLIFF_LAYER_BASE:
		var cliff_index := layer - TerrainMaterialVariants.CLIFF_LAYER_BASE
		return _generate(CLIFF_COLOURS[cliff_index], 10, 0.8, layer)
	var material_index := layer / TerrainMaterialVariants.MAX_VARIANTS
	var variant := layer % TerrainMaterialVariants.MAX_VARIANTS
	# Slots past a material's variant list are never sampled (the codec clamps the
	# stored variant), but the array still owns them, and an uninitialised layer
	# shows up as garbage the moment a stale save points at one.
	var clamped := TerrainMaterialVariants.clamp_variant(material_index, variant)
	return _generate(
		_tinted(MATERIAL_COLOURS[material_index], clamped),
		GRAIN_BY_MATERIAL[material_index],
		HEIGHT_CONTRAST_BY_MATERIAL[material_index],
		material_index * TerrainMaterialVariants.MAX_VARIANTS + clamped,
	)


## Variants shift value and saturation only. "Lush" and "parched" grass have to
## stay grass; a variant that changes hue is a new material pretending to be one.
static func _tinted(base: Color, variant: int) -> Color:
	match variant:
		1:
			return base.darkened(0.14)
		2:
			return base.lightened(0.12)
		3:
			return base.lerp(Color(0.62, 0.58, 0.48), 0.18)
	return base


## Albedo in RGB, texture height in A (§7.1). Value noise at one grain size plus a
## finer octave: enough structure for the height blend to bite into.
static func _generate(base: Color, grain: int, height_contrast: float, seed_value: int) -> Image:
	var image := Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value * 7919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / maxf(float(grain), 1.0)
	var detail := FastNoiseLite.new()
	detail.seed = seed_value * 7919 + 13
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 1.0 / maxf(float(grain) * 0.35, 1.0)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var coarse := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var fine := detail.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var value := clampf(coarse * 0.7 + fine * 0.3, 0.0, 1.0)
			var albedo := base.lerp(base.lightened(0.35), value * 0.55).darkened((1.0 - value) * 0.18)
			albedo.a = clampf(0.5 + (value - 0.5) * height_contrast * 2.0, 0.0, 1.0)
			image.set_pixel(x, y, albedo)
	image.generate_mipmaps()
	return image
