class_name MapPlacementCommand
extends MapEditorCommand

## Snapshot command for the `placements[]` layer (map_editor.md §3.3).
##
## The twin of `MapEntityCommand`, and for the same reason: a placement row is
## small, and one snapshot of the layer makes place / move / delete uniformly safe
## on the shared stack.
##
## It is almost never pushed alone. Placing a building moves the ground and the
## water as well, and all of it is one author action — so this becomes a part of a
## `MapEditorCompositeCommand` and the terrain deltas travel with it. That is the
## whole of §11.1's "одна команда undo": partial undo is impossible because there
## is nothing to undo partially.

var _document: MapDocument
var _before: Array = []
var _after: Array = []
var _applied := false


static func of(document: MapDocument, before: Array, after: Array, command_label: String) -> MapPlacementCommand:
	var command := MapPlacementCommand.new()
	command._document = document
	command._before = before.duplicate(true)
	command._after = after.duplicate(true)
	command.label = command_label
	return command


## The mode has already mutated the layer by the time it records the snapshot,
## exactly as the terrain services have already committed their deltas.
func apply_on_push() -> bool:
	return false


func redo() -> bool:
	if _document == null:
		return false
	_apply(_after)
	_applied = true
	return true


func undo() -> bool:
	if _document == null:
		return false
	_apply(_before)
	_applied = false
	return true


func was_applied() -> bool:
	return _applied


func _apply(snapshot: Array) -> void:
	_document.placements.from_json(snapshot)
	_document.mark_dirty()
