class_name MapZoneCommand
extends MapEditorCommand

## Snapshot command for the small, typed map zone layer. Zone gestures change a
## handful of records at once (deleting an area may remove its points and route
## stops), so storing the layer before and after is clearer and safer than a
## parallel undo stack.
##
## It optionally carries the map's start section too, because one gesture reaches
## both: placing the party's first appearance point builds the spawn group *and*
## the entrance that names it (`MapPartyStartAuthoring`). Two commands would mean
## two `Ctrl+Z` for one click, and the state between them — a group no entrance
## points at — is exactly the unlaunchable map that wiring exists to prevent.
## `MapEditorCompositeCommand` cannot express this pair: it answers `false` to
## `apply_on_push`, so a snapshot part inside it never gets the first `redo` that
## arms its `undo`.

var _document: MapDocument
var _before: Dictionary = {}
var _after: Dictionary = {}
## Start section snapshots, or empty when the gesture did not touch it. Empty is
## meaningful — a map always has a start section, so "nothing recorded" and "an
## empty section" can never be confused.
var _start_before: Dictionary = {}
var _start_after: Dictionary = {}
var _first_apply := true


static func of(document: MapDocument, before: Dictionary, after: Dictionary, command_label: String) -> MapZoneCommand:
	var command := MapZoneCommand.new()
	command._document = document
	command._before = before.duplicate(true)
	command._after = after.duplicate(true)
	command.label = command_label
	return command


## The same command, recording the start section alongside the layer.
static func with_start(
	document: MapDocument,
	before: Dictionary,
	after: Dictionary,
	start_before: Dictionary,
	start_after: Dictionary,
	command_label: String,
) -> MapZoneCommand:
	var command := MapZoneCommand.of(document, before, after, command_label)
	command._start_before = start_before.duplicate(true)
	command._start_after = start_after.duplicate(true)
	return command


func redo() -> bool:
	if _document == null:
		return false
	_apply(_after, _start_after)
	_first_apply = false
	return true


func undo() -> bool:
	if _document == null or _first_apply:
		return false
	_apply(_before, _start_before)
	return true


func _apply(snapshot: Dictionary, start_snapshot: Dictionary) -> void:
	_document.zones.from_json(snapshot)
	if not start_snapshot.is_empty():
		_document.meta.start = MapStart.from_dict(start_snapshot)
	_document.mark_dirty()
