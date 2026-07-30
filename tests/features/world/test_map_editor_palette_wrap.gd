extends SceneTree

## The grass palette has eight variants. At the authored 240 px panel width they
## must form several rows instead of widening or clipping the editor sidebar.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var palette := load("res://game/features/world/presentation/editor/ui/map_editor_palette.tscn").instantiate() as MapEditorPalette
	get_root().add_child(palette)
	palette.size = Vector2(240.0, 480.0)
	var options: Array = []
	for variant in TerrainMaterialVariants.variants_of(TerrainMaterialCatalog.DEFAULT_INDEX):
		options.append(MapEditorMode.ToolOption.of(StringName("variant_%s" % variant), String(variant), &"variants"))
	palette.set_options(options)
	await process_frame
	await process_frame

	var flows := palette.find_children("*", "HFlowContainer", true, false)
	assert(flows.size() == 1, "variant options use one wrapping flow row")
	var flow := flows[0] as HFlowContainer
	var row_positions: Dictionary = {}
	for button: Control in flow.get_children():
		row_positions[roundi(button.position.y)] = true
	assert(row_positions.size() >= 2, "eight grass variants wrap onto another line")
	assert(flow.size.x <= 220.0, "flow stays inside the palette's content width")
	print("[PASS] Map editor palette wraps grass variants")
	quit(0)
