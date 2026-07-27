class_name MapEditorCompositeCommand
extends MapEditorCommand

## Several already-committed operations that the author performed as one action
## (map_editor.md §3.3).
##
## It exists for exactly one situation, and inventing it for anything else is how
## an undo stack starts lying: **one stroke produced edits in two layers.** Digging
## a channel to the coast on a map with an ocean border (§6.1) moves the ground and
## then lets the sea in, and those are a `TerrainDelta` and a `WaterDelta` on two
## services. An author pressing Ctrl+Z once expects the channel back the way it
## was, not a dry trench they now have to undo again.
##
## Undo runs the parts in reverse and redo in order — the only ordering that works
## when the later part was computed against the state the earlier one produced. If
## any part refuses, the ones already reversed are re-applied, because a
## half-undone composite is a state no author asked for and no command can
## describe.

var _parts: Array[MapEditorCommand] = []


static func of(parts: Array[MapEditorCommand], label: String) -> MapEditorCompositeCommand:
	var command := MapEditorCompositeCommand.new()
	command._parts = parts.duplicate()
	command.label = label
	return command


## The parts have already been committed by their services, exactly as a single
## `TerrainServiceCommand` has.
func apply_on_push() -> bool:
	return false


func redo() -> bool:
	for index in _parts.size():
		if _parts[index].redo():
			continue
		for done in range(index - 1, -1, -1):
			_parts[done].undo()
		return false
	return true


func undo() -> bool:
	for index in range(_parts.size() - 1, -1, -1):
		if _parts[index].undo():
			continue
		for done in range(index + 1, _parts.size()):
			_parts[done].redo()
		return false
	return true


func part_count() -> int:
	return _parts.size()
