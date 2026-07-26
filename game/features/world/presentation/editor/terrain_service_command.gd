class_name TerrainServiceCommand
extends MapEditorCommand

## A ground edit, recorded on the editor's stack (map_editor.md §3.3).
##
## The terrain already has a working undo: `TerrainService` keeps a stack of
## `TerrainDelta`, each carrying whole columns, and reverting one republishes the
## mesh and the navigation field. This command does not duplicate that — it
## delegates to it.
##
## The two stacks stay in step because both are last-in-first-out and every
## terrain edit that reaches the service also reaches this stack. Undoing a
## command of some other kind simply does not call the service, so the relative
## order of the terrain entries is unchanged. That is what lets phases 2–5 add
## placements and markers to the same stack without a second history.

var _service: TerrainService


static func of(service: TerrainService, label: String) -> TerrainServiceCommand:
	var command := TerrainServiceCommand.new()
	command._service = service
	command.label = label
	return command


## The service commits as it validates, so the edit has already happened by the
## time the editor hears about it.
func apply_on_push() -> bool:
	return false


func redo() -> bool:
	return _service != null and _service.redo()


func undo() -> bool:
	return _service != null and _service.undo()
