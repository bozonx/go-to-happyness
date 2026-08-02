class_name TerrainSurfaceMaps
extends RefCounted

## The maps that carry the surface to the GPU
## (design_docs/engine/terrain_materials.md §7.3).
##
## | Map | Format | Content |
## | :-- | :-- | :-- |
## | index | `R8`, nearest | material index of the column |
## | detail | `RGBA8` | variant, wear, snow depth, unused alpha |
## | coverage | `RG8`, nearest | coverage index of the column, and its wear |
##
## The coverage map is a third texel and not a fourth channel of the detail map:
## it belongs to a different layer with a different owner (`CoverageLayer`), and
## painting a road must not have to rewrite the material of the cell under it.
##
## Both are board-sized — 96×96 is 9 KB and 36 KB — and that is the whole reason
## painting a material is not a mesh operation any more: the brush writes one
## texel and the `ArrayMesh`, its collision and the chunk queue are never touched
## (§7.5). The alternative schemes were rejected in the design: RGBA splat weights
## do not scale past four materials, and CPU-computed blend weights have to be
## kept in sync with the mesher on every stroke.
##
## The index map MUST be sampled with nearest filtering: it holds indices, and a
## linearly interpolated index is a different material.

const INDEX_TEXTURE := &"index_map"
const DETAIL_TEXTURE := &"detail_map"
const COVERAGE_TEXTURE := &"coverage_map"

var _index_image: Image = null
var _detail_image: Image = null
var _coverage_image: Image = null
var _index_texture: ImageTexture = null
var _detail_texture: ImageTexture = null
var _coverage_texture: ImageTexture = null
var _board_cells := 0
var _half_cells := 0
var _index_dirty := false
var _detail_dirty := false


func configure(board_cells: int) -> void:
	_board_cells = maxi(board_cells, 1)
	_half_cells = _board_cells / 2
	_index_image = Image.create_empty(_board_cells, _board_cells, false, Image.FORMAT_R8)
	_detail_image = Image.create_empty(_board_cells, _board_cells, false, Image.FORMAT_RGBA8)
	_coverage_image = Image.create_empty(_board_cells, _board_cells, false, Image.FORMAT_RG8)
	_index_texture = ImageTexture.create_from_image(_index_image)
	_detail_texture = ImageTexture.create_from_image(_detail_image)
	_coverage_texture = ImageTexture.create_from_image(_coverage_image)


func is_configured() -> bool:
	return _index_texture != null


func board_cells() -> int:
	return _board_cells


func index_texture() -> ImageTexture:
	return _index_texture


func detail_texture() -> ImageTexture:
	return _detail_texture


func coverage_texture() -> ImageTexture:
	return _coverage_texture


## Writes every column. Used on load and after a board resize; a brush uses
## `update_cells` instead.
func rebuild(grid: TerrainGrid) -> void:
	if grid == null:
		return
	if _board_cells != grid.board_cells or not is_configured():
		configure(grid.board_cells)
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_write_cell(grid, Vector2i(x, z))
	# A full publish uploads unconditionally: the images were just created empty,
	# so a column that happens to match the cleared texel still has to reach the GPU.
	_index_dirty = true
	_detail_dirty = true
	_upload()


## Updates exactly the columns the grid reported dirty, then re-uploads only the
## maps whose texels actually moved. A material stroke and a wear pass write
## different images, and the board is up to 512² — a full `RGBA8` upload of that
## is a megabyte, which is not something to spend on a frame that repainted
## nothing in it.
func update_cells(grid: TerrainGrid, cells: Array[Vector2i]) -> void:
	if grid == null or cells.is_empty() or not is_configured():
		return
	_index_dirty = false
	_detail_dirty = false
	for cell: Vector2i in cells:
		_write_cell(grid, cell)
	_upload()


func _write_cell(grid: TerrainGrid, cell: Vector2i) -> void:
	if not grid.is_inside(cell):
		return
	var x := cell.x + _half_cells
	var y := cell.y + _half_cells
	if x < 0 or y < 0 or x >= _board_cells or y >= _board_cells:
		return
	var material_index := grid.material_index_at(cell)
	# R8 stores the index as a byte; the shader multiplies by 255 and rounds. The
	# variant travels in the detail map instead of being folded in here, so a
	# material repaint and a variant repaint stay independent texel writes.
	var index_texel := Color(float(material_index) / 255.0, 0.0, 0.0, 1.0)
	if _index_image.get_pixel(x, y) != index_texel:
		_index_image.set_pixel(x, y, index_texel)
		_index_dirty = true
	var detail := grid.detail_at(cell)
	var detail_texel := Color(
		float(TerrainDetailCodec.variant_of(detail)) / 15.0,
		float(TerrainDetailCodec.wear_of(detail)) / float(TerrainDetailCodec.MAX_WEAR),
		float(TerrainDetailCodec.snow_depth_of(detail)) / float(TerrainDetailCodec.MAX_SNOW_DEPTH),
		0.0,
	)
	if _detail_image.get_pixel(x, y) != detail_texel:
		_detail_image.set_pixel(x, y, detail_texel)
		_detail_dirty = true


## Rewrites the coverage texel of every column. Separate from `rebuild` because
## the two layers have separate owners and separate dirty sets: a material stroke
## must not repaint coverage, and a road stroke must not touch the ground.
func rebuild_coverage(layer: CoverageLayer) -> void:
	if layer == null or not is_configured():
		return
	var minimum := layer.min_cell()
	var maximum := layer.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_write_coverage_cell(layer, Vector2i(x, z))
	_upload_coverage()


func update_coverage_cells(layer: CoverageLayer, cells: Array[Vector2i]) -> void:
	if layer == null or cells.is_empty() or not is_configured():
		return
	for cell: Vector2i in cells:
		_write_coverage_cell(layer, cell)
	_upload_coverage()


func sync_coverage(layer: CoverageLayer) -> void:
	if layer == null or not layer.has_dirty_cells():
		return
	update_coverage_cells(layer, layer.take_dirty_cells())


func _write_coverage_cell(layer: CoverageLayer, cell: Vector2i) -> void:
	if not layer.is_inside(cell):
		return
	var x := cell.x + _half_cells
	var y := cell.y + _half_cells
	if x < 0 or y < 0 or x >= _board_cells or y >= _board_cells:
		return
	# Red is the catalog index, read back with the same `* 255 + 0.5` rounding the
	# material index uses. Green is the coverage's own wear, which is why the layer
	# reuses `TerrainDetailCodec` instead of inventing road flags.
	_coverage_image.set_pixel(x, y, Color(
		float(layer.index_at(cell)) / 255.0,
		float(layer.wear_at(cell)) / float(TerrainDetailCodec.MAX_WEAR),
		0.0,
		1.0,
	))


func _upload() -> void:
	if _index_dirty:
		_index_texture.update(_index_image)
		_index_dirty = false
	if _detail_dirty:
		_detail_texture.update(_detail_image)
		_detail_dirty = false


func _upload_coverage() -> void:
	_coverage_texture.update(_coverage_image)
