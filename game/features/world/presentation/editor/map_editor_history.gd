class_name MapEditorHistory
extends RefCounted

## The editor's single undo stack (map_editor.md §3.3).
##
## One stack for every mode. Pushing a new command after an undo discards the
## redo branch, which is the behaviour every editor has and the only one that
## does not surprise an author.

const MAX_DEPTH := 256

signal changed()

var _undo_stack: Array[MapEditorCommand] = []
var _redo_stack: Array[MapEditorCommand] = []


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	changed.emit()


func push(command: MapEditorCommand) -> bool:
	if command == null:
		return false
	if command.apply_on_push() and not command.redo():
		return false
	_undo_stack.append(command)
	# A new action makes the abandoned branch unreachable; keeping it would let
	# redo replay operations that no longer fit the state they were recorded in.
	_redo_stack.clear()
	if _undo_stack.size() > MAX_DEPTH:
		_undo_stack.pop_front()
	changed.emit()
	return true


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var command: MapEditorCommand = _undo_stack.pop_back()
	if not command.undo():
		# It refused, so it is still in effect: put it back rather than leave the
		# stack claiming a state the world is not in.
		_undo_stack.append(command)
		changed.emit()
		return false
	_redo_stack.append(command)
	changed.emit()
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	var command: MapEditorCommand = _redo_stack.pop_back()
	if not command.redo():
		_redo_stack.append(command)
		return false
	_undo_stack.append(command)
	changed.emit()
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo_depth() -> int:
	return _undo_stack.size()


func redo_depth() -> int:
	return _redo_stack.size()


func undo_label() -> String:
	return _undo_stack.back().label if not _undo_stack.is_empty() else ""
