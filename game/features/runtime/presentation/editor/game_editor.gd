class_name GameEditor
extends Control

@onready var pack_name_edit: LineEdit = %PackNameEdit
@onready var author_name_edit: LineEdit = %AuthorNameEdit
@onready var version_edit: LineEdit = %VersionEdit
@onready var game_list: ItemList = %GameList
@onready var game_id_edit: LineEdit = %GameIdEdit
@onready var game_name_edit: LineEdit = %GameNameEdit
@onready var game_description_edit: TextEdit = %GameDescriptionEdit
@onready var modules_edit: LineEdit = %ModulesEdit
@onready var map_option: OptionButton = %DefaultMapOption
@onready var clock_option: OptionButton = %ClockOption
@onready var input_edit: LineEdit = %InputEdit
@onready var layout_edit: LineEdit = %LayoutEdit
@onready var settlement_panel: Control = %SettlementPanel
@onready var biome_edit: LineEdit = %BiomeEdit
@onready var money_spin: SpinBox = %MoneySpin
@onready var wellbeing_spin: SpinBox = %WellbeingSpin
@onready var population_spin: SpinBox = %PopulationSpin
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

var pack_root := ""
var pack_source: StringName = &""
var pack: ContentPack
var pack_repository: ContentProjectRepository
var repository: GameDefinitionRepository
var entries: Array[Dictionary] = []
var definition: GameDefinition
var current_path := ""
var selected_era := -1


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	pack_root = String(launch_manager.get("active_editor_pack_root"))
	pack_source = StringName(launch_manager.get("active_editor_pack_source"))
	if pack_root.is_empty():
		status_label.text = "Не выбран project pack"
		return
	pack_repository = ContentProjectRepository.new(bool(launch_manager.get("editor_dev_mode")))
	pack = pack_repository.load_pack(pack_root)
	repository = GameDefinitionRepository.new(pack_root)
	_setup_static_options()
	_connect_ui()
	_load_pack_fields()
	_refresh_games()


func _setup_static_options() -> void:
	clock_option.clear()
	for clock_id: StringName in [&"realtime_pauseable", &"realtime", &"turn_based"]:
		clock_option.add_item(String(clock_id))
		clock_option.set_item_metadata(clock_option.item_count - 1, clock_id)
	map_option.clear()
	var index := ContentIndex.new()
	index.rebuild()
	for entry in index.map_entries():
		map_option.add_item("%s · %s" % [entry.name, entry.runtime_key])
		map_option.set_item_metadata(map_option.item_count - 1, entry.runtime_key)


func _connect_ui() -> void:
	%BackButton.pressed.connect(func(): get_node("/root/GameLaunchManager").call("return_to_editor_hub"))
	%SavePackButton.pressed.connect(_save_pack)
	%NewGameButton.pressed.connect(new_game_dialog.popup_centered)
	new_game_dialog.confirmed.connect(_new_game)
	%SaveGameButton.pressed.connect(_save_game)
	%TestGameButton.pressed.connect(_test_game)
	game_list.item_selected.connect(_select_game)
	%AddEraButton.pressed.connect(_add_era)
	%RemoveEraButton.pressed.connect(_remove_era)
	era_list.item_selected.connect(_select_era)
	modules_edit.text_changed.connect(func(_value: String): _refresh_module_panels())
	for field: LineEdit in [game_id_edit, input_edit, layout_edit, era_id_edit, new_game_id_edit]:
		field.text_changed.connect(_sanitize_id.bind(field))


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


func _refresh_games() -> void:
	entries = repository.list_definitions()
	game_list.clear()
	for entry: Dictionary in entries:
		game_list.add_item("%s · %s" % [entry.name, entry.id])
	if not entries.is_empty():
		game_list.select(0)
		_select_game(0)


func _select_game(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	definition = repository.load(entries[index].path)
	current_path = entries[index].path
	_sync_definition_to_ui()


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
	_sync_definition_to_ui()


func _sync_definition_to_ui() -> void:
	if definition == null:
		return
	game_id_edit.text = String(definition.id)
	game_name_edit.text = definition.name
	game_description_edit.text = definition.description
	modules_edit.text = ", ".join(definition.module_ids.map(func(value: StringName) -> String: return String(value)))
	_select_option_metadata(map_option, definition.default_map)
	_select_option_metadata(clock_option, definition.clock_id)
	input_edit.text = String(definition.input_profile)
	layout_edit.text = String(definition.ui_layout)
	var settlement: Dictionary = definition.start_module_parameters.get(&"gth.settlement", {})
	biome_edit.text = String(settlement.get("biome", "summer_valley"))
	money_spin.value = int(settlement.get("starting_money", 500))
	wellbeing_spin.value = int(settlement.get("starting_wellbeing", 75))
	population_spin.value = int(settlement.get("starting_population", 4))
	_refresh_module_panels()
	_refresh_eras()


func _collect_definition_from_ui() -> bool:
	_commit_era_fields()
	definition.id = StringName(ContentId.normalize_id(game_id_edit.text))
	definition.name = game_name_edit.text.strip_edges()
	definition.description = game_description_edit.text.strip_edges()
	definition.pack_id = pack.id
	definition.module_ids.clear()
	for raw: String in modules_edit.text.split(",", false):
		var module_id := raw.strip_edges()
		if not module_id.is_empty():
			definition.module_ids.append(StringName(module_id))
	if map_option.selected >= 0:
		definition.default_map = map_option.get_item_metadata(map_option.selected)
	definition.clock_id = clock_option.get_item_metadata(clock_option.selected)
	definition.input_profile = StringName(ContentId.normalize_id(input_edit.text))
	definition.ui_layout = StringName(ContentId.normalize_id(layout_edit.text))
	definition.start_module_parameters.clear()
	if &"gth.settlement" in definition.module_ids:
		definition.start_module_parameters[&"gth.settlement"] = {
			"biome": biome_edit.text.strip_edges(),
			"starting_money": int(money_spin.value),
			"starting_wellbeing": int(wellbeing_spin.value),
			"starting_population": int(population_spin.value),
		}
	var parsed_technologies: Variant = JSON.parse_string(technologies_edit.text)
	if not parsed_technologies is Dictionary:
		status_label.text = "Технологии должны быть JSON-объектом"
		return false
	definition.progression.technologies = (parsed_technologies as Dictionary).duplicate(true)
	return true


func _save_game() -> bool:
	if definition == null:
		return false
	if not _collect_definition_from_ui():
		return false
	var saved := repository.save(definition, current_path)
	status_label.text = "Игра сохранена: %s" % saved if not saved.is_empty() else repository.last_error
	if saved.is_empty():
		return false
	current_path = saved
	_refresh_games()
	return true


func _test_game() -> void:
	if not _save_game():
		return
	var key := ContentId.runtime_key(pack_source, definition.id)
	get_node("/root/GameLaunchManager").call("launch_game_definition", key, definition.default_map)


func _refresh_module_panels() -> void:
	var module_ids: Array[String] = []
	for value: String in modules_edit.text.split(",", false):
		module_ids.append(value.strip_edges())
	settlement_panel.visible = module_ids.has("gth.settlement")


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
	_refresh_eras()
	era_list.select(definition.progression.eras.size() - 1)
	_select_era(definition.progression.eras.size() - 1)


func _remove_era() -> void:
	if definition == null or selected_era < 0:
		return
	definition.progression.eras.remove_at(selected_era)
	_refresh_eras()


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
