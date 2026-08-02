class_name GameSessionConfig
extends RefCounted

## One launch request. Game-specific values live inside module_parameters; this
## record deliberately does not know citizens, resources, or professions.
##
## Progression is the exception, and on purpose: eras are host functionality that
## packs opt into with data, so the session resolves them once — game catalogue,
## map policy, player choice — and every module reads the same answer.

var definition: GameDefinition = null
var map_ref: StringName = &""
var map_document: MapDocument = null
var seed := 0
## Editor test run only: where the starting party appears, in world space,
## overriding the map's authored spawn points (`map_editor.md` §12). It is a
## property of **this launch**, never of the map — an author checking a far
## corner must not have to drag `core:hero_start` there and remember to drag it
## back, and nothing about the document changes when they do it.
var spawn_override := Vector3.INF
var module_parameters: Dictionary = {}
var progression: SessionProgression = SessionProgression.new()


static func create(
	p_definition: GameDefinition,
	p_map_ref: StringName,
	p_map_document: MapDocument,
	p_module_parameters: Dictionary = {},
	p_selected_era: StringName = &"",
) -> GameSessionConfig:
	var session := GameSessionConfig.new()
	session.definition = p_definition
	session.map_ref = p_map_ref
	session.map_document = p_map_document
	session.module_parameters = _default_module_parameters(p_definition)
	if p_map_document != null:
		_merge_module_parameters(session.module_parameters, p_map_document.meta.start.module_settings)
	for module_id: Variant in p_module_parameters:
		_merge_module_parameter(session.module_parameters, module_id, p_module_parameters[module_id])
	session.progression = SessionProgression.resolve(
		p_definition.progression if p_definition != null else null,
		map_policy(p_map_document),
		p_selected_era,
	)
	return session


func has_spawn_override() -> bool:
	return spawn_override != Vector3.INF


## The map's progression policy, or the neutral default when there is no map.
static func map_policy(map_document: MapDocument) -> ProgressionPolicy:
	return map_document.meta.start.progression if map_document != null else ProgressionPolicy.new()


func parameters_for(module_id: StringName) -> Dictionary:
	var value: Variant = module_parameters.get(module_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _default_module_parameters(definition: GameDefinition) -> Dictionary:
	return definition.start_module_parameters.duplicate(true) if definition != null else {}


static func _merge_module_parameters(target: Dictionary, supplied: Dictionary) -> void:
	for module_id: Variant in supplied:
		_merge_module_parameter(target, module_id, supplied[module_id])


static func _merge_module_parameter(target: Dictionary, module_id: Variant, supplied: Variant) -> void:
	if supplied is Dictionary and target.get(module_id, {}) is Dictionary:
		var merged: Dictionary = (target.get(module_id, {}) as Dictionary).duplicate(true)
		_merge_dictionary(merged, supplied as Dictionary)
		target[module_id] = merged
	else:
		target[module_id] = supplied.duplicate(true) if supplied is Dictionary else supplied


static func _merge_dictionary(target: Dictionary, supplied: Dictionary) -> void:
	for key: Variant in supplied:
		var value: Variant = supplied[key]
		if value is Dictionary and target.get(key, {}) is Dictionary:
			var nested: Dictionary = (target.get(key, {}) as Dictionary).duplicate(true)
			_merge_dictionary(nested, value as Dictionary)
			target[key] = nested
		else:
			target[key] = value.duplicate(true) if value is Dictionary else value
