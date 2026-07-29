class_name SessionSaveCoordinator
extends RefCounted

## Host-owned save envelope for every running game. Modules contribute their
## sections through GameModule; scene nodes are never a save API.

const QUICKSAVE_PATH := "user://saves/quicksave.json"


static func has_quicksave() -> bool:
	return FileAccess.file_exists(QUICKSAVE_PATH)


static func save_quicksave(runtime: GameRuntime) -> bool:
	if runtime == null or runtime.active_session == null:
		push_error("[save] no active game session")
		return false
	var session := runtime.active_session
	var definition := session.definition
	if definition == null:
		push_error("[save] session has no game definition")
		return false
	var save_data := SaveData.new()
	var game_address := ContentId.split_runtime_key(_definition_key(definition))
	save_data.game_header = {
		"pack": String(game_address["source"]),
		"id": String(definition.id),
		"revision": "",
	}
	save_data.map_header = _map_header(session)
	save_data.engine_state = {"clock": {}}
	for module_id: StringName in runtime.active_modules:
		var module: GameModule = runtime.active_modules[module_id]
		var state := module.save_state(runtime)
		if not state.is_empty():
			save_data.module_states[module_id] = state.duplicate(true)
	return save_data.save_to_file(QUICKSAVE_PATH)


static func load_pending(runtime: GameRuntime, path: String) -> bool:
	if runtime == null or path.is_empty():
		return false
	var save_data := SaveData.new()
	if not save_data.load_from_file(path):
		return false
	if not _matches_active_definition(save_data, runtime.active_session):
		push_warning("[save] выбранное сохранение принадлежит другой игре")
		return false
	for module_id: StringName in save_data.module_states:
		if not runtime.active_modules.has(module_id):
			push_warning("[save] сохранение требует отсутствующий модуль: %s" % module_id)
			return false
	for module_id: StringName in runtime.active_modules:
		if not save_data.module_states.has(module_id):
			continue
		var module: GameModule = runtime.active_modules[module_id]
		var state: Variant = save_data.module_states[module_id]
		if not state is Dictionary or not module.restore_state(runtime, state as Dictionary):
			push_warning("[save] модуль не восстановил свою секцию: %s" % module_id)
			return false
	return true


static func _map_header(session: GameSessionConfig) -> Dictionary:
	var address := ContentId.split_runtime_key(session.map_ref)
	var header := {"source": String(address["source"]), "id": String(address["id"])}
	if session.map_document != null:
		header["revision"] = session.map_document.meta.revision
	return header


static func _definition_key(definition: GameDefinition) -> StringName:
	if definition != null and not definition.runtime_key.is_empty():
		return definition.runtime_key
	return ContentId.runtime_key(definition.pack_id, definition.id) if definition != null else &""


static func _matches_active_definition(save_data: SaveData, session: GameSessionConfig) -> bool:
	if save_data == null or session == null or session.definition == null:
		return false
	var address := ContentId.split_runtime_key(_definition_key(session.definition))
	return StringName(save_data.game_header.get("pack", "")) == address["source"] \
		and StringName(save_data.game_header.get("id", "")) == session.definition.id
