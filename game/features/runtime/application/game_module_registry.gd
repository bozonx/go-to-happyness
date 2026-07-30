class_name GameModuleRegistry
extends RefCounted

static func resolve_definition(definition_key: StringName) -> GameDefinition:
	var content_index := ContentIndex.new()
	content_index.rebuild()
	var entry := content_index.get_entry(definition_key)
	if entry == null or entry.content_type != &"game":
		push_error("GameModuleRegistry: unknown game definition: %s" % definition_key)
		return null
	var definition := GameDefinition.load_from_file(entry.path)
	if definition != null:
		definition.runtime_key = entry.runtime_key
	return definition


static func create_module(module_id: StringName) -> GameModule:
	if module_id == &"core.world":
		return CoreWorldModule.new()
	if module_id == &"gth.settlement":
		return SettlementGameModule.new()
	if module_id == &"gth.world_showcase":
		return WorldShowcaseModule.new()
	push_error("GameModuleRegistry: unknown module: %s" % module_id)
	return null


static func has_module(module_id: StringName) -> bool:
	return module_id in [&"core.world", &"gth.settlement", &"gth.world_showcase"]


static func validate_definition(definition: GameDefinition) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		errors.append("описание игры отсутствует")
		return errors
	if definition.default_map.is_empty():
		errors.append("не задана стартовая карта")
	if definition.module_ids.is_empty():
		errors.append("не задан ни один модуль")
	for module_id: StringName in definition.module_ids:
		if not has_module(module_id):
			errors.append("неизвестный модуль %s" % module_id)
	var seen_eras: Dictionary = {}
	for era: EraDefinition in definition.progression.eras:
		if seen_eras.has(era.id):
			errors.append("дубликат эры %s" % era.id)
		seen_eras[era.id] = true
		for next_era: StringName in era.next_eras:
			if definition.progression.era_by_id(next_era) == null:
				errors.append("эра %s ссылается на неизвестную следующую эру %s" % [era.id, next_era])
	return errors
