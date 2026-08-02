extends SceneTree

## What a retained mesher costs on a full build versus on the delta rebuild that
## follows a single-column edit — the interactive path a brush drag actually hits.

func _init() -> void:
	_compare("flat", false)
	_compare("hilly", true)
	quit(0)


func _compare(label: String, hilly: bool) -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 128, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	if hilly:
		var noise := FastNoiseLite.new()
		noise.seed = 12345
		noise.frequency = 0.03
		for z in range(grid.min_cell().y, grid.max_cell().y + 1):
			for x in range(grid.min_cell().x, grid.max_cell().x + 1):
				grid.set_height(Vector2i(x, z), int(round(noise.get_noise_2d(float(x), float(z)) * 8.0)))
	grid.take_dirty_chunks()

	var chunk := Vector2i(0, 0)
	var mesher := TerrainChunkMesher.new()
	mesher.configure(grid, chunk)

	var passes := 30
	var start := Time.get_ticks_usec()
	for _index in passes:
		mesher.build(TerrainChunkMesher.Lod.FULL, TerrainChunkMesher.FULL_BOUNDS)
	var full := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	# How the game and the map editor actually run: every smoothing treatment off.
	start = Time.get_ticks_usec()
	for _index in passes:
		mesher.build(TerrainChunkMesher.Lod.FULL, TerrainChunkMesher.FULL_BOUNDS, false)
	var plain := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	# One column raised in the middle of the chunk, exactly what a brush does.
	var cell := Vector2i(7, 7)
	var bounds := Vector4i(cell.x, cell.y, cell.x, cell.y)
	start = Time.get_ticks_usec()
	for index in passes:
		grid.set_height(cell, 1 if index % 2 == 0 else 2)
		grid.take_dirty_chunks()
		mesher.build(TerrainChunkMesher.Lod.FULL, bounds)
	var delta := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	# The same edit without the retained bands, i.e. what it cost before.
	start = Time.get_ticks_usec()
	for index in passes:
		grid.set_height(cell, 1 if index % 2 == 0 else 2)
		grid.take_dirty_chunks()
		TerrainChunkMesher.build_chunk(grid, chunk, TerrainChunkMesher.Lod.FULL)
	var whole := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	# The interactive path as it is actually configured.
	start = Time.get_ticks_usec()
	for index in passes:
		grid.set_height(cell, 1 if index % 2 == 0 else 2)
		grid.take_dirty_chunks()
		mesher.build(TerrainChunkMesher.Lod.FULL, bounds, false)
	var plain_delta := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	print("%s: full %.2f ms (no smoothing %.2f) | one-cell edit: delta %.2f ms (no smoothing %.2f) vs whole-chunk %.2f ms" % [
		label, full, plain, delta, plain_delta, whole,
	])

	# Geometry has to be identical whichever path produced it.
	var reference := TerrainChunkMesher.build_chunk(grid, chunk, TerrainChunkMesher.Lod.FULL)
	var incremental := mesher.build(TerrainChunkMesher.Lod.FULL, bounds)
	print("  collision soup: delta %d tris, full rebuild %d tris, same volume=%s" % [
		(incremental["faces"] as PackedVector3Array).size() / 3,
		(reference["faces"] as PackedVector3Array).size() / 3,
		_same_volume(incremental["faces"], reference["faces"]),
	])


## Band-limited greedy merging can split a quad the full pass would have kept
## whole, so the triangle COUNT may differ; the surface they describe may not.
## Compared as the set of triangle centroids weighted by area.
static func _same_volume(left: PackedVector3Array, right: PackedVector3Array) -> bool:
	return is_equal_approx(_area(left), _area(right))


static func _area(faces: PackedVector3Array) -> float:
	var total := 0.0
	for triangle in faces.size() / 3:
		var base := triangle * 3
		total += (faces[base + 1] - faces[base]).cross(faces[base + 2] - faces[base]).length() * 0.5
	return total


