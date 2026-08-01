extends SceneTree

## Throwaway visual check: does a painted road actually appear on the ground?

func _init() -> void:
	var board := 32
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, board)
	var coverage := CoverageLayer.new()
	coverage.configure(1.0, board)
	var service := CoverageService.new()
	service.configure(coverage, terrain)
	var cells := CoverageRasterizer.stroke(
		[Vector2i(-10, -6), Vector2i(6, -6), Vector2i(6, 8)] as Array[Vector2i], 3, coverage,
	)
	service.paint(cells, CoverageCatalog.index_of_id(CoverageCatalog.STONE))
	var trail := CoverageRasterizer.stroke(
		[Vector2i(-10, 4), Vector2i(8, 4)] as Array[Vector2i], 1, coverage,
	)
	service.paint(trail, CoverageCatalog.index_of_id(CoverageCatalog.TRAIL))

	var world := GridTerrainWorld.new()
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 26.0, 26.0), Vector3.ZERO, Vector3.UP)
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	root.add_child(light)
	world.configure(terrain, camera, coverage)
	world.rebuild_pending_now()

	for _frame in 8:
		await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("user://coverage_check.png")
	print("[capture] wrote user://coverage_check.png")
	quit(0)
