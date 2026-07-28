class_name GameModuleRegistry
extends RefCounted

static func resolve_definition(definition_key: StringName) -> GameDefinition:
	var content_index := ContentIndex.new()
	content_index.rebuild()
	var entry := content_index.get_entry(definition_key)
	if entry == null or entry.content_type != &"game":
		push_error("GameModuleRegistry: unknown game definition: %s" % definition_key)
		return null
	return GameDefinition.load_from_file(entry.path)


static func create_module(module_id: StringName) -> GameModule:
	if module_id == &"gth.settlement":
		return SettlementGameModule.new()
	push_error("GameModuleRegistry: unknown module: %s" % module_id)
	return null
