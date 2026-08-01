extends SceneTree

## Attributes the per-chunk mesh cost to its phases, on a flat chunk (the cheapest
## possible geometry) and a hilly one.

func _init() -> void:
	_breakdown("flat", false)
	_breakdown("hilly", true)
	_isolate_corner_heights()
	quit(0)


func _breakdown(label: String, hilly: bool) -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 128, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	if hilly:
		var noise := FastNoiseLite.new()
		noise.seed = 12345
		noise.frequency = 0.03
		for z in range(grid.min_cell().y, grid.max_cell().y + 1):
			for x in range(grid.min_cell().x, grid.max_cell().x + 1):
				grid.set_height(Vector2i(x, z), int(round(noise.get_noise_2d(float(x), float(z)) * 8.0)))

	var passes := 40
	var chunk := Vector2i(0, 0)

	# Whole build, for reference.
	var start := Time.get_ticks_usec()
	for _index in passes:
		TerrainChunkMesher.build_chunk(grid, chunk, TerrainChunkMesher.Lod.FULL)
	var whole := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	# Corner-height cache alone: the 18x18 padded region.
	start = Time.get_ticks_usec()
	var scratch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for _index in passes:
		for padded_z in 18:
			for padded_x in 18:
				grid.corner_heights_into(Vector2i(padded_x - 1, padded_z - 1), scratch)
	var cache := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	# Collision face soup alone.
	var result := TerrainChunkMesher.build_chunk(grid, chunk, TerrainChunkMesher.Lod.FULL)
	var mesh: ArrayMesh = result["mesh"]
	var quads := 0
	if mesh != null:
		for surface in mesh.get_surface_count():
			quads += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 4

	# ArrayMesh construction alone: rebuild surfaces from the arrays we already have.
	start = Time.get_ticks_usec()
	for _index in passes:
		var copy := ArrayMesh.new()
		if mesh != null:
			for surface in mesh.get_surface_count():
				copy.add_surface_from_arrays(
					Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface),
					[], {}, mesh.surface_get_format(surface) & (
						Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1
						| Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3
					)
				)
	var array_mesh := float(Time.get_ticks_usec() - start) / float(passes) / 1000.0

	print("%s chunk: whole %.2f ms | corner cache %.2f ms | ArrayMesh+arrays %.2f ms | %d quads" % [
		label, whole, cache, array_mesh, quads,
	])


func _isolate_corner_heights() -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 128, 0, TerrainMaterialCatalog.DEFAULT_MATERIAL)
	var scratch := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var passes := 200000
	var start := Time.get_ticks_usec()
	for _index in passes:
		grid.corner_heights_into(Vector2i(3, 3), scratch)
	print("corner_heights_into (flat, early-out): %.3f us/call" % [
		float(Time.get_ticks_usec() - start) / float(passes),
	])
	grid.place_ramp(Vector2i(10, 10), &"moderate", SlopeCatalog.DIR_E)
	start = Time.get_ticks_usec()
	for _index in passes:
		grid.corner_heights_into(Vector2i(10, 10), scratch)
	print("corner_heights_into (on a ramp, full scan): %.3f us/call" % [
		float(Time.get_ticks_usec() - start) / float(passes),
	])
	start = Time.get_ticks_usec()
	for _index in passes:
		grid.height_of(Vector2i(3, 3))
	print("height_of: %.3f us/call" % [float(Time.get_ticks_usec() - start) / float(passes)])
