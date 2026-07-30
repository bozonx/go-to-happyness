class_name EditorHub
extends Control

@export var dev_mode := true

@onready var project_list: ItemList = %ProjectList
@onready var mode_label: Label = %ModeLabel
@onready var project_title: Label = %ProjectTitle
@onready var project_details: Label = %ProjectDetails
@onready var create_button: Button = %CreateButton
@onready var game_button: Button = %GameButton
@onready var map_button: Button = %MapButton
@onready var building_button: Button = %BuildingButton
@onready var create_dialog: ConfirmationDialog = %CreateDialog
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
	project_list.item_selected.connect(_select_project)
	create_button.pressed.connect(create_dialog.popup_centered)
	create_dialog.confirmed.connect(_create_project)
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
		var launch_manager := get_node_or_null("/root/GameLaunchManager")
		launch_manager.call("select_editor_pack", project.root, project.source)


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


func _sanitize_id(value: String, field: LineEdit) -> void:
	var sanitized := ContentId.sanitize_id(value)
	if sanitized != value:
		field.text = sanitized
		field.caret_column = sanitized.length()
