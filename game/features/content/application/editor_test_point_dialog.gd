class_name EditorTestPointDialog
extends AcceptDialog

## Properties inspector for a single test point (`EditorTestPoints`).
##
## The point's `name` field is in the format and read back, but nothing could
## write it: every point was "точка 1…9" because that is what `display_name`
## falls back to. This is the one field it owns — the cell and the level are
## where the author placed the point and are read-only, the name is the label.
##
## Shared by both editors, next to `EditorTestPoints` for the same reason that
## class is in `content`: a test point is a piece of authoring state belonging to
## a content package on disk, and the inspector over it is no more a map or a
## building thing than the record it edits. The level's meaning differs — a
## terrain level on the map, a floor in a building — so the editor passes the
## word, and the dialog stays vocabulary-neutral.
##
## Emits `name_changed` on every edit and never touches the sidecar itself: the
## owner writes the point, persists and redraws (`map_editor._commit_test_points`
## / `building_editor.persist_test_points`), and the marker's label and the
## run-menu row pick up the new name from the same single source of truth.

signal name_changed(index: int, new_name: String)

var _index := -1
var _name_edit: LineEdit = null
var _cell_label: Label = null
var _level_label: Label = null
## "ур. рельефа" on the map, "этаж" in a building — the one word that makes the
## read-only level row mean something in the editor that opened the dialog.
var _level_term := ""


func _ready() -> void:
	# `title`, `ok_button_text` and size are presentation; the editor opening it
	# positions the popup. Built in code because the dialog is a shared component
	# instanced by two owners, and a `.tscn` per owner would duplicate five lines.
	title = "Тест-точка"
	ok_button_text = "Готово"
	min_size = Vector2i(320, 0)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)

	var title_row := HBoxContainer.new()
	var glyph := Label.new()
	glyph.text = "◆"
	var title_text := Label.new()
	title_text.text = "Свойства тест-точки"
	title_text.add_theme_font_size_override("font_size", 15)
	title_row.add_child(glyph)
	title_row.add_child(title_text)
	body.add_child(title_row)

	var name_label := Label.new()
	name_label.text = "Имя"
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72, 1.0))
	body.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "имя точки (иначе — «точка N»)"
	_name_edit.text_submitted.connect(_commit_name)
	_name_edit.focus_exited.connect(_commit_name)
	body.add_child(_name_edit)

	var pos_section := Label.new()
	pos_section.text = "Положение"
	pos_section.add_theme_font_size_override("font_size", 11)
	pos_section.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72, 1.0))
	body.add_child(pos_section)

	_cell_label = Label.new()
	_cell_label.add_theme_font_size_override("font_size", 12)
	body.add_child(_cell_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 12)
	body.add_child(_level_label)

	confirmed.connect(_commit_name)


## Opens the dialog on `point` (`index` into the owner's list), labelling the
## level row with `level_term`. An empty `level_term` hides the row rather than
## showing a label that says nothing.
func edit_point(index: int, point: EditorTestPoints.Point, level_term: String) -> void:
	_index = index
	_level_term = level_term
	# Repopulate before showing so the field does not flash the previous point's
	# name while the popup is already on screen.
	_name_edit.text = point.name
	_cell_label.text = "Клетка: %d, %d" % [point.cell.x, point.cell.y]
	if level_term.is_empty():
		_level_label.visible = false
	else:
		_level_label.visible = true
		_level_label.text = "%s: %d" % [level_term, point.level]
	popup_centered()
	_name_edit.grab_focus()
	_name_edit.caret_column = _name_edit.text.length()


## Emits the field on every commit path. The owner decides what counts as a
## change — it may ignore a name equal to the current one — but this dialog does
## not: stripping whitespace here would silently undo a name the author padded
## on purpose, and there is no reason a point cannot be named " ".
func _commit_name(_arg: Variant = null) -> void:
	if _index < 0 or _name_edit == null:
		return
	name_changed.emit(_index, _name_edit.text)
