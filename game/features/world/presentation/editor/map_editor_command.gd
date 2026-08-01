class_name MapEditorCommand
extends RefCounted

## One undoable operation of the territory editor (map_editor.md §3.3).
##
## The editor has exactly one undo stack across every mode, and this is the
## interface that makes that possible: a mode never touches the stack's insides,
## it produces commands. `Ctrl+Z` after switching modes therefore undoes the
## author's last action, whatever mode made it.
##
## This is the deliberate correction of the building editor, where undo was built
## per mode and decor kept a stack of its own — which already reads as a bug: the
## author presses undo, and nothing they did comes back.

## Short description of what was done, shown in the status line and the edit menu.
var label := ""


## Re-applies the operation. Called for redo, and by the editor when the command
## is first pushed only if `apply_on_push` says so.
func redo() -> bool:
	return false


## Reverses it. Must restore exactly the state before `redo`, or the stack lies.
func undo() -> bool:
	return false


## Whether pushing this command should perform it. Operations that have already
## happened by the time they are recorded — a terrain edit, which the service
## commits as it validates it — answer false.
func apply_on_push() -> bool:
	return true


## Поглощает следующую команду того же поля, чтобы серия непрерывных правок
## осталась одним шагом отмены. Возвращает false, если склейка невозможна: тогда
## история просто положит вторую команду поверх первой.
func absorb(_next: MapEditorCommand) -> bool:
	return false
