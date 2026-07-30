class_name TerrainMaterialVariants
extends RefCounted

## Stable visual variants of terrain materials.
##
## The stored detail byte has four variant bits, but the GPU texture array is
## packed: materials pay only for the surface styles they actually use. Several
## grass variants can therefore share one ground style while keeping distinct
## vegetation cards (the five flower colours all use the same meadow floor).

const MAX_VARIANTS := 16

const VARIANTS_BY_INDEX: Array = [
	[&"plain", &"lush", &"parched", &"flower_white", &"flower_blue", &"flower_red", &"flower_purple", &"flower_yellow"], # grass
	[&"plain", &"dark", &"cracked", &"dusty"],              # dirt
	[&"grey", &"dark", &"sandstone", &"cooled_lava"],       # stone
	[&"yellow", &"white", &"coarse"],                       # sand
	[&"river_pebbles", &"crushed"],                         # gravel
	[&"silty", &"puddled"],                                 # mud
	[&"meadow", &"fern", &"eared"],                         # grass_tall
	[&"smouldering", &"cold"],                              # scorched
	[&"smooth", &"cracked", &"hummocks", &"dusty"],         # ice
	[&"mare_dark", &"highland_light"],                      # lunar_regolith
	[&"breccia", &"light_rock"],                            # lunar_rock
	[&"red", &"ochre"],                                     # mars_regolith
	[&"basalt", &"layered"],                                # mars_rock
	[&"red", &"grey", &"dry"],                              # clay
]

## Stored variant -> authored surface style. Flower colour belongs to the
## MultiMesh cutout, not to five duplicate copies of the same soil texture.
const SURFACE_STYLE_BY_VARIANT: Array = [
	[0, 1, 2, 3, 3, 3, 3, 3], # grass: plain, lush, parched, shared flower meadow
	[0, 1, 2, 3],
	[0, 1, 2, 3],
	[0, 1, 2],
	[0, 1],
	[0, 1],
	[0, 1, 2],
	[0, 1],
	[0, 1, 2, 3],
	[0, 1],
	[0, 1],
	[0, 1],
	[0, 1],
	[0, 1, 2],
]


static func variant_count(material_index: int) -> int:
	if not TerrainMaterialCatalog.is_valid_index(material_index):
		return 1
	return (VARIANTS_BY_INDEX[material_index] as Array).size()


static func variants_of(material_index: int) -> Array:
	if not TerrainMaterialCatalog.is_valid_index(material_index):
		return VARIANTS_BY_INDEX[TerrainMaterialCatalog.DEFAULT_INDEX]
	return VARIANTS_BY_INDEX[material_index]


static func variant_name(material_index: int, variant: int) -> StringName:
	var names: Array = variants_of(material_index)
	return names[clampi(variant, 0, names.size() - 1)]


static func clamp_variant(material_index: int, variant: int) -> int:
	return clampi(variant, 0, variant_count(material_index) - 1)


static func surface_style_count(material_index: int) -> int:
	if not TerrainMaterialCatalog.is_valid_index(material_index):
		return 1
	var styles: Array = SURFACE_STYLE_BY_VARIANT[material_index]
	var highest := 0
	for style: int in styles:
		highest = maxi(highest, style)
	return highest + 1


static func surface_style_of(material_index: int, variant: int) -> int:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	var styles: Array = SURFACE_STYLE_BY_VARIANT[index]
	return int(styles[clamp_variant(index, variant)])


static func surface_layer_offset(material_index: int) -> int:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	var offset := 0
	for previous in index:
		offset += surface_style_count(previous)
	return offset


static func layer_of(material_index: int, variant: int) -> int:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	return surface_layer_offset(index) + surface_style_of(index, variant)


static func surface_layer_count() -> int:
	var count := 0
	for index in TerrainMaterialCatalog.MATERIAL_COUNT:
		count += surface_style_count(index)
	return count


static func cliff_layer_of(cliff_index: int) -> int:
	return surface_layer_count() + clampi(cliff_index, 0, TerrainMaterialCatalog.cliff_count() - 1)


static func cliff_layer_of_material(material_index: int) -> int:
	return cliff_layer_of(TerrainMaterialCatalog.cliff_index_of_index(material_index))


static func total_layer_count() -> int:
	return surface_layer_count() + TerrainMaterialCatalog.cliff_count()


static func procedural_variant(material_index: int, cell: Vector2i) -> int:
	var count := variant_count(material_index)
	if count <= 1:
		return 0
	var hashed := int(hash(Vector3i(cell.x, cell.y, material_index)))
	return absi(hashed) % count
