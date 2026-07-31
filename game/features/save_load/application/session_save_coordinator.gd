class_name SessionSaveCoordinator
extends RefCounted

## Host-owned save envelope for every running game. Modules contribute their
## sections through GameModule; scene nodes are never a save API.

const QUICKSAVE_SLOT := "quicksave"
const SAVES_DIR := "user://saves"
const QUICKSAVE_PATH := SAVES_DIR + "/" + QUICKSAVE_SLOT + ".json"


static func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return result
	for file_name in DirAccess.get_files_at(SAVES_DIR):
		if not file_name.ends_with(".json"):
			continue
		var path := SAVES_DIR.path_join(file_name)
		var save_data := SaveData.new()
		if not save_data.load_from_file(path):
			continue
		result.append({
			"path": path,
			"file_name": file_name,
			"game_id": String(save_data.game_header.get("id", "")),
			"pack_id": String(save_data.game_header.get("pack", "")),
			"map_id": String(save_data.map_header.get("id", "")),
			"modified": FileAccess.get_modified_time(path),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]))
	return result


static func delete_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


static func has_quicksave() -> bool:
	return FileAccess.file_exists(QUICKSAVE_PATH)


static func save_quicksave(runtime: GameRuntime) -> bool:
	return save_to_slot(runtime, QUICKSAVE_SLOT)


static func save_to_slot(runtime: GameRuntime, slot_name: String) -> bool:
	var save_data := capture(runtime)
	if save_data == null:
		return false
	if DirAccess.make_dir_recursive_absolute(SAVES_DIR) != OK:
		push_error("[save] cannot create saves directory")
		return false
	return save_data.save_to_file(SAVES_DIR.path_join(slot_name + ".json"))


## Builds the envelope for the running session. Returns null when there is
## nothing coherent to write, so callers never persist a half-composed session.
static func capture(runtime: GameRuntime) -> SaveData:
	if runtime == null or runtime.active_session == null:
		push_error("[save] no active game session")
		return null
	var session := runtime.active_session
	var definition := session.definition
	if definition == null:
		push_error("[save] session has no game definition")
		return null
	var save_data := SaveData.new()
	var game_address := ContentId.split_runtime_key(_definition_key(definition))
	save_data.game_header = {
		"pack": String(game_address["source"]),
		"id": String(definition.id),
		"revision": definition.revision,
	}
	save_data.map_header = _map_header(session)
	save_data.engine_state = {"seed": session.seed}
	for module_id: StringName in runtime.active_modules:
		var module: GameModule = runtime.active_modules[module_id]
		var state := module.save_state(runtime)
		if not state.is_empty():
			save_data.set_module_section(module_id, module.section_version(), state)
	return save_data


static func load_pending(runtime: GameRuntime, path: String) -> bool:
	if runtime == null or path.is_empty():
		return false
	var save_data := SaveData.new()
	if not save_data.load_from_file(path):
		return false
	if not _matches_active_definition(save_data, runtime.active_session):
		push_warning("[save] выбранное сохранение принадлежит другой игре")
		return false
	_warn_on_changed_content(save_data, runtime.active_session)
	for module_id: StringName in save_data.module_sections:
		if not runtime.active_modules.has(module_id):
			push_warning("[save] сохранение требует отсутствующий модуль: %s" % module_id)
			return false
	for module_id: StringName in runtime.active_modules:
		if not save_data.module_sections.has(module_id):
			continue
		var module: GameModule = runtime.active_modules[module_id]
		var state := _section_for(save_data, module)
		if state.is_empty() or not module.restore_state(runtime, state):
			push_warning("[save] модуль не восстановил свою секцию: %s" % module_id)
			return false
	return true


## Brings one module's section up to the version that module currently speaks.
## A module that cannot migrate returns nothing, and the load is refused — a
## partially understood section is a broken world, not an old one.
static func _section_for(save_data: SaveData, module: GameModule) -> Dictionary:
	var module_id := module.module_id()
	var saved_version := save_data.module_section_version(module_id)
	var state := save_data.module_section(module_id)
	if saved_version == module.section_version():
		return state
	var migrated := module.migrate_section(saved_version, state)
	if migrated.is_empty():
		push_warning("[save] секция %s версии %d несовместима с текущей версией %d"
			% [module_id, saved_version, module.section_version()])
	return migrated


## Content the save was written against may have been edited since. The map
## already warns; the game definition now does too, because an era removed from
## the catalogue explains a broken load better than the failure it causes.
static func _warn_on_changed_content(save_data: SaveData, session: GameSessionConfig) -> void:
	var saved_game_revision := String(save_data.game_header.get("revision", ""))
	if not saved_game_revision.is_empty() and saved_game_revision != session.definition.revision:
		push_warning("[save] игра %s изменилась после сохранения" % session.definition.id)
	var saved_map_revision := String(save_data.map_header.get("revision", ""))
	if session.map_document != null and not saved_map_revision.is_empty() \
			and saved_map_revision != session.map_document.meta.revision:
		push_warning("[save] карта %s изменилась после сохранения" % session.map_ref)


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
