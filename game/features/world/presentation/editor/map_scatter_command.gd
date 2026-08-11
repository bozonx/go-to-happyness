class_name MapScatterCommand
extends MapEditorCommand

## Отмена мазка кисти-разброса (`map_fill_mode.md` §8.2, `map_editor.md` §7).
##
## Снимок — это закодированный слой, а не список изменений. Причина та же, по
## которой у именованных сущностей снимок слоя: мазок ставит сотни записей и
## может задеть таблицу архетипов, а «дельта на сотни записей» — это способ
## однажды разойтись с тем, что реально лежит в слое. Байты `objects.bin`
## дёшевы: шестнадцать на объект, то есть мазок в триста деревьев — пять
## килобайт снимка.

var _document: MapDocument
var _before := PackedByteArray()
var _after := PackedByteArray()
var _before_archetypes: Array[StringName] = []
var _after_archetypes: Array[StringName] = []
var _first_apply := true


## `before` снимается ДО правки слоя, `after` — после.
static func of(
	document: MapDocument,
	before: PackedByteArray,
	before_archetypes: Array[StringName],
	command_label: String
) -> MapScatterCommand:
	var command := MapScatterCommand.new()
	command._document = document
	command._before = before
	command._before_archetypes = before_archetypes.duplicate()
	command._after = MapScatterCodec.encode(document.scatter)
	command._after_archetypes = document.scatter.archetypes.duplicate()
	command.label = command_label
	return command


func redo() -> bool:
	if _document == null:
		return false
	_apply(_after, _after_archetypes)
	_first_apply = false
	return true


func undo() -> bool:
	if _document == null or _first_apply:
		return false
	_apply(_before, _before_archetypes)
	return true


func mark_applied() -> MapScatterCommand:
	_first_apply = false
	return self


func capture_after() -> void:
	if _document == null:
		return
	_after = MapScatterCodec.encode(_document.scatter)
	_after_archetypes = _document.scatter.archetypes.duplicate()


## Склейка протяжки: «было» от первого кадра, «стало» от последнего. Автор вёл
## мышью один раз — и Ctrl+Z обязан отменить один мазок, а не семнадцать кадров.
func absorb(next: MapEditorCommand) -> bool:
	var other := next as MapScatterCommand
	if other == null or other._document != _document:
		return false
	_after = other._after
	_after_archetypes = other._after_archetypes.duplicate()
	_first_apply = false
	return true


func _apply(snapshot: PackedByteArray, archetypes: Array[StringName]) -> void:
	var layer := _document.scatter
	layer.archetypes = archetypes.duplicate()
	if snapshot.is_empty():
		# Пустой снимок — это пустой слой, а не «нечего восстанавливать»:
		# отменённый первый мазок обязан вернуть карту к чистой земле.
		layer.records.clear()
	else:
		MapScatterCodec.decode_into(snapshot, layer)
	_document.mark_dirty()
