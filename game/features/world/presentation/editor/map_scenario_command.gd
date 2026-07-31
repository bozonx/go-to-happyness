class_name MapScenarioCommand
extends MapEditorCommand

## Snapshot command for the scenario layer, for the same reason `MapZoneCommand`
## is one: a single author gesture touches several records at once — deleting a
## flag orphans the conditions that read it, adding a rule renumbers nothing but
## reorders the list — and a per-field delta stack would have to model all of it.
## The layer is small (a rule table is tens of rows, not a terrain), so storing
## it whole before and after is both simpler and safer.

var _document: MapDocument
var _before: Dictionary = {}
var _after: Dictionary = {}
var _first_apply := true


static func of(document: MapDocument, before: Dictionary, after: Dictionary, command_label: String) -> MapScenarioCommand:
	var command := MapScenarioCommand.new()
	command._document = document
	command._before = before.duplicate(true)
	command._after = after.duplicate(true)
	command.label = command_label
	return command


func redo() -> bool:
	if _document == null:
		return false
	_apply(_after)
	_first_apply = false
	return true


func undo() -> bool:
	if _document == null or _first_apply:
		return false
	_apply(_before)
	return true


func _apply(snapshot: Dictionary) -> void:
	_document.scenario = MapScenario.from_json(snapshot)
	_document.mark_dirty()
