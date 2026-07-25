class_name TerrainMaterialVariants
extends RefCounted

## Visual variants of a material and the texture-array layout they imply
## (design_docs/core/terrain_materials.md §4, §7.1).
##
## A variant NEVER changes gameplay: same repose, same weight, same soil, same
## cliff face. It is the answer to "this only looks different", which is why the
## material catalog stays at thirteen entries while the world stops looking like
## thirteen textures.
##
## The budget of four variants per material is not taste, it is the array layout:
## `layer = material_index * MAX_VARIANTS + variant`, and every unused slot is
## VRAM paid for nothing. The stored field is four bits wide on purpose — room to
## raise `MAX_VARIANTS` later without changing the save format (§5).
##
## Layer numbers live here rather than in presentation because they are derived
## from the catalog, and presentation must be able to *build* its arrays from the
## domain instead of keeping a second list that drifts.

const MAX_VARIANTS := 4

## Variant names per material index, in layer order. Names are for the editor's
## variant picker and for tests; nothing in the simulation reads them.
const VARIANTS_BY_INDEX: Array = [
	[&"plain", &"lush", &"flowering", &"parched"],          # grass
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
]

## Layers 0 … `MATERIAL_LAYER_COUNT-1` are material × variant; the auto-rock face
## kinds (§3) follow them in the same array, so the whole world still costs one
## `sampler2DArray` and one binding (§7.1).
const MATERIAL_LAYER_COUNT := TerrainMaterialCatalog.MATERIAL_COUNT * MAX_VARIANTS
const CLIFF_LAYER_BASE := MATERIAL_LAYER_COUNT


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


## Clamps a variant to what this material actually has. A stored variant can
## outlive the texture set it was painted against (a material may lose a variant
## between builds), and pointing at an empty layer would sample garbage.
static func clamp_variant(material_index: int, variant: int) -> int:
	return clampi(variant, 0, variant_count(material_index) - 1)


## The texture-array layer of a material+variant pair. The only formula in the
## system that ties the domain catalog to GPU memory (§7.1).
static func layer_of(material_index: int, variant: int) -> int:
	var index := material_index if TerrainMaterialCatalog.is_valid_index(material_index) else TerrainMaterialCatalog.DEFAULT_INDEX
	return index * MAX_VARIANTS + clamp_variant(index, variant)


## Layer of an auto-rock face kind, by its position in
## `TerrainMaterialCatalog.CLIFF_IDS`.
static func cliff_layer_of(cliff_index: int) -> int:
	var count := TerrainMaterialCatalog.cliff_count()
	return CLIFF_LAYER_BASE + clampi(cliff_index, 0, count - 1)


## Layer of the face under a column of this material — what the mesher hands to
## the cliff shader.
static func cliff_layer_of_material(material_index: int) -> int:
	return cliff_layer_of(TerrainMaterialCatalog.cliff_index_of_index(material_index))


## Total layers the array must hold: every material slot (including the unused
## tail of materials with fewer variants) plus the face kinds.
static func total_layer_count() -> int:
	return CLIFF_LAYER_BASE + TerrainMaterialCatalog.cliff_count()


## Deterministic variant for procedural ground: the same cell always gets the same
## look, so a generated map never has to store what it can recompute (§4).
static func procedural_variant(material_index: int, cell: Vector2i) -> int:
	var count := variant_count(material_index)
	if count <= 1:
		return 0
	var hashed := int(hash(Vector3i(cell.x, cell.y, material_index)))
	return absi(hashed) % count
