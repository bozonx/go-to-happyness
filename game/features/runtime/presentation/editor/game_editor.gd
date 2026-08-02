class_name GameEditor
extends Control

## Authoring surface for a game definition. It reads every installed game so an
## author can start from a shipped one, and writes only into the active project
## pack (content_packaging.md §6.4).
##
## Nothing here is written per module: the module list comes from the registry
## and the start-parameter controls from each module's declared schema, so a new
## built-in module appears in this editor without touching it.

@onready var pack_name_edit: LineEdit = %PackNameEdit
@onready var author_name_edit: LineEdit = %AuthorNameEdit
@onready var version_edit: LineEdit = %VersionEdit
@onready var game_list: ItemList = %GameList
@onready var game_id_edit: LineEdit = %GameIdEdit
@onready var game_name_edit: LineEdit = %GameNameEdit
@onready var game_description_edit: TextEdit = %GameDescriptionEdit
@onready var modules_box: VBoxContainer = %ModulesBox
@onready var map_option: OptionButton = %DefaultMapOption
@onready var input_edit: LineEdit = %InputEdit
@onready var parameters_box: VBoxContainer = %ParametersBox
@onready var menu_parameters_box: VBoxContainer = %MenuParametersBox
@onready var source_label: Label = %SourceLabel
@onready var era_list: ItemList = %EraList
@onready var era_id_edit: LineEdit = %EraIdEdit
@onready var era_ru_edit: LineEdit = %EraRuEdit
@onready var era_en_edit: LineEdit = %EraEnEdit
@onready var era_description_edit: TextEdit = %EraDescriptionEdit
@onready var era_tags_edit: LineEdit = %EraTagsEdit
@onready var era_roots_edit: LineEdit = %EraRootsEdit
@onready var era_next_edit: LineEdit = %EraNextEdit
@onready var era_transition_edit: TextEdit = %EraTransitionEdit
@onready var technologies_edit: TextEdit = %TechnologiesEdit
@onready var status_label: Label = %StatusLabel
@onready var new_game_dialog: ConfirmationDialog = %NewGameDialog
@onready var new_game_id_edit: LineEdit = %NewGameIdEdit
@onready var discard_dialog: ConfirmationDialog = %DiscardDialog

var pack_root := ""
var pack_source: StringName = &""
var pack: ContentPack
var pack_repository: ContentProjectRepository
var repository: GameDefinitionRepository
var entries: Array[Dictionary] = []
var definition: GameDefinition
## Path the open definition came from, empty when it is detached — read-only
## source, or a game that has never been saved.
var current_path := ""
var selected_era := -1
var dirty := false

var _module_checks: Dictionary = {}
## `module_id -> {parameter: value}` the author has edited since the definition
## was opened. Kept beside the controls rather than inside them: toggling a module
## rebuilds the panel, and reading values back off freed controls lost them.
var _edited_parameters: Dictionary = {}
var _pending_discard: Callable = Callable()


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	pack_root = String(launch_manager.get("active_editor_pack_root"))
	pack_source = StringName(launch_manager.get("active_editor_pack_source"))
	if pack_root.is_empty():
		# Nothing to edit, but the author must still be able to leave: an editor
		# that only shows an error and traps you is worse than the error.
		status_label.text = "Не выбран project pack"
		%BackButton.pressed.connect(func() -> void: launch_manager.call("return_to_editor_hub"))
		return
	pack_repository = ContentProjectRepository.new(bool(launch_manager.get("editor_dev_mode")))
	pack = pack_repository.load_pack(pack_root)
	repository = GameDefinitionRepository.new(pack_root)
	_setup_static_options()
	_connect_ui()
	_load_pack_fields()
	_refresh_games()


func _setup_static_options() -> void:
	map_option.clear()
	for entry in ContentIndex.shared().map_entries():
		if entry.kind == MapMeta.KIND_PREFAB:
			continue
		map_option.add_item("%s · %s" % [entry.name, entry.runtime_key])
		map_option.set_item_metadata(map_option.item_count - 1, entry.runtime_key)
	for module_id: StringName in GameModuleRegistry.module_ids():
		var check := CheckBox.new()
		check.text = String(module_id)
		check.toggled.connect(func(_pressed: bool) -> void:
			_mark_dirty()
			_refresh_module_panels())
		modules_box.add_child(check)
		_module_checks[module_id] = check


func _connect_ui() -> void:
	%BackButton.pressed.connect(_on_back_pressed)
	%SavePackButton.pressed.connect(_save_pack)
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	new_game_dialog.confirmed.connect(_new_game)
	%SaveGameButton.pressed.connect(func() -> void: _save_game())
	%SaveAsButton.pressed.connect(_save_game_as)
	%TestGameButton.pressed.connect(_test_game)
	game_list.item_selected.connect(_on_game_list_selected)
	%AddEraButton.pressed.connect(_add_era)
	%RemoveEraButton.pressed.connect(_remove_era)
	era_list.item_selected.connect(_select_era)
	discard_dialog.confirmed.connect(_on_discard_confirmed)
	for field: LineEdit in [game_id_edit, input_edit, era_id_edit, new_game_id_edit]:
		field.text_changed.connect(_sanitize_id.bind(field))
	for field: Control in [game_id_edit, game_name_edit, input_edit, era_id_edit, era_ru_edit,
			era_en_edit, era_tags_edit, era_roots_edit, era_next_edit]:
		(field as LineEdit).text_changed.connect(func(_value: String) -> void: _mark_dirty())
	for field: TextEdit in [game_description_edit, era_description_edit, era_transition_edit, technologies_edit]:
		field.text_changed.connect(_mark_dirty)
	map_option.item_selected.connect(func(_index: int) -> void: _mark_dirty())


func _load_pack_fields() -> void:
	if pack == null:
		return
	pack_name_edit.text = pack.name
	author_name_edit.text = pack.author_name
	version_edit.text = pack.version
	%PackIdentityLabel.text = "%s.%s" % [pack.author_id, pack.id]


func _save_pack() -> void:
	pack.name = pack_name_edit.text.strip_edges()
	pack.author_name = author_name_edit.text.strip_edges()
	pack.version = version_edit.text.strip_edges()
	status_label.text = "Манифест сохранён" if pack_repository.save_pack(pack, pack_root) else pack_repository.last_error


# --- Library ------------------------------------------------------------------

func _refresh_games() -> void:
	entries = repository.list_definitions()
	game_list.clear()
	for entry: Dictionary in entries:
		var badge := "✎ " if entry.writable else "🔒 "
		game_list.add_item("%s%s · %s" % [badge, entry.name, entry.key])
	var selected := _index_of_path(current_path)
	if selected < 0 and not entries.is_empty():
		selected = 0
	if selected >= 0:
		game_list.select(selected)
		if definition == null:
			_open_entry(selected)


func _index_of_path(path: String) -> int:
	if path.is_empty():
		return -1
	for index in entries.size():
		if entries[index].path == path:
			return index
	return -1


func _on_game_list_selected(index: int) -> void:
	_guard_unsaved(func() -> void: _open_entry(index))


func _open_entry(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	var entry := entries[index]
	definition = repository.load(entry.path)
	if definition == null:
		status_label.text = "Не удалось открыть %s" % entry.path
		return
	# Read-only sources detach instead of refusing: starting from a shipped game
	# is the normal first step, and the copy lands in the author's own pack.
	current_path = entry.path if entry.writable else ""
	dirty = false
	_sync_definition_to_ui()
	_update_source_label(entry.key, entry.writable)


func _update_source_label(key: StringName, writable: bool) -> void:
	if writable:
		source_label.text = "%s · проект %s" % [key, pack.id if pack != null else ""]
	else:
		source_label.text = "%s · только чтение → проект %s" % [key, pack.id if pack != null else ""]


func _on_new_game_pressed() -> void:
	_guard_unsaved(func() -> void: new_game_dialog.popup_centered())


func _new_game() -> void:
	var game_id := StringName(ContentId.normalize_id(new_game_id_edit.text))
	if game_id.is_empty():
		status_label.text = "Введите id игры"
		return
	definition = GameDefinition.new()
	definition.id = game_id
	definition.name = String(game_id).capitalize()
	definition.pack_id = pack.id
	definition.module_ids = [&"core.world", &"gth.world_showcase"]
	if map_option.item_count > 0:
		definition.default_map = map_option.get_item_metadata(0)
	current_path = ""
	selected_era = -1
	dirty = true
	_sync_definition_to_ui()
	source_label.text = "новая игра → проект %s" % (pack.id if pack != null else "")


# --- Definition fields --------------------------------------------------------

func _sync_definition_to_ui() -> void:
	if definition == null:
		return
	# Pending edits belong to the definition they were made in. Opening another
	# game keeps them only long enough to write them into the wrong file.
	_edited_parameters.clear()
	game_id_edit.text = String(definition.id)
	game_name_edit.text = definition.name
	game_description_edit.text = definition.description
	for module_id: StringName in _module_checks:
		(_module_checks[module_id] as CheckBox).set_pressed_no_signal(module_id in definition.module_ids)
	_select_option_metadata(map_option, definition.default_map)
	input_edit.text = String(definition.input_profile)
	_refresh_module_panels()
	_refresh_eras()


## One control per parameter every selected module declares, plus a checkbox that
## decides whether the launch screen offers it to the player.
##
## The controls are `EditorPropertyInspector` rows built from each module's own
## schema (`map_start.md` §2.6). The hand-written builder that used to be here
## understood four types and had to be edited — together with its twin in the
## launch screen — every time a module wanted a fifth.
func _refresh_module_panels() -> void:
	if definition == null:
		return
	# Toggling a module rebuilds this panel, so what the author has already typed
	# is kept in `_edited_parameters` rather than read back off the controls:
	# otherwise every toggle silently reverted their edits to the values on disk.
	var in_menu := _menu_parameter_keys() if parameters_box.get_child_count() == 0 else _collected_menu_keys()
	for child in parameters_box.get_children():
		parameters_box.remove_child(child)
		child.queue_free()
	for child in menu_parameters_box.get_children():
		menu_parameters_box.remove_child(child)
		child.queue_free()
	if not definition.progression.eras.is_empty():
		_add_menu_toggle("Начальная эра", "era", in_menu.has("era"))
	for module_id: StringName in _selected_modules():
		var declared := GameModuleRegistry.start_parameters_of(module_id)
		if declared.is_empty():
			continue
		var header := Label.new()
		header.text = String(module_id)
		parameters_box.add_child(header)
		var values := _module_values(module_id, declared)
		var inspector := EditorPropertyInspector.new()
		inspector.set_fields(declared, values, false)
		inspector.property_committed.connect(_on_parameter_committed.bind(module_id))
		inspector.property_reset_requested.connect(func(parameter: StringName) -> void:
			var reset := EntityPropertyDef.find(declared, parameter)
			if reset != null:
				_on_parameter_committed(parameter, reset.default, module_id))
		parameters_box.add_child(inspector)
		for parameter: EntityPropertyDef in declared:
			# Only a parameter the module lets a player see can be offered in the
			# launch screen (§2.6); an author-only one has no menu control to build.
			if parameter.visibility != EntityPropertyDef.VISIBILITY_PLAYER:
				continue
			var key := "%s/%s" % [module_id, parameter.name]
			_add_menu_toggle("%s · %s" % [module_id, parameter.label], key, in_menu.has(key))


## Authored values of one module: what the author has edited in this session,
## falling back to the definition on disk and then to the module's own default.
func _module_values(module_id: StringName, declared: Array[EntityPropertyDef]) -> Dictionary:
	var authored := definition.parameters_for(module_id)
	var pending: Dictionary = _edited_parameters.get(module_id, {})
	var values: Dictionary = {}
	for parameter: EntityPropertyDef in declared:
		var key := String(parameter.name)
		values[parameter.name] = parameter.clamp_value(
			pending.get(key, authored.get(key, parameter.default)))
	return values


func _on_parameter_committed(parameter: StringName, value: Variant, module_id: StringName) -> void:
	var values: Dictionary = _edited_parameters.get(module_id, {})
	values[String(parameter)] = value
	_edited_parameters[module_id] = values
	_mark_dirty()


func _add_menu_toggle(label_text: String, key: String, pressed: bool) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = pressed
	check.set_meta("menu_key", key)
	check.toggled.connect(func(_v: bool) -> void: _mark_dirty())
	menu_parameters_box.add_child(check)


## Menu toggles as they currently stand in the UI, so a module toggle does not
## reset which parameters the author chose to surface.
func _collected_menu_keys() -> Dictionary:
	var keys: Dictionary = {}
	for check in menu_parameters_box.get_children():
		if check is CheckBox and (check as CheckBox).button_pressed:
			keys[String(check.get_meta("menu_key", ""))] = true
	return keys


func _menu_parameter_keys() -> Dictionary:
	var keys: Dictionary = {}
	for entry: Dictionary in definition.menu_parameters:
		if StringName(entry.get("type", "")) == GameDefinition.MENU_PARAMETER_ERA:
			keys["era"] = true
		else:
			keys["%s/%s" % [entry.get("module", ""), entry.get("id", "")]] = true
	return keys


func _selected_modules() -> Array[StringName]:
	var ids: Array[StringName] = []
	for module_id: StringName in GameModuleRegistry.module_ids():
		if (_module_checks[module_id] as CheckBox).button_pressed:
			ids.append(module_id)
	return ids


func _collect_definition_from_ui() -> bool:
	_commit_era_fields()
	definition.id = StringName(ContentId.normalize_id(game_id_edit.text))
	definition.name = game_name_edit.text.strip_edges()
	definition.description = game_description_edit.text.strip_edges()
	definition.pack_id = pack.id
	definition.module_ids = _selected_modules()
	if map_option.selected >= 0:
		definition.default_map = map_option.get_item_metadata(map_option.selected)
	definition.input_profile = StringName(ContentId.normalize_id(input_edit.text))
	definition.start_module_parameters = _collect_start_parameters()
	definition.menu_parameters = _collect_menu_parameters()
	var parsed_technologies: Variant = JSON.parse_string(technologies_edit.text)
	if not parsed_technologies is Dictionary:
		status_label.text = "Технологии должны быть JSON-объектом"
		return false
	definition.progression.technologies = (parsed_technologies as Dictionary).duplicate(true)
	return true


## What the definition will be saved with. Edits live in `_edited_parameters`
## from the moment they are committed, so this neither reads controls back nor
## depends on the panel still being built.
func _collect_start_parameters() -> Dictionary:
	var collected: Dictionary = {}
	for module_id: StringName in _selected_modules():
		var declared := GameModuleRegistry.start_parameters_of(module_id)
		if declared.is_empty():
			continue
		var values: Dictionary = {}
		for parameter: EntityPropertyDef in declared:
			values[String(parameter.name)] = _module_values(module_id, declared)[parameter.name]
		collected[module_id] = values
	return collected


func _collect_menu_parameters() -> Array[Dictionary]:
	var collected: Array[Dictionary] = []
	for check in menu_parameters_box.get_children():
		if not check is CheckBox or not (check as CheckBox).button_pressed:
			continue
		var key := String(check.get_meta("menu_key", ""))
		if key == "era":
			collected.append({"type": String(GameDefinition.MENU_PARAMETER_ERA)})
			continue
		var parts := key.split("/")
		if parts.size() == 2:
			collected.append({"module": parts[0], "id": parts[1]})
	return collected


# --- Saving -------------------------------------------------------------------

func _save_game() -> bool:
	if definition == null:
		return false
	if not _collect_definition_from_ui():
		return false
	var saved := repository.save(definition, current_path)
	if saved.is_empty():
		status_label.text = repository.last_error
		return false
	current_path = saved
	dirty = false
	status_label.text = "Игра сохранена: %s" % saved
	_update_source_label(ContentId.runtime_key(pack_source, definition.id), true)
	_refresh_games()
	return true


## Explicit copy into the active project, whatever the definition was opened
## from. Detaching already does this implicitly; this is the deliberate version.
func _save_game_as() -> void:
	if definition == null:
		return
	current_path = ""
	_save_game()


func _test_game() -> void:
	if not _save_game():
		return
	get_node("/root/GameLaunchManager").call("launch_editor_test", ContentId.runtime_key(pack_source, definition.id),
		MapDocumentService.new().load_map(definition.default_map),
		RuntimeLaunchManager.GAME_EDITOR_SCENE, definition.default_map)


# --- Unsaved-work guard -------------------------------------------------------

func _mark_dirty(_unused: Variant = null) -> void:
	dirty = true


func _guard_unsaved(action: Callable) -> void:
	if not dirty or definition == null:
		action.call()
		return
	_pending_discard = action
	discard_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	dirty = false
	if _pending_discard.is_valid():
		var action := _pending_discard
		_pending_discard = Callable()
		action.call()


func _on_back_pressed() -> void:
	_guard_unsaved(func() -> void: get_node("/root/GameLaunchManager").call("return_to_editor_hub"))


# --- Eras ---------------------------------------------------------------------

func _refresh_eras() -> void:
	era_list.clear()
	technologies_edit.text = JSON.stringify(definition.progression.technologies, "  ")
	for era: EraDefinition in definition.progression.eras:
		era_list.add_item("%s · %s" % [era.display_name("ru"), era.id])
	selected_era = -1
	if not definition.progression.eras.is_empty():
		era_list.select(0)
		_select_era(0)


func _select_era(index: int) -> void:
	_commit_era_fields()
	selected_era = index
	if index < 0 or index >= definition.progression.eras.size():
		return
	var era := definition.progression.eras[index]
	era_id_edit.text = String(era.id)
	era_ru_edit.text = String(era.names.get("ru", ""))
	era_en_edit.text = String(era.names.get("en", ""))
	era_description_edit.text = String(era.descriptions.get("ru", ""))
	era_tags_edit.text = _join_ids(era.tags)
	era_roots_edit.text = _join_ids(era.technology_roots)
	era_next_edit.text = _join_ids(era.next_eras)
	era_transition_edit.text = JSON.stringify(era.transition, "  ")


func _commit_era_fields() -> void:
	if definition == null or selected_era < 0 or selected_era >= definition.progression.eras.size():
		return
	var era := definition.progression.eras[selected_era]
	var era_id := ContentId.normalize_id(era_id_edit.text)
	if not era_id.is_empty():
		era.id = StringName(era_id)
	era.names = {"ru": era_ru_edit.text.strip_edges(), "en": era_en_edit.text.strip_edges()}
	era.descriptions = {"ru": era_description_edit.text.strip_edges()}
	era.tags = _split_ids(era_tags_edit.text)
	era.technology_roots = _split_ids(era_roots_edit.text)
	era.next_eras = _split_ids(era_next_edit.text)
	var transition: Variant = JSON.parse_string(era_transition_edit.text)
	if transition is Dictionary:
		era.transition = (transition as Dictionary).duplicate(true)


func _add_era() -> void:
	if definition == null:
		return
	_commit_era_fields()
	var era := EraDefinition.new()
	era.id = StringName("era_%d" % (definition.progression.eras.size() + 1))
	era.names = {"ru": "Новая эра", "en": "New era"}
	definition.progression.eras.append(era)
	_mark_dirty()
	_refresh_eras()
	_refresh_module_panels()
	era_list.select(definition.progression.eras.size() - 1)
	_select_era(definition.progression.eras.size() - 1)


func _remove_era() -> void:
	if definition == null or selected_era < 0:
		return
	definition.progression.eras.remove_at(selected_era)
	selected_era = -1
	_mark_dirty()
	_refresh_eras()
	_refresh_module_panels()


static func _select_option_metadata(option: OptionButton, value: Variant) -> void:
	for index: int in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return


static func _split_ids(value: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw: String in value.split(",", false):
		var cleaned := ContentId.normalize_id(raw)
		if not cleaned.is_empty():
			result.append(StringName(cleaned))
	return result


static func _join_ids(values: Array[StringName]) -> String:
	var strings: PackedStringArray = []
	for value: StringName in values:
		strings.append(String(value))
	return ", ".join(strings)


func _sanitize_id(value: String, field: LineEdit) -> void:
	var sanitized := ContentId.sanitize_id(value)
	if sanitized != value:
		field.text = sanitized
		field.caret_column = sanitized.length()
