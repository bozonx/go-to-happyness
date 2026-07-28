class_name MapEntityCommand
extends MapEditorCommand

## Snapshot command for named map entities. Individual placement is small, and a
## layer snapshot makes add/delete/transform uniformly safe on the shared stack.

var _document: MapDocument
var _before: Array = []
var _after: Array = []
var _first_apply := true


static func of(document: MapDocument, before: Array, after: Array, command_label: String) -> MapEntityCommand:
	var command := MapEntityCommand.new()
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


## Composite terrain commands are recorded after both terrain and dependent
## entity positions have already changed, so they must be undoable immediately.
func mark_applied() -> MapEntityCommand:
	_first_apply = false
	return self


func _apply(snapshot: Array) -> void:
	_document.entities.from_json(snapshot)
	_document.mark_dirty()
