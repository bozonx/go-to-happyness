class_name MapEditorHistory
extends RefCounted

## The editor's single undo stack (map_editor.md §3.3).
##
## One stack for every mode. Pushing a new command after an undo discards the
## redo branch, which is the behaviour every editor has and the only one that
## does not surprise an author.

## Service-backed commands retain 128 deltas.  This cap must never exceed that
## retention window: otherwise the editor can advertise an older command whose
## service has already forgotten the delta needed to replay it.
const MAX_DEPTH := 128

signal changed()

var _undo_stack: Array[MapEditorCommand] = []
var _redo_stack: Array[MapEditorCommand] = []
var _merge_key: StringName = &""
var _merge_msec := 0


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_merge_key = &""
	changed.emit()


## `merge_key` склеивает подряд идущие правки одного поля одного объекта в один
## шаг отмены. Без него протянутый спин или колесо над числовым полем оставляли
## бы столько шагов, сколько было промежуточных значений — а автор сделал одно
## действие (`map_fill_mode.md` §7.5). Правки разных полей не сливаются никогда:
## ключ включает в себя и объект, и поле.
func push(command: MapEditorCommand, merge_key: StringName = &"") -> bool:
	if command == null:
		return false
	if command.apply_on_push() and not command.redo():
		return false
	if _can_merge(merge_key) and _undo_stack.back().absorb(command):
		_merge_msec = Time.get_ticks_msec()
		_redo_stack.clear()
		changed.emit()
		return true
	_merge_key = merge_key
	_merge_msec = Time.get_ticks_msec()
	_undo_stack.append(command)
	# A new action makes the abandoned branch unreachable; keeping it would let
	# redo replay operations that no longer fit the state they were recorded in.
	_redo_stack.clear()
	if _undo_stack.size() > MAX_DEPTH:
		_undo_stack.pop_front()
	changed.emit()
	return true


func _can_merge(merge_key: StringName) -> bool:
	return merge_key != &"" and merge_key == _merge_key \
		and not _undo_stack.is_empty() \
		and Time.get_ticks_msec() - _merge_msec <= EditorFillConventions.HISTORY_MERGE_MSEC


func undo() -> bool:
	_merge_key = &""
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
	_merge_key = &""
	if _redo_stack.is_empty():
		return false
	var command: MapEditorCommand = _redo_stack.pop_back()
	if not command.redo():
		_redo_stack.append(command)
		changed.emit()
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
