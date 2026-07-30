extends SceneTree

const MainMenuScene := preload("res://game/features/ui/presentation/main_menu/main_menu.tscn")
const EditorHubScene := preload("res://game/features/content/presentation/editor/editor_hub.tscn")
const GameEditorScene := preload("res://game/features/runtime/presentation/editor/game_editor.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var launch_manager := root.get_node("GameLaunchManager") as RuntimeLaunchManager

	var menu := MainMenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	assert(menu.game_option.item_count > 0)
	assert(menu.editor_btn.visible and not menu.editor_btn.disabled)
	menu.queue_free()
	await process_frame

	launch_manager.editor_mode_forced = true
	launch_manager.editor_dev_mode = true
	var hub := EditorHubScene.instantiate()
	root.add_child(hub)
	await process_frame
	assert(not hub.projects.is_empty(), "dev Editor Hub must expose the core pack")
	assert(not hub.game_button.disabled and not hub.map_button.disabled and not hub.building_button.disabled)
	hub.queue_free()
	await process_frame

	launch_manager.select_editor_pack("res://game/content/core", &"core")
	var game_editor := GameEditorScene.instantiate()
	root.add_child(game_editor)
	await process_frame
	assert(game_editor.pack != null and game_editor.pack.id == &"core")
	assert(game_editor.definition != null)
	assert(game_editor.era_list.item_count == game_editor.definition.progression.eras.size())
	assert(not game_editor.technologies_edit.text.is_empty())
	game_editor.queue_free()
	await process_frame

	launch_manager.editor_mode_forced = false
	launch_manager.active_editor_pack_root = ""
	launch_manager.active_editor_pack_source = &""
	quit(0)
