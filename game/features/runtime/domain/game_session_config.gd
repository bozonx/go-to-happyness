class_name GameSessionConfig
extends RefCounted

## One launch request. Game-specific values live inside module_parameters; this
## record deliberately does not know citizens, resources, or professions.
##
## Its one job that is not storage is running the §2.5 chain exactly once
## (`map_start.md`): module default → game definition → map → start option →
## player. The result is a fact, and `resolution` keeps the chain that produced
## it so both the launch screen and the editor can explain the number instead of
## presenting it.
##
## Progression is the exception to "the host knows no gameplay", and on purpose:
## eras are host functionality that packs opt into with data, so the session
## resolves them once — game catalogue, map policy, player choice — and every
## module reads the same answer.

var definition: GameDefinition = null
var map_ref: StringName = &""
var map_document: MapDocument = null
var seed := 0
## Editor test run only: where the starting party appears, in world space,
## overriding the map's authored spawn points (`map_editor.md` §12). It is a
## property of **this launch**, never of the map — an author checking a far
## corner must not have to drag `core:party_leader` there and remember to drag it
## back, and nothing about the document changes when they do it.
var spawn_override := Vector3.INF
var module_parameters: Dictionary = {}
var progression: SessionProgression = SessionProgression.new()
## The entrance this session begins at (`map_start.md` §3). Recorded in the save,
## because a start option is applied exactly once (§15).
var start_option: StringName = &""
## The chain behind every value in `module_parameters`, for the UI that has to
## explain why a slider stops where it does (§12).
var resolution: StartParameterResolution = StartParameterResolution.new()


static func create(
	p_definition: GameDefinition,
	p_map_ref: StringName,
	p_map_document: MapDocument,
	p_module_parameters: Dictionary = {},
	p_selected_era: StringName = &"",
	p_start_option: StringName = &"",
) -> GameSessionConfig:
	var session := GameSessionConfig.new()
	session.definition = p_definition
	session.map_ref = p_map_ref
	session.map_document = p_map_document
	session.start_option = _resolve_start_option(p_definition, p_map_document, p_start_option)
	var option := selected_option(p_map_document, session.start_option)
	session.resolution = StartParameterResolver.resolve(
		_declared_parameters(p_definition),
		_definition_parameters(p_definition),
		p_map_document.meta.start.module_settings if p_map_document != null else {},
		option.module_overrides if option != null else {},
		p_module_parameters,
	)
	session.module_parameters = session.resolution.values.duplicate(true)
	session.progression = SessionProgression.resolve(
		p_definition.progression if p_definition != null else null,
		map_policy(p_map_document),
		p_selected_era,
	)
	return session


func has_spawn_override() -> bool:
	return spawn_override != Vector3.INF


## The entrance record itself, or null on a map that declares none.
func start_option_record() -> MapStartOption:
	return selected_option(map_document, start_option)


static func selected_option(map_document: MapDocument, option_id: StringName) -> MapStartOption:
	if map_document == null:
		return null
	var option := map_document.meta.start.start_by_id(option_id)
	return option if option != null else map_document.meta.start.default_option(
		map_document.meta.start.game_definition)


## The map's progression policy, or the neutral default when there is no map.
static func map_policy(map_document: MapDocument) -> ProgressionPolicy:
	return map_document.meta.start.progression if map_document != null else ProgressionPolicy.new()


func parameters_for(module_id: StringName) -> Dictionary:
	var value: Variant = module_parameters.get(module_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


## Initial scenario-flag values the chosen entrance declares (§3.1, §7.3 step 9).
func start_flags() -> Dictionary:
	var option := start_option_record()
	return option.flags.duplicate(true) if option != null else {}


## Whether an authored entity belongs to this session's entrance (§3.2).
func includes_entity(entity: MapEntityRecord) -> bool:
	return entity.belongs_to_start(start_option)


## Chooses the entrance: what the player picked, if it exists and suits the game;
## otherwise the map's declared default.
static func _resolve_start_option(
	definition: GameDefinition,
	map_document: MapDocument,
	requested: StringName,
) -> StringName:
	if map_document == null:
		return requested
	var definition_key := definition.runtime_key if definition != null else &""
	var start := map_document.meta.start
	var option := start.start_by_id(requested)
	if option != null and option.suits_definition(definition_key):
		return option.id
	var fallback := start.default_option(definition_key)
	return fallback.id if fallback != null else &""


## Level 1 of the chain: what every module of this game declares.
static func _declared_parameters(definition: GameDefinition) -> Dictionary:
	var declared: Dictionary = {}
	if definition == null:
		return declared
	for module_id: StringName in definition.module_ids:
		declared[module_id] = GameModuleRegistry.start_parameters_of(module_id)
	return declared


## Level 2: what the game definition authored.
static func _definition_parameters(definition: GameDefinition) -> Dictionary:
	return definition.start_module_parameters.duplicate(true) if definition != null else {}
