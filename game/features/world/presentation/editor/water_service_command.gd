class_name WaterServiceCommand
extends MapEditorCommand

## A water stroke, recorded on the editor's stack (map_editor.md §3.3).
##
## The twin of `TerrainServiceCommand` and, like it, no second history: the
## service already keeps a stack of `WaterDelta` and reverting one republishes the
## surface and the navigation field, so this delegates rather than duplicates.
##
## Both stacks stay in step because both are last-in-first-out and every water
## edit that reaches the service also reaches this one. Undoing a terrain command
## does not call the water service and vice versa, so the relative order of each
## kind's entries is unchanged — which is exactly what lets one editor stack carry
## two layers.

var _service: WaterService
var _delta: WaterDelta


static func of(service: WaterService, delta: WaterDelta, label: String) -> WaterServiceCommand:
	var command := WaterServiceCommand.new()
	command._service = service
	command._delta = delta
	command.label = label
	return command


## The service commits as it validates, so the edit has already happened by the
## time the editor hears about it.
func apply_on_push() -> bool:
	return false


func redo() -> bool:
	return _service != null and _delta != null and _service.redo_delta(_delta)


func undo() -> bool:
	return _service != null and _delta != null and _service.undo_delta(_delta)
