extends SceneTree

func _initialize() -> void:
	var scene := load("res://game/features/buildings/presentation/editor/building_editor.tscn")
	var editor = scene.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor._mark_dirty()
	editor._on_load_pressed()
	await process_frame
	print("items: ", editor._load_list.item_count, " meta0=", editor._load_list.get_item_metadata(0))
	editor._on_load_item_activated(0)
	await process_frame
	await process_frame
	for c in editor.get_children():
		if c is ConfirmationDialog:
			print("dialog visible=", c.visible)
			c.confirmed.emit()
			c.hide()
			print("after hide visible=", c.visible)
	for i in 5:
		await process_frame
	print("blueprint after: ", editor.blueprint.name, " blocks=", editor.blueprint.block_count())
	quit(0)
