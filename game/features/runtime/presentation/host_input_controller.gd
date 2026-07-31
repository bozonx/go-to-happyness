class_name HostInputController
extends RefCounted

## Godot-facing bindings for the standard host commands. Module scenes receive
## input only after these commands have had a chance to handle it, so save and
## return-to-library behave identically in every installed RTS-profile game.

var profile_id: StringName = &""


func configure(p_profile_id: StringName) -> void:
	profile_id = p_profile_id


func handle_unhandled_input(event: InputEvent, runtime: GameRuntime) -> bool:
	if profile_id != HostInputProfile.RTS or not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode == KEY_F5:
		if SessionSaveCoordinator.save_quicksave(runtime):
			print("[save] quicksave written")
		return true
	if key_event.keycode == KEY_ESCAPE:
		var launch_manager := runtime.get_node_or_null("/root/GameLaunchManager")
		if launch_manager == null:
			return false
		# A test run returns to the editor it was started from; anything else
		# returns to the library. The host decides this, not the running game.
		if not String(launch_manager.get("editor_return_scene")).is_empty():
			launch_manager.call("return_from_editor_test")
			return true
		if launch_manager.has_method("return_to_main_menu"):
			launch_manager.call("return_to_main_menu")
			return true
	return false
