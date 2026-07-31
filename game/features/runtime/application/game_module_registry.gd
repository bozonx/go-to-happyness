class_name GameModuleRegistry
extends RefCounted

## The set of built-in modules a pack may select. One table is the whole
## registry: adding a module is one entry, and no other host code enumerates
## module ids.

static var _factories: Dictionary = {
	&"core.world": func() -> GameModule: return CoreWorldModule.new(),
	&"gth.settlement": func() -> GameModule: return SettlementGameModule.new(),
	&"gth.world_showcase": func() -> GameModule: return WorldShowcaseModule.new(),
}


static func module_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for module_id: StringName in _factories:
		ids.append(module_id)
	ids.sort()
	return ids


static func has_module(module_id: StringName) -> bool:
	return _factories.has(module_id)


static func create_module(module_id: StringName) -> GameModule:
	if not _factories.has(module_id):
		push_error("GameModuleRegistry: unknown module: %s" % module_id)
		return null
	var factory: Callable = _factories[module_id]
	return factory.call() as GameModule


## Parameters a module accepts, without starting a session. The launch screen and
## the game editor ask for this before any module instance exists.
static func start_parameters_of(module_id: StringName) -> Array[StartParameterDef]:
	var module := create_module(module_id)
	return module.start_parameters() if module != null else []


static func resolve_definition(definition_key: StringName) -> GameDefinition:
	var entry := ContentIndex.shared().get_entry(definition_key)
	if entry == null or entry.content_type != &"game":
		push_error("GameModuleRegistry: unknown game definition: %s" % definition_key)
		return null
	var definition := GameDefinition.load_from_file(entry.path)
	if definition != null:
		definition.runtime_key = entry.runtime_key
	return definition


static func validate_definition(definition: GameDefinition) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		errors.append("описание игры отсутствует")
		return errors
	if definition.default_map.is_empty():
		errors.append("не задана стартовая карта")
	if definition.module_ids.is_empty():
		errors.append("не задан ни один модуль")
	if not HostInputProfile.is_supported(definition.input_profile):
		errors.append("неподдерживаемый профиль управления %s" % definition.input_profile)
	for module_id: StringName in definition.module_ids:
		if not has_module(module_id):
			errors.append("неизвестный модуль %s" % module_id)
	errors.append_array(_validate_progression(definition))
	errors.append_array(_validate_menu_parameters(definition))
	return errors


## Eras are host functionality, so the host validates the catalogue itself: a
## dangling `next` would otherwise only surface as a dead end mid-game.
static func _validate_progression(definition: GameDefinition) -> Array[String]:
	var errors: Array[String] = []
	var seen_eras: Dictionary = {}
	for era: EraDefinition in definition.progression.eras:
		if seen_eras.has(era.id):
			errors.append("дубликат эры %s" % era.id)
		seen_eras[era.id] = true
		for next_era: StringName in era.next_eras:
			if definition.progression.era_by_id(next_era) == null:
				errors.append("эра %s ссылается на неизвестную следующую эру %s" % [era.id, next_era])
	return errors


## A menu parameter that names nothing is a blank control at launch time, so it
## is an authoring error here rather than a surprise on the start screen.
static func _validate_menu_parameters(definition: GameDefinition) -> Array[String]:
	var errors: Array[String] = []
	for entry: Dictionary in definition.menu_parameters:
		var kind := StringName(entry.get("type", ""))
		if kind == GameDefinition.MENU_PARAMETER_ERA:
			if definition.progression.eras.is_empty():
				errors.append("параметр меню «эра» требует объявленных эр")
			continue
		var module_id := StringName(entry.get("module", ""))
		var parameter_id := StringName(entry.get("id", ""))
		if not has_module(module_id) or module_id not in definition.module_ids:
			errors.append("параметр меню ссылается на модуль %s вне игры" % module_id)
			continue
		if StartParameterDef.find(start_parameters_of(module_id), parameter_id) == null:
			errors.append("модуль %s не объявляет параметр %s" % [module_id, parameter_id])
	return errors
