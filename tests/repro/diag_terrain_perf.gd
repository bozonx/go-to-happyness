extends SceneTree

## Print-only terrain performance probe: meshing, cascade and grass costs on the
## real board presets. Not a test — no asserts, only numbers.

func _init() -> void:
	for board in [128, 256]:
		_measure_board(board)
	_measure_cascade()
	_measure_height_query()
	quit(0)


func _measure_board(board: int) -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, board, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	# Rough hills so the mesher does real work rather than one greedy quad.
	var noise := FastNoiseLite.new()
	noise.seed = 12345
	noise.frequency = 0.03
	var minimum := grid.min_cell()
	var maximum := grid.max_cell()
	for z in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var h := int(round(noise.get_noise_2d(float(x), float(z)) * 8.0))
			grid.set_height(Vector2i(x, z), h)
	var chunks := grid.chunk_coords()
	var start := Time.get_ticks_usec()
	var vertices := 0
	var faces := 0
	for chunk: Vector2i in chunks:
		# As the game and the map editor actually configure it: every smoothing
		# treatment off, so the mesh carries no data the shader will not read.
		var result := TerrainChunkMesher.build_chunk(grid, chunk, TerrainChunkMesher.Lod.FULL, false)
		var mesh: ArrayMesh = result["mesh"]
		if mesh != null:
			for surface in mesh.get_surface_count():
				vertices += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		faces += (result["faces"] as PackedVector3Array).size() / 3
	var elapsed := Time.get_ticks_usec() - start
	print("board %d: %d chunks, mesh %.1f ms total, %.2f ms/chunk, %d verts, %d collision tris" % [
		board, chunks.size(), elapsed / 1000.0, elapsed / 1000.0 / float(chunks.size()), vertices, faces,
	])

	# Flat board for comparison — the greedy path.
	var flat := TerrainGrid.new()
	flat.configure(1.0, board, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	start = Time.get_ticks_usec()
	for chunk: Vector2i in flat.chunk_coords():
		TerrainChunkMesher.build_chunk(flat, chunk, TerrainChunkMesher.Lod.FULL, false)
	print("board %d flat: mesh %.1f ms total" % [board, (Time.get_ticks_usec() - start) / 1000.0])

	# Grass on the hilly board.
	var grass := TerrainMediumGrass.new()
	start = Time.get_ticks_usec()
	var instances := 0
	for chunk: Vector2i in chunks:
		instances += grass.build_chunk(grid, chunk).instance_count
	print("board %d grass: %.1f ms total, %d instances" % [
		board, (Time.get_ticks_usec() - start) / 1000.0, instances,
	])


func _measure_cascade() -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 256, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	for size: int in [1, 4, 8]:
		var cells: Array[Vector2i] = []
		var radius: int = size - 1
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				cells.append(Vector2i(x, z))
		var start := Time.get_ticks_usec()
		var delta := CascadeSolver.solve_operation(grid, TerrainEditOperation.offset(cells, 4, TerrainEditOperation.Mode.SCULPT))
		var elapsed := Time.get_ticks_usec() - start
		print("cascade brush %d (+4): %.2f ms, delta %d cells" % [
			size, elapsed / 1000.0, 0 if delta == null else delta.size(),
		])
		if delta != null:
			delta.apply(grid)
			delta.revert(grid)


func _measure_height_query() -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 128, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	grid.place_ramp(Vector2i(0, 0), &"moderate", SlopeCatalog.DIR_E)
	var start := Time.get_ticks_usec()
	for index in 100000:
		grid.height_at(Vector3(float(index % 60) + 0.3, 0.0, 0.7))
	print("height_at: %.2f us/call (100k calls)" % [(Time.get_ticks_usec() - start) / 100000.0])
