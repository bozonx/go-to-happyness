class_name CoverageLibrary
extends RefCounted

## What built coverage looks like (map_editor.md §5.2.1).
##
## The split is the same one the ground already uses: `CoverageCatalog` in
## `routing/domain` says what a surface COSTS and who may use it, and this says
## what it looks like — exactly as `TerrainMaterialCatalog` names a material and
## `TerrainMaterialLibrary` renders it. Routing has no business holding a colour,
## and a palette swatch has no business deciding what a cart may drive on.
##
## Coverage is drawn as a tinted surface rather than its own texture array for
## now: one lookup row, no second `Texture2DArray` binding, and the shader path is
## the one already there. When authored coverage textures arrive they replace the
## colour in this row and nothing else moves — the layer, the codec and the
## catalog never learn about either.

## One texel per catalog index, index 0 included, so the shader can index it
## directly with the byte it read out of the coverage map.
const PALETTE_HEIGHT := 1

## Colours by canonical id. An entry with no colour here — a pack surface — draws
## in `FALLBACK`, which is deliberately readable rather than magenta: an
## uninstalled texture is not a reason to make the map unusable.
const COLOURS: Dictionary = {
	CoverageCatalog.TRAIL: Color(0.62, 0.55, 0.42),
	CoverageCatalog.DIRT: Color(0.48, 0.39, 0.29),
	CoverageCatalog.CLAY: Color(0.60, 0.45, 0.34),
	CoverageCatalog.WOOD: Color(0.45, 0.33, 0.21),
	CoverageCatalog.STONE: Color(0.52, 0.52, 0.50),
	CoverageCatalog.ASPHALT: Color(0.24, 0.24, 0.26),
}

const FALLBACK := Color(0.55, 0.52, 0.48)

## How much of the ground each surface hides. A trail is a worn line through the
## grass and still shows it; a paved road does not.
const OPACITY: Dictionary = {
	CoverageCatalog.TRAIL: 0.75,
}

const DEFAULT_OPACITY := 1.0

var _palette_texture: ImageTexture = null


## Colour of a catalog index, for the editor palette swatch and the status line.
static func colour_of_index(index: int) -> Color:
	if index == CoverageLayer.NO_COVERAGE:
		return Color(0, 0, 0, 0)
	return COLOURS.get(CoverageCatalog.id_of_index(index), FALLBACK)


static func opacity_of_index(index: int) -> float:
	if index == CoverageLayer.NO_COVERAGE:
		return 0.0
	return float(OPACITY.get(CoverageCatalog.id_of_index(index), DEFAULT_OPACITY))


## The lookup row the ground shader samples: RGB is the surface colour, alpha is
## how completely it covers the ground beneath.
func palette_texture() -> ImageTexture:
	if _palette_texture != null:
		return _palette_texture
	var width := maxi(CoverageCatalog.count(), 1)
	var image := Image.create_empty(width, PALETTE_HEIGHT, false, Image.FORMAT_RGBA8)
	for index in width:
		var colour := colour_of_index(index)
		colour.a = opacity_of_index(index)
		image.set_pixel(index, 0, colour)
	_palette_texture = ImageTexture.create_from_image(image)
	return _palette_texture


func palette_size() -> int:
	return maxi(CoverageCatalog.count(), 1)
