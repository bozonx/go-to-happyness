class_name MapTestRunService
extends RefCounted

## Read-only preflight for an editor test run. The editor owns buttons and scene
## changes; this service owns the rule that an unsaved map must be launchable
## before handing it to the host runtime.
##
## It runs **everything the save path runs**, and that is the point. While the
## check button skipped `MapZoneLayer.validate`, a duplicate zone id reported
## "карта проверена: ошибок нет", launched happily, and then refused to save —
## the author found out about it at the one moment they had nothing to do about
## it. One set of rules, three entry points: check, F5, save.

func validate(document: MapDocument, nav_grid: NavGrid) -> Dictionary:
	var result := {"errors": [], "warnings": []}
	if document == null:
		result["errors"] = ["карта отсутствует"]
		return result
	var errors: Array[String] = document.zones.validate(document.board_cells())
	errors.append_array(MapValidator.validate(
		document, document.terrain, document.water, nav_grid,
	))
	var warnings: Array[String] = document.zones.warnings(document.board_cells())
	warnings.append_array(MapValidator.warnings(document, nav_grid))
	result["errors"] = errors
	result["warnings"] = warnings
	return result


## Runs every game module's `validate_session` against the document without
## changing scenes. This mirrors what `SessionBootstrapper.run` will check, so a
## map that fails here (a start option whose clearing cannot hold the party, bad
## progression) is reported in the editor status bar instead of leaving the
## author on a black screen after the launch. The bootstrapper still validates at
## start — this is a read-only preflight, not a bypass of its invariant.
##
## `spawn_override` marks the editor's "test from here" run: it brings its own
## party start, so a module must not refuse the launch for want of authored
## spawn anchors.
func validate_session(
	document: MapDocument,
	definition_key: StringName,
	spawn_override := false,
	start_option: StringName = &"",
) -> Array[String]:
	if document == null:
		return ["карта отсутствует"]
	var definition := GameModuleRegistry.resolve_definition(definition_key)
	if definition == null:
		return ["игра %s не установлена" % definition_key]
	var session := GameSessionConfig.create(
		definition, &"editor:preview", document, {}, &"", start_option)
	if spawn_override:
		# Any finite position marks the launch as overridden; the actual cell is
		# the editor's business and does not change what a module may refuse.
		session.spawn_override = Vector3.ZERO
	var errors: Array[String] = []
	for module_id: StringName in definition.module_ids:
		var module := GameModuleRegistry.create_module(module_id)
		if module == null:
			errors.append("неизвестный модуль %s" % module_id)
			continue
		errors.append_array(module.validate_session(session))
	return errors
