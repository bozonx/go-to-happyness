class_name DecorCatalogPanel
extends RefCounted

## Catalog sub-panel of decor mode: one-level-at-a-time browse navigation,
## search, tag filters, recent assets, and snap-step selection. Extracted from
## DecorModeController to isolate catalog UI building from placement and
## inspector logic.
##
## State (current_asset_id, current_category, etc.) stays on the controller
## so tests and external code can still read/write it directly.

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")

const RECENT_ASSET_LIMIT := 6

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


func setup(controller: Node, editor: Node) -> void:
	_controller = controller
	_search_edit = editor.get_node("%DecorSearchEdit")
	_recent_label = editor.get_node("%DecorRecentLbl")
	_recent_container = editor.get_node("%DecorRecentContainer")
	_asset_container = editor.get_node("%DecorAssetContainer")
	_back_button = editor.get_node("%DecorCatalogBackBtn")
	_location_label = editor.get_node("%DecorCatalogLocation")
	_tag_filter_toggle = editor.get_node("%DecorTagFilterToggle")
	_tag_filters = editor.get_node("%DecorTagFilters")

	_search_edit.text_changed.connect(_on_search_changed)
	_back_button.pressed.connect(_go_back)
	_tag_filter_toggle.pressed.connect(_toggle_tag_filters)

	_build_snap_options(editor)


func activate() -> void:
	_rebuild_tag_filters()
	_rebuild_asset_buttons()
	_rebuild_recent_assets()


func _build_snap_options(editor: Node) -> void:
	_snap_buttons = {1.0: editor.get_node("%DecorSnap1Btn"), 0.5: editor.get_node("%DecorSnapHalfBtn"), 0.25: editor.get_node("%DecorSnapQuarterBtn")}
	for step in _snap_buttons.keys():
		(_snap_buttons[step] as Button).pressed.connect(_select_snap_step.bind(float(step)))


## Browse one catalog level at a time. Search and tag filtering intentionally
## replace the hierarchy with a flat result list: neither is a third accordion.
func _rebuild_asset_buttons() -> void:
	for child in _asset_container.get_children():
		child.queue_free()
	_asset_buttons.clear()

	var search_text := _search_edit.text.strip_edges().to_lower() if _search_edit != null else ""
	var filtering := not search_text.is_empty() or not _active_tag.is_empty()
	if filtering:
		_location_label.text = "Результаты поиска"
		_back_button.visible = false
		_add_asset_buttons(_filtered_assets(search_text), true)
	elif _opened_category != &"":
		_location_label.text = FurnishingAssetCatalogScript.category_display_name(_opened_category)
		_back_button.visible = true
		_add_asset_buttons(FurnishingAssetCatalogScript.get_assets_by_category(_opened_category))
	elif _opened_group != &"":
		_location_label.text = String(FurnishingAssetCatalogScript.GROUPS[_opened_group])
		_back_button.visible = true
		_add_category_buttons(_opened_group)
	else:
		_location_label.text = "Все группы"
		_back_button.visible = false
		_add_group_buttons()
	if _asset_buttons.is_empty() and filtering:
		var empty_label := Label.new()
		empty_label.text = "Ничего не найдено."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
		_asset_container.add_child(empty_label)
	_controller.refresh_ghost()


func _add_group_buttons() -> void:
	var counts := FurnishingAssetCatalogScript.category_counts()
	for group_id in FurnishingAssetCatalogScript.GROUPS.keys():
		var count := 0
		for category_id in FurnishingAssetCatalogScript.categories_in_group(group_id):
			count += int(counts.get(category_id, 0))
		var button := _make_browse_button("%s (%d)" % [FurnishingAssetCatalogScript.GROUPS[group_id], count])
		button.pressed.connect(_open_group.bind(group_id))
		_asset_container.add_child(button)


func _add_category_buttons(group_id: StringName) -> void:
	var counts := FurnishingAssetCatalogScript.category_counts()
	for category_id in FurnishingAssetCatalogScript.categories_in_group(group_id):
		var count := int(counts.get(category_id, 0))
		var button := _make_browse_button("%s (%d)" % [FurnishingAssetCatalogScript.category_display_name(category_id), count])
		button.disabled = count == 0
		button.tooltip_text = "Скоро появится" if count == 0 else ""
		button.pressed.connect(_open_category.bind(category_id))
		_asset_container.add_child(button)


func _add_asset_buttons(assets: Array, show_category: bool = false) -> void:
	for asset in assets:
		var button := Button.new()
		button.toggle_mode = true
		button.text = asset.name
		if show_category:
			button.text += "  ·  " + FurnishingAssetCatalogScript.category_display_name(asset.category)
		button.tooltip_text = _asset_tooltip(asset)
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.button_pressed = asset.id == _controller.current_asset_id
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
	_controller.current_group = group_id
	_rebuild_asset_buttons()


func _open_category(category_id: StringName) -> void:
	_opened_category = category_id
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
	for asset in FurnishingAssetCatalogScript.get_all_assets():
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
	for child in _tag_filters.get_children():
		child.queue_free()
	var all_button := Button.new()
	all_button.text = "Все теги"
	all_button.toggle_mode = true
	all_button.button_pressed = _active_tag.is_empty()
	all_button.pressed.connect(_select_tag.bind(StringName("")))
	_tag_filters.add_child(all_button)
	for tag in FurnishingAssetCatalogScript.all_tags():
		var button := Button.new()
		button.text = String(tag)
		button.toggle_mode = true
		button.button_pressed = tag == _active_tag
		button.pressed.connect(_select_tag.bind(tag))
		_tag_filters.add_child(button)
	_tag_filters.visible = _tag_filters_visible
	_tag_filter_toggle.text = "Теги: %s ▾" % _active_tag if not _active_tag.is_empty() else "Теги ▾"


func _select_tag(tag: StringName) -> void:
	_active_tag = tag
	_rebuild_tag_filters()
	_rebuild_asset_buttons()


func _toggle_tag_filters() -> void:
	_tag_filters_visible = not _tag_filters_visible
	_tag_filters.visible = _tag_filters_visible


func _select_asset(asset_id: StringName) -> void:
	select_asset(asset_id)


## Chooses an asset as a placement brush.  This is also used by the scene
## eyedropper, so catalog and shortcut selection always leave identical UI.
func select_asset(asset_id: StringName) -> void:
	_controller.current_asset_id = asset_id
	for id in _asset_buttons.keys():
		(_asset_buttons[id] as Button).button_pressed = id == asset_id
	for id in _recent_buttons.keys():
		(_recent_buttons[id] as Button).button_pressed = id == asset_id
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	if asset != null:
		_select_snap_step(asset.default_snap_step)
		add_recent_asset(asset_id)
	_controller.refresh_ghost()


func clear_asset_selection() -> void:
	_controller.current_asset_id = &""
	for button in _asset_buttons.values():
		(button as Button).button_pressed = false
	for button in _recent_buttons.values():
		(button as Button).button_pressed = false
	_controller.refresh_ghost()


func _on_search_changed(_new_text: String) -> void:
	_rebuild_asset_buttons()


## Track recently used assets for quick access.
func add_recent_asset(asset_id: StringName) -> void:
	_recent_assets.erase(asset_id)
	_recent_assets.push_front(asset_id)
	if _recent_assets.size() > RECENT_ASSET_LIMIT:
		_recent_assets.resize(RECENT_ASSET_LIMIT)
	_rebuild_recent_assets()


## Rebuild the recently-used asset buttons row.
func _rebuild_recent_assets() -> void:
	for child in _recent_container.get_children():
		child.queue_free()
	_recent_buttons.clear()
	if _recent_assets.is_empty():
		_recent_label.visible = false
		return
	_recent_label.visible = true
	for asset_id in _recent_assets:
		var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
		if asset == null:
			continue
		var button := Button.new()
		button.text = asset.name
		button.tooltip_text = asset.description
		button.custom_minimum_size = Vector2(80, 0)
		button.clip_text = true
		button.toggle_mode = true
		button.button_pressed = asset_id == _controller.current_asset_id
		button.pressed.connect(_select_asset.bind(asset_id))
		_recent_container.add_child(button)
		_recent_buttons[asset_id] = button


func _select_snap_step(step: float) -> void:
	if not _snap_buttons.has(step):
		return
	_controller.current_snap_step = step
	for snap_step in _snap_buttons.keys():
		(_snap_buttons[snap_step] as Button).button_pressed = is_equal_approx(float(snap_step), step)
	_controller.refresh_ghost()
