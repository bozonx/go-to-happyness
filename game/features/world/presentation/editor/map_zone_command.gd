class_name MapZoneCommand
extends MapEditorCommand

## Snapshot command for the small, typed map zone layer. Zone gestures change a
## handful of records at once (deleting an area may remove its points and route
## stops), so storing the layer before and after is clearer and safer than a
## parallel undo stack.

var _document: MapDocument
var _before: Dictionary = {}
var _after: Dictionary = {}
var _first_apply := true


static func of(document: MapDocument, before: Dictionary, after: Dictionary, command_label: String) -> MapZoneCommand:
	var command := MapZoneCommand.new()
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
	_document.zones.from_json(snapshot)
	_document.mark_dirty()
