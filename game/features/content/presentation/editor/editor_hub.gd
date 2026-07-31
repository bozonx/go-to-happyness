class_name EditorHub
extends Control

@export var dev_mode := true

@onready var project_list: ItemList = %ProjectList
@onready var mode_label: Label = %ModeLabel
@onready var project_title: Label = %ProjectTitle
@onready var project_details: Label = %ProjectDetails
@onready var content_counts_label: Label = %ContentCountsLabel
@onready var create_button: Button = %CreateButton
@onready var delete_button: Button = %DeleteButton
@onready var game_button: Button = %GameButton
@onready var map_button: Button = %MapButton
@onready var building_button: Button = %BuildingButton
@onready var create_dialog: ConfirmationDialog = %CreateDialog
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog
@onready var author_id_edit: LineEdit = %AuthorIdEdit
@onready var author_name_edit: LineEdit = %AuthorNameEdit
@onready var pack_id_edit: LineEdit = %PackIdEdit
@onready var pack_name_edit: LineEdit = %PackNameEdit
@onready var status_label: Label = %StatusLabel

var repository: ContentProjectRepository
var projects: Array[Dictionary] = []
var selected_project: Dictionary = {}


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	if launch_manager != null and bool(launch_manager.get("editor_mode_forced")):
		dev_mode = bool(launch_manager.get("editor_dev_mode"))
	dev_mode = dev_mode and OS.has_feature("editor")
	repository = ContentProjectRepository.new(dev_mode)
	mode_label.text = "Встроенный контент · dev mode" if dev_mode else "Пользовательские проекты"
	create_button.visible = not dev_mode
	delete_button.visible = not dev_mode
	project_list.item_selected.connect(_select_project)
	create_button.pressed.connect(create_dialog.popup_centered)
	create_dialog.confirmed.connect(_create_project)
	delete_button.pressed.connect(_confirm_delete_project)
	delete_dialog.confirmed.connect(_delete_project)
	game_button.pressed.connect(_open_game_editor)
	map_button.pressed.connect(_open_map_editor)
	building_button.pressed.connect(_open_building_editor)
	%BackButton.pressed.connect(func(): launch_manager.call("return_to_main_menu"))
	for field: LineEdit in [author_id_edit, pack_id_edit]:
		field.text_changed.connect(_sanitize_id.bind(field))
	_refresh_projects()


func _refresh_projects() -> void:
	projects = repository.list_projects()
	project_list.clear()
	for project: Dictionary in projects:
		project_list.add_item("%s  ·  %s.%s" % [project.name, project.author_id, project.id])
	if not projects.is_empty():
		project_list.select(0)
		_select_project(0)
	else:
		_set_project({})


func _select_project(index: int) -> void:
	if index >= 0 and index < projects.size():
		_set_project(projects[index])


func _set_project(project: Dictionary) -> void:
	selected_project = project
	var available := not project.is_empty()
	game_button.disabled = not available
	map_button.disabled = not available
	building_button.disabled = not available
	project_title.text = String(project.get("name", "Выберите проект"))
	project_details.text = "%s\n%s" % [project.get("root", ""),
		"Встроенный writable pack" if dev_mode and available else "Редактируемый пользовательский pack" if available else ""]
	if available:
		_refresh_content_counts(project)
		var launch_manager := get_node_or_null("/root/GameLaunchManager")
		launch_manager.call("select_editor_pack", project.root, project.source)
	else:
		content_counts_label.text = ""


## Counts games, maps and buildings in the selected project pack by indexing
## its content through ContentIndex filtered by source.
func _refresh_content_counts(project: Dictionary) -> void:
	var index := ContentIndex.shared()
	var source: StringName = project.get("source", &"")
	var game_count := 0
	var map_count := 0
	var building_count := 0
	for entry in index.game_entries():
		if entry.source == source:
			game_count += 1
	for entry in index.map_entries():
		if entry.source == source and entry.kind != &"prefab":
			map_count += 1
	for entry in index.blueprint_entries():
		if entry.source == source:
			building_count += 1
	content_counts_label.text = "Игр: %d · Карт: %d · Зданий: %d" % [game_count, map_count, building_count]


func _create_project() -> void:
	var created := repository.create_project(
		StringName(ContentId.normalize_id(author_id_edit.text)),
		StringName(ContentId.normalize_id(pack_id_edit.text)),
		pack_name_edit.text.strip_edges(), author_name_edit.text.strip_edges())
	if created.is_empty():
		status_label.text = repository.last_error
		return
	status_label.text = "Проект создан: %s" % created.root
	_refresh_projects()


func _open_game_editor() -> void:
	get_node("/root/GameLaunchManager").call("launch_game_editor")


func _open_map_editor() -> void:
	get_node("/root/GameLaunchManager").call("launch_map_editor", &"", dev_mode)


func _open_building_editor() -> void:
	get_node("/root/GameLaunchManager").call("launch_building_editor", dev_mode)


func _confirm_delete_project() -> void:
	if selected_project.is_empty():
		return
	delete_dialog.dialog_text = "Удалить проект «%s»?\nПапка: %s\nВесь контент будет удалён безвозвратно." % [
		selected_project.get("name", ""), selected_project.get("root", "")]
	delete_dialog.popup_centered()


func _delete_project() -> void:
	if selected_project.is_empty():
		return
	var root: String = selected_project.get("root", "")
	if root.is_empty() or dev_mode:
		return
	if _remove_directory_recursive(root):
		ContentIndex.invalidate()
		status_label.text = "Проект удалён: %s" % root
		selected_project = {}
		_refresh_projects()
	else:
		status_label.text = "Не удалось удалить проект"


static func _remove_directory_recursive(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return false
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory in DirAccess.get_directories_at(path):
		_remove_directory_recursive(path.path_join(directory))
	DirAccess.remove_absolute(path)
	return not DirAccess.dir_exists_absolute(path)


func _sanitize_id(value: String, field: LineEdit) -> void:
	var sanitized := ContentId.sanitize_id(value)
	if sanitized != value:
		field.text = sanitized
		field.caret_column = sanitized.length()
