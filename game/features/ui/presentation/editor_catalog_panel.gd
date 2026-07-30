class_name EditorCatalogPanel
extends VBoxContainer

## Shared catalog panel for browsing, searching, tag filtering, and tracking recent
## assets across authoring tools (map editor fill mode, building editor decor mode).
##
## State and callbacks delegate back to the parent controller or connect to
## `asset_selected` / `snap_step_selected` signals.

signal asset_selected(asset_id: StringName)
signal snap_step_selected(step: float)

const RECENT_ASSET_LIMIT := 6

var scope: StringName = WorldAssetDef.SCOPE_BUILDING

var _controller: Node = null
var _search_edit: LineEdit = null
var _recent_label: Label = null
var _recent_container: HFlowContainer = null
var _asset_container: VBoxContainer = null
var _back_button: Button = null
var _location_label: Label = null
var _tag_filter_toggle: Button = null
var _tag_filters: HFlowContainer = null
var _snap_buttons: Dictionary = {}
var _asset_buttons: Dictionary = {}
var _recent_buttons: Dictionary = {}
var _recent_assets: Array[StringName] = []
var _opened_group: StringName = &""
var _opened_category: StringName = &""
var _active_tag: StringName = &""
var _tag_filters_visible := false
var _selected_asset_id: StringName = &""


func setup(controller: Object, editor: Node = null, p_scope: StringName = WorldAssetDef.SCOPE_BUILDING) -> void:
	_controller = controller
	scope = p_scope

	if editor != null and editor.has_node("%DecorSearchEdit"):
		_search_edit = editor.get_node("%DecorSearchEdit")
		_recent_label = editor.get_node("%DecorRecentLbl")
		_recent_container = editor.get_node("%DecorRecentContainer")
		_asset_container = editor.get_node("%DecorAssetContainer")
		_back_button = editor.get_node("%DecorCatalogBackBtn")
		_location_label = editor.get_node("%DecorCatalogLocation")
		_tag_filter_toggle = editor.get_node("%DecorTagFilterToggle")
		_tag_filters = editor.get_node("%DecorTagFilters")
		_build_snap_options(editor)
	else:
		_build_dynamic_ui()

	if _search_edit != null and not _search_edit.text_changed.is_connected(_on_search_changed):
		_search_edit.text_changed.connect(_on_search_changed)
	if _back_button != null and not _back_button.pressed.is_connected(_go_back):
		_back_button.pressed.connect(_go_back)
	if _tag_filter_toggle != null and not _tag_filter_toggle.pressed.is_connected(_toggle_tag_filters):
		_tag_filter_toggle.pressed.connect(_toggle_tag_filters)


func _build_dynamic_ui() -> void:
	for child in get_children():
		child.queue_free()

	add_theme_constant_override("separation", 6)

	_recent_label = Label.new()
	_recent_label.text = "Недавно использованные:"
	_recent_label.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72, 1))
	_recent_label.add_theme_font_size_override("font_size", 12)
	add_child(_recent_label)

	_recent_container = HFlowContainer.new()
	_recent_container.add_theme_constant_override("h_separation", 3)
	_recent_container.add_theme_constant_override("v_separation", 3)
	add_child(_recent_container)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Поиск ассета во всех категориях..."
	_search_edit.clear_button_enabled = true
	add_child(_search_edit)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)

	_back_button = Button.new()
	_back_button.flat = true
	_back_button.text = "‹ Назад"
	_back_button.visible = false
	nav.add_child(_back_button)

	_location_label = Label.new()
	_location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_label.text = "Все группы"
	_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(_location_label)

	_tag_filter_toggle = Button.new()
	_tag_filter_toggle.flat = true
	_tag_filter_toggle.text = "Теги ▾"
	nav.add_child(_tag_filter_toggle)

	add_child(nav)

	_tag_filters = HFlowContainer.new()
	_tag_filters.add_theme_constant_override("h_separation", 3)
	_tag_filters.add_theme_constant_override("v_separation", 3)
	_tag_filters.visible = false
	add_child(_tag_filters)

	_asset_container = VBoxContainer.new()
	_asset_container.add_theme_constant_override("separation", 3)
	add_child(_asset_container)


func set_scope(new_scope: StringName) -> void:
	scope = new_scope
	_opened_group = &""
	_opened_category = &""
	_active_tag = &""
	if is_inside_tree():
		activate()


func activate() -> void:
	_rebuild_tag_filters()
	_rebuild_asset_buttons()
	_rebuild_recent_assets()


func _build_snap_options(editor: Node) -> void:
	if editor.has_node("%DecorSnap1Btn"):
		_snap_buttons = {1.0: editor.get_node("%DecorSnap1Btn"), 0.5: editor.get_node("%DecorSnapHalfBtn"), 0.25: editor.get_node("%DecorSnapQuarterBtn")}
		for step in _snap_buttons.keys():
			(_snap_buttons[step] as Button).pressed.connect(_select_snap_step.bind(float(step)))


func _rebuild_asset_buttons() -> void:
	if _asset_container == null:
		return
	for child in _asset_container.get_children():
		child.queue_free()
	_asset_buttons.clear()

	var search_text := _search_edit.text.strip_edges().to_lower() if _search_edit != null else ""
	var filtering := not search_text.is_empty() or not _active_tag.is_empty()
	if filtering:
		if _location_label != null:
			_location_label.text = "Результаты поиска"
		if _back_button != null:
			_back_button.visible = false
		_add_asset_buttons(_filtered_assets(search_text), true)
	elif _opened_category != &"":
		if _location_label != null:
			_location_label.text = WorldAssetCatalog.category_display_name(_opened_category)
		if _back_button != null:
			_back_button.visible = true
		_add_asset_buttons(WorldAssetCatalog.get_assets_by_category(_opened_category, scope))
	elif _opened_group != &"":
		if _location_label != null:
			_location_label.text = String(WorldAssetCatalog.GROUPS.get(_opened_group, _opened_group))
		if _back_button != null:
			_back_button.visible = true
		_add_category_buttons(_opened_group)
	else:
		if _location_label != null:
			_location_label.text = "Все группы"
		if _back_button != null:
			_back_button.visible = false
		_add_group_buttons()

	if _asset_buttons.is_empty() and filtering:
		var empty_label := Label.new()
		empty_label.text = "Ничего не найдено."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
		_asset_container.add_child(empty_label)

	if _controller != null and _controller.has_method("refresh_ghost"):
		_controller.call("refresh_ghost")


func _add_group_buttons() -> void:
	var counts := WorldAssetCatalog.category_counts(scope)
	for group_id in WorldAssetCatalog.GROUPS.keys():
		var count := 0
		for category_id in WorldAssetCatalog.categories_in_group(group_id):
			count += int(counts.get(category_id, 0))
		var button := _make_browse_button("%s (%d)" % [WorldAssetCatalog.GROUPS[group_id], count])
		button.disabled = count == 0
		button.pressed.connect(_open_group.bind(group_id))
		_asset_container.add_child(button)


func _add_category_buttons(group_id: StringName) -> void:
	var counts := WorldAssetCatalog.category_counts(scope)
	for category_id in WorldAssetCatalog.categories_in_group(group_id):
		var count := int(counts.get(category_id, 0))
		var button := _make_browse_button("%s (%d)" % [WorldAssetCatalog.category_display_name(category_id), count])
		button.disabled = count == 0
		button.tooltip_text = "Скоро появится" if count == 0 else ""
		button.pressed.connect(_open_category.bind(category_id))
		_asset_container.add_child(button)


func _add_asset_buttons(assets: Array, show_category: bool = false) -> void:
	var active_id := _get_active_asset_id()
	for asset in assets:
		var button := Button.new()
		button.toggle_mode = true
		button.text = asset.name
		if show_category:
			button.text += "  ·  " + WorldAssetCatalog.category_display_name(asset.category)
		button.tooltip_text = _asset_tooltip(asset)
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.button_pressed = asset.id == active_id
		button.pressed.connect(_select_asset.bind(asset.id))
		_asset_container.add_child(button)
		_asset_buttons[asset.id] = button


func _make_browse_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	return button


func _open_group(group_id: StringName) -> void:
	_opened_group = group_id
	_opened_category = &""
	if _controller != null and "current_group" in _controller:
		_controller.current_group = group_id
	_rebuild_asset_buttons()


func _open_category(category_id: StringName) -> void:
	_opened_category = category_id
	if _controller != null and "current_category" in _controller:
		_controller.current_category = category_id
	_rebuild_asset_buttons()


func _go_back() -> void:
	if _opened_category != &"":
		_opened_category = &""
	elif _opened_group != &"":
		_opened_group = &""
	_rebuild_asset_buttons()


func _filtered_assets(search_text: String) -> Array:
	var matches: Array = []
	for asset in WorldAssetCatalog.get_all_assets(scope):
		if not _active_tag.is_empty() and not asset.tags.has(_active_tag):
			continue
		if not search_text.is_empty() and not _asset_matches_search(asset, search_text):
			continue
		matches.append(asset)
	matches.sort_custom(func(a, b) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return matches


func _asset_matches_search(asset, search_text: String) -> bool:
	if String(asset.name).to_lower().contains(search_text) or String(asset.description).to_lower().contains(search_text):
		return true
	for tag in asset.tags:
		if String(tag).to_lower().contains(search_text):
			return true
	return false


func _asset_tooltip(asset) -> String:
	var tags: Array[String] = []
	for tag in asset.tags:
		tags.append(String(tag))
	var tag_text := ", ".join(tags)
	return asset.description + ("\nТеги: " + tag_text if not tag_text.is_empty() else "")


func _rebuild_tag_filters() -> void:
	if _tag_filters == null:
		return
	for child in _tag_filters.get_children():
		child.queue_free()
	var all_button := Button.new()
	all_button.text = "Все теги"
	all_button.toggle_mode = true
	all_button.button_pressed = _active_tag.is_empty()
	all_button.pressed.connect(_select_tag.bind(StringName("")))
	_tag_filters.add_child(all_button)
	for tag in WorldAssetCatalog.all_tags(scope):
		var button := Button.new()
		button.text = String(tag)
		button.toggle_mode = true
		button.button_pressed = tag == _active_tag
		button.pressed.connect(_select_tag.bind(tag))
		_tag_filters.add_child(button)
	_tag_filters.visible = _tag_filters_visible
	if _tag_filter_toggle != null:
		_tag_filter_toggle.text = "Теги: %s ▾" % _active_tag if not _active_tag.is_empty() else "Теги ▾"


func _select_tag(tag: StringName) -> void:
	_active_tag = tag
	_rebuild_tag_filters()
	_rebuild_asset_buttons()


func _toggle_tag_filters() -> void:
	_tag_filters_visible = not _tag_filters_visible
	if _tag_filters != null:
		_tag_filters.visible = _tag_filters_visible


func _select_asset(asset_id: StringName) -> void:
	select_asset(asset_id)


func select_asset(asset_id: StringName) -> void:
	_selected_asset_id = asset_id
	if _controller != null and "current_asset_id" in _controller:
		_controller.current_asset_id = asset_id
	for id in _asset_buttons.keys():
		(_asset_buttons[id] as Button).button_pressed = id == asset_id
	for id in _recent_buttons.keys():
		(_recent_buttons[id] as Button).button_pressed = id == asset_id
	var asset := WorldAssetCatalog.get_asset(asset_id)
	if asset != null:
		_select_snap_step(asset.default_snap_step)
		add_recent_asset(asset_id)
	if _controller != null:
		if _controller.has_method("refresh_ghost"):
			_controller.call("refresh_ghost")
		if "selected_object_id" in _controller and String(_controller.selected_object_id).is_empty() and _controller.has_method("_refresh_inspector"):
			_controller.call("_refresh_inspector")
	asset_selected.emit(asset_id)


func clear_asset_selection() -> void:
	_selected_asset_id = &""
	if _controller != null and "current_asset_id" in _controller:
		_controller.current_asset_id = &""
	for button in _asset_buttons.values():
		(button as Button).button_pressed = false
	for button in _recent_buttons.values():
		(button as Button).button_pressed = false
	if _controller != null:
		if _controller.has_method("refresh_ghost"):
			_controller.call("refresh_ghost")
		if "selected_object_id" in _controller and String(_controller.selected_object_id).is_empty() and _controller.has_method("_refresh_inspector"):
			_controller.call("_refresh_inspector")


func _on_search_changed(_new_text: String) -> void:
	_rebuild_asset_buttons()


func add_recent_asset(asset_id: StringName) -> void:
	_recent_assets.erase(asset_id)
	_recent_assets.push_front(asset_id)
	if _recent_assets.size() > RECENT_ASSET_LIMIT:
		_recent_assets.resize(RECENT_ASSET_LIMIT)
	_rebuild_recent_assets()


func _rebuild_recent_assets() -> void:
	if _recent_container == null:
		return
	for child in _recent_container.get_children():
		child.queue_free()
	_recent_buttons.clear()
	if _recent_assets.is_empty():
		if _recent_label != null:
			_recent_label.visible = false
		return
	if _recent_label != null:
		_recent_label.visible = true
	var active_id := _get_active_asset_id()
	for asset_id in _recent_assets:
		var asset := WorldAssetCatalog.get_asset(asset_id)
		if asset == null:
			continue
		var button := Button.new()
		button.text = asset.name
		button.tooltip_text = asset.description
		button.custom_minimum_size = Vector2(80, 0)
		button.clip_text = true
		button.toggle_mode = true
		button.button_pressed = asset_id == active_id
		button.pressed.connect(_select_asset.bind(asset_id))
		_recent_container.add_child(button)
		_recent_buttons[asset_id] = button


func _select_snap_step(step: float) -> void:
	if _controller != null and "current_snap_step" in _controller:
		_controller.current_snap_step = step
	for snap_step in _snap_buttons.keys():
		(_snap_buttons[snap_step] as Button).button_pressed = is_equal_approx(float(snap_step), step)
	if _controller != null and _controller.has_method("refresh_ghost"):
		_controller.call("refresh_ghost")
	snap_step_selected.emit(step)


func _get_active_asset_id() -> StringName:
	if _controller != null and "current_asset_id" in _controller:
		return _controller.current_asset_id
	return _selected_asset_id
