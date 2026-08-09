extends SceneTree

## Prints the minimum size every panel demands, which is what decides whether the
## chrome fits a small window. With a display server it also captures the HUD;
## headless runs deliberately report layout only, so CI diagnostics stay clean.

const EDITOR := "res://game/features/world/presentation/editor/map_editor.tscn"


func _initialize() -> void:
	var editor: Node = load(EDITOR).instantiate()
	root.add_child(editor)
	_capture(editor)


func _capture(editor: Node) -> void:
	await _settle()
	_report(editor, "рельеф")
	_save("map_editor_hud")
	editor.call("_select_mode", &"surface")
	await _settle()
	_report(editor, "поверхность")
	_save("map_editor_hud_surface")
	editor.call("_select_mode", &"scenario")
	await _settle()
	_report(editor, "сценарий")
	_save("map_editor_hud_scenario")
	quit(0)


func _report(editor: Node, label: String) -> void:
	var screen: Control = editor.get_node("UI/Screen")
	print("--- %s (окно %s)" % [label, root.size])
	print("  Screen min ", screen.get_combined_minimum_size(), " pos ", screen.position, " size ", screen.size)
	for path in ["UI/Screen/TopBar", "UI/Screen/TopBar/Margin/Scroll/Row", "UI/Screen/Middle",
			"UI/Screen/Middle/Palette", "UI/Screen/Middle/Workspace", "UI/Screen/Middle/SidePanel", "UI/Screen/StatusBar",
			"UI/Screen/StatusBar/Margin/Row"]:
		var node: Control = editor.get_node(path)
		print("  %-38s min %s" % [path.trim_prefix("UI/Screen/"), node.get_combined_minimum_size()])


func _settle() -> void:
	for i in 5:
		await process_frame


func _save(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("capture skipped in headless mode: ", name)
		return
	var path := "user://%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved to ", ProjectSettings.globalize_path(path))
