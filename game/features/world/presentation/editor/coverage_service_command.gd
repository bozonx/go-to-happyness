class_name CoverageServiceCommand
extends MapEditorCommand

## A coverage stroke, recorded on the editor's stack (map_editor.md §3.3).
##
## The twin of `TerrainServiceCommand` and `WaterServiceCommand`, and like them no
## second history: the service already keeps a stack of `CoverageDelta`, and
## reverting one republishes both the surface texture and the road weights, so
## this delegates rather than duplicates.

var _service: CoverageService
var _delta: CoverageDelta


static func of(service: CoverageService, delta: CoverageDelta, label: String) -> CoverageServiceCommand:
	var command := CoverageServiceCommand.new()
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
