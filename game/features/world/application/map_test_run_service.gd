class_name MapTestRunService
extends RefCounted

## Read-only preflight for an editor test run. The editor owns buttons and scene
## changes; this service owns the rule that an unsaved map must be launchable
## before handing it to the host runtime.

func validate(document: MapDocument, nav_grid: NavGrid) -> Dictionary:
	var result := {"errors": [], "warnings": []}
	if document == null:
		result["errors"] = ["карта отсутствует"]
		return result
	result["errors"] = MapValidator.validate(
		document, document.terrain, document.water, nav_grid,
	)
	result["warnings"] = MapValidator.warnings(document, nav_grid)
	return result


## Runs every game module's `validate_session` against the document without
## changing scenes. This mirrors what `SessionBootstrapper.run` will check, so a
## map that fails here (no `core:hero_start` for a settlement, bad progression)
## is reported in the editor status bar instead of leaving the author on a black
## screen after the launch. The bootstrapper still validates at start — this is
## a read-only preflight, not a bypass of its invariant.
func validate_session(document: MapDocument, definition_key: StringName) -> Array[String]:
	if document == null:
		return ["карта отсутствует"]
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		return ["игра %s не установлена" % definition_key]
	var session := GameSessionConfig.create(definition, &"editor:preview", document)
	var errors: Array[String] = []
	for module_id: StringName in definition.module_ids:
		var module := GameModuleRegistry.create_module(module_id)
		if module == null:
			errors.append("неизвестный модуль %s" % module_id)
			continue
		errors.append_array(module.validate_session(session))
	return errors
