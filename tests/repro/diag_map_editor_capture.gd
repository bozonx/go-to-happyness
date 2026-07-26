extends SceneTree

## Captures a screenshot of the map editor HUD to user://map_editor_hud.png.
## Diagnostic only: run with a display server, not --headless.

const EDITOR := "res://game/features/world/presentation/editor/map_editor.tscn"


func _initialize() -> void:
	var editor: Node = load(EDITOR).instantiate()
	root.add_child(editor)
	_capture(editor)


func _capture(editor: Node) -> void:
	await _settle()
	_save("map_editor_hud")
	editor.call("_select_mode", &"surface")
	await _settle()
	_save("map_editor_hud_surface")
	quit(0)


func _settle() -> void:
	for i in 5:
		await process_frame


func _save(name: String) -> void:
	var path := "user://%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved to ", ProjectSettings.globalize_path(path))
