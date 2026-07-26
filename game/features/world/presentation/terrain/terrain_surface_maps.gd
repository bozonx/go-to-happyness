class_name TerrainSurfaceMaps
extends RefCounted

## The two maps that carry the surface to the GPU
## (design_docs/engine/terrain_materials.md §7.3).
##
## | Map | Format | Content |
## | :-- | :-- | :-- |
## | index | `R8`, nearest | material index of the column |
## | detail | `RGBA8` | variant, wear, snow depth, (reserved: moisture) |
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

var _index_image: Image = null
var _detail_image: Image = null
var _index_texture: ImageTexture = null
var _detail_texture: ImageTexture = null
var _board_cells := 0
var _half_cells := 0


func configure(board_cells: int) -> void:
	_board_cells = maxi(board_cells, 1)
	_half_cells = _board_cells / 2
	_index_image = Image.create_empty(_board_cells, _board_cells, false, Image.FORMAT_R8)
	_detail_image = Image.create_empty(_board_cells, _board_cells, false, Image.FORMAT_RGBA8)
	_index_texture = ImageTexture.create_from_image(_index_image)
	_detail_texture = ImageTexture.create_from_image(_detail_image)


func is_configured() -> bool:
	return _index_texture != null


func board_cells() -> int:
	return _board_cells


func index_texture() -> ImageTexture:
	return _index_texture


func detail_texture() -> ImageTexture:
	return _detail_texture


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
	_upload()


## Updates exactly the columns the grid reported dirty. The upload is the whole
## (tiny) texture rather than a sub-rect: at 96² the transfer is cheaper than the
## bookkeeping needed to describe the region.
func update_cells(grid: TerrainGrid, cells: Array[Vector2i]) -> void:
	if grid == null or cells.is_empty() or not is_configured():
		return
	for cell: Vector2i in cells:
		_write_cell(grid, cell)
	_upload()


## Drains whatever the grid has pending. `GridTerrainWorld` calls this every
## frame; it costs one dictionary check when nothing was painted.
func sync(grid: TerrainGrid) -> void:
	if grid == null or not grid.has_dirty_surface_cells():
		return
	update_cells(grid, grid.take_dirty_surface_cells())


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
	_index_image.set_pixel(x, y, Color(float(material_index) / 255.0, 0.0, 0.0, 1.0))
	var detail := grid.detail_at(cell)
	_detail_image.set_pixel(x, y, Color(
		float(TerrainDetailCodec.variant_of(detail)) / 15.0,
		float(TerrainDetailCodec.wear_of(detail)) / float(TerrainDetailCodec.MAX_WEAR),
		float(TerrainDetailCodec.snow_depth_of(detail)) / float(TerrainDetailCodec.MAX_SNOW_DEPTH),
		0.0,
	))


func _upload() -> void:
	_index_texture.update(_index_image)
	_detail_texture.update(_detail_image)
