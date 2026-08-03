extends SceneTree

## Focused runner for everything terrain-surface (design_docs/engine/terrain_materials.md).
##
## `tests/run_all.gd` is the suite; this one exists so the terrain work can be
## verified while some unrelated corner of the project is mid-refactor and does
## not compile — a broken neighbour must not hide a broken material catalog.

const SCRIPTS: Array[String] = [
	"res://tests/domain/test_domain_terrain.gd",
	"res://tests/domain/test_domain_terrain_materials.gd",
	"res://tests/domain/test_domain_terrain_textures.gd",
	"res://tests/domain/test_domain_terrain_navigation.gd",
	"res://tests/domain/test_terrain_anchors.gd",
	"res://tests/features/world/test_surface_state.gd",
	"res://tests/features/world/test_terrain_meshing.gd",
	"res://tests/features/world/test_terrain_brush.gd",
	"res://tests/features/world/test_coverage_layer.gd",
	"res://tests/features/world/test_map_document.gd",
	"res://tests/domain/test_map_generation.gd",
]


func _init() -> void:
	for path in SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			push_error("не загрузился: %s" % path)
			continue
		script.run_all()
	print("== terrain suites done ==")
	quit()
