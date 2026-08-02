extends SceneTree

## Bakes the terrain normal maps (design_docs/engine/terrain_materials.md §7.1).
##
## Every authored surface underlay and cliff face carries its height map in the
## alpha channel. The normal map is a pure function of that height, so it is
## CONTENT, not a load-time computation: deriving all 45 layers at runtime was a
## GDScript loop over 11.8 million texels, measured at 4.8 seconds in the middle
## of loading a map.
##
## Run it after adding or redrawing a surface texture:
##
## ```sh
## godot --headless --script tools/bake_terrain_normals.gd
## godot --headless --import          # let the editor import the new PNGs
## ```
##
## Output is `<name>_n.png` beside each source, at `NORMAL_TEXTURE_SIZE`.
## `TerrainMaterialLibrary` picks them up by name; a source with no baked normal
## simply gets a flat one, so an interrupted bake degrades instead of breaking.

const SIZE := TerrainMaterialLibrary.NORMAL_TEXTURE_SIZE


func _init() -> void:
	var baked := 0
	var skipped := 0
	for path in _source_paths():
		var texture := load(path) as Texture2D
		if texture == null:
			push_warning("[bake] не удалось загрузить %s" % path)
			skipped += 1
			continue
		var normal := TerrainMaterialLibrary.normal_from_height(texture.get_image(), SIZE)
		var target := TerrainMaterialLibrary.normal_path_of(path)
		var error := normal.save_png(ProjectSettings.globalize_path(target))
		if error != OK:
			push_error("[bake] не удалось записать %s (%d)" % [target, error])
			skipped += 1
			continue
		baked += 1
		print("  %s" % target.get_file())
	print("[bake] нормалей записано: %d, пропущено: %d, размер %d²" % [baked, skipped, SIZE])
	quit(1 if skipped > 0 else 0)


## Exactly the layers `TerrainMaterialLibrary` will look for, in layout order, so
## the bake cannot miss a style the array is going to sample.
func _source_paths() -> Array[String]:
	var paths: Array[String] = []
	for material_index in TerrainMaterialCatalog.MATERIAL_COUNT:
		for style in TerrainMaterialVariants.surface_style_count(material_index):
			var path := TerrainMaterialLibrary.authored_surface_path(material_index, style)
			if path != "":
				paths.append(path)
	for cliff_index in TerrainMaterialCatalog.cliff_count():
		var cliff_path := TerrainMaterialLibrary.authored_cliff_path(cliff_index)
		if cliff_path != "":
			paths.append(cliff_path)
	return paths
