class_name DecorCatalogPanel
extends RefCounted

## Catalog sub-panel of decor mode: groups, categories, asset buttons, search,
## recent assets, and snap-step selection. Extracted from DecorModeController
## to isolate catalog UI building from placement and inspector logic.
##
## State (current_asset_id, current_category, etc.) stays on the controller
## so tests and external code can still read/write it directly.

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")

const RECENT_ASSET_LIMIT := 6

var _controller: Node = null
var _group_option: OptionButton = null
var _category_option: OptionButton = null
var _search_edit: LineEdit = null
var _recent_label: Label = null
var _recent_container: HFlowContainer = null
var _asset_container: VBoxContainer = null
var _asset_hint: Label = null
var _snap_buttons: Dictionary = {}
var _asset_buttons: Dictionary = {}
var _recent_buttons: Dictionary = {}
var _recent_assets: Array[StringName] = []
var _expanded_categories: Dictionary = {}


func setup(controller: Node, editor: Node) -> void:
	_controller = controller
	_group_option = editor.get_node("%DecorGroupOption")
	_category_option = editor.get_node("%DecorCategoryOption")
	_search_edit = editor.get_node("%DecorSearchEdit")
	_recent_label = editor.get_node("%DecorRecentLbl")
	_recent_container = editor.get_node("%DecorRecentContainer")
	_asset_container = editor.get_node("%DecorAssetContainer")
	_asset_hint = editor.get_node("%DecorAssetHint")

	_category_option.item_selected.connect(_on_category_selected)
	_group_option.item_selected.connect(_on_group_selected)
	_search_edit.text_changed.connect(_on_search_changed)

	_build_group_options()
	_build_snap_options(editor)


func activate() -> void:
	_rebuild_category_options()
	_rebuild_asset_buttons()
	_rebuild_recent_assets()


func _build_group_options() -> void:
	_group_option.clear()
	_group_option.add_item("Все группы")
	_group_option.set_item_metadata(0, &"")
	for group_id in FurnishingAssetCatalogScript.GROUPS.keys():
		_group_option.add_item(String(FurnishingAssetCatalogScript.GROUPS[group_id]))
		_group_option.set_item_metadata(_group_option.item_count - 1, group_id)
	_group_option.select(0)


func _build_snap_options(editor: Node) -> void:
	_snap_buttons = {1.0: editor.get_node("%DecorSnap1Btn"), 0.5: editor.get_node("%DecorSnapHalfBtn"), 0.25: editor.get_node("%DecorSnapQuarterBtn")}
	for step in _snap_buttons.keys():
		(_snap_buttons[step] as Button).pressed.connect(_select_snap_step.bind(float(step)))


func _on_group_selected(index: int) -> void:
	_controller.current_group = _group_option.get_item_metadata(index)
	_rebuild_category_options()
	_rebuild_asset_buttons()


func _rebuild_category_options() -> void:
	var counts := FurnishingAssetCatalogScript.category_counts()
	_category_option.clear()
	var selected_index := -1
	for category_id in FurnishingAssetCatalogScript.categories_in_group(_controller.current_group):
		var count := int(counts.get(category_id, 0))
		_category_option.add_item("%s (%d)" % [FurnishingAssetCatalogScript.category_display_name(category_id), count])
		var item_index := _category_option.item_count - 1
		_category_option.set_item_metadata(item_index, category_id)
		# Empty categories stay listed (they document what is planned) but cannot
		# be selected into a blank asset list.
		_category_option.set_item_disabled(item_index, count == 0)
		if category_id == _controller.current_category:
			selected_index = item_index
	if selected_index < 0:
		_controller.current_category = FurnishingAssetCatalogScript.first_populated_category(_controller.current_category)
		for i in _category_option.item_count:
			if _category_option.get_item_metadata(i) == _controller.current_category:
				selected_index = i
				break
	if selected_index >= 0:
		_category_option.select(selected_index)


func _on_category_selected(index: int) -> void:
	_controller.current_category = _category_option.get_item_metadata(index)
	_rebuild_asset_buttons()


## One toggle button per asset, mirroring the frame palette, instead of a second
## dropdown: the author sees every option at once.
## When the search field is non-empty, assets are filtered by name/description.
func _rebuild_asset_buttons() -> void:
	for child in _asset_container.get_children():
		child.queue_free()
	_asset_buttons.clear()

	var search_text := _search_edit.text.strip_edges().to_lower() if _search_edit != null else ""
	var all_assets := FurnishingAssetCatalogScript.get_all_assets()
	if not search_text.is_empty():
		var filtered: Array = []
		for asset in all_assets:
			if String(asset.name).to_lower().contains(search_text) or String(asset.description).to_lower().contains(search_text):
				filtered.append(asset)
		all_assets = filtered
	if all_assets.is_empty():
		var empty_label := Label.new()
		if not search_text.is_empty():
			empty_label.text = "Ничего не найдено."
		else:
			empty_label.text = "В этой категории пока нет ассетов."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
		_asset_container.add_child(empty_label)
		if search_text.is_empty():
			_controller.current_asset_id = &""
			_asset_hint.text = ""
		_controller.refresh_ghost()
		return

	var keep_selection := false
	for asset in all_assets:
		if asset.id == _controller.current_asset_id:
			keep_selection = true
	if not keep_selection:
		_controller.current_asset_id = all_assets[0].id
	for group_id in FurnishingAssetCatalogScript.GROUPS.keys():
		var group_box := VBoxContainer.new()
		var group_title := Label.new()
		group_title.text = String(FurnishingAssetCatalogScript.GROUPS[group_id])
		group_title.add_theme_font_size_override("font_size", 15)
		group_box.add_child(group_title)
		for category_id in FurnishingAssetCatalogScript.categories_in_group(group_id):
			var assets := FurnishingAssetCatalogScript.get_assets_by_category(category_id)
			if not search_text.is_empty():
				assets = assets.filter(func(asset): return asset in all_assets)
			var header := Button.new()
			header.flat = true
			header.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var expanded := bool(_expanded_categories.get(category_id, category_id == _controller.current_category or not search_text.is_empty()))
			header.text = ("▾ " if expanded else "▸ ") + "%s (%d)" % [FurnishingAssetCatalogScript.category_display_name(category_id), assets.size()]
			header.disabled = assets.is_empty() and search_text.is_empty()
			header.pressed.connect(_toggle_catalog_category.bind(category_id))
			group_box.add_child(header)
			if expanded:
				for asset in assets:
					var button := Button.new()
					button.toggle_mode = true
					button.text = "    " + asset.name
					button.tooltip_text = asset.description
					button.clip_text = true
					button.alignment = HORIZONTAL_ALIGNMENT_LEFT
					button.button_pressed = asset.id == _controller.current_asset_id
					button.pressed.connect(_select_asset.bind(asset.id))
					group_box.add_child(button)
					_asset_buttons[asset.id] = button
		_asset_container.add_child(group_box)
	_update_asset_hint()
	_controller.refresh_ghost()


func _toggle_catalog_category(category_id: StringName) -> void:
	_expanded_categories[category_id] = not bool(_expanded_categories.get(category_id, category_id == _controller.current_category))
	_controller.current_category = category_id
	_rebuild_asset_buttons()


func _select_asset(asset_id: StringName) -> void:
	_controller.current_asset_id = asset_id
	for id in _asset_buttons.keys():
		(_asset_buttons[id] as Button).button_pressed = id == asset_id
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	if asset != null:
		_select_snap_step(asset.default_snap_step)
	_add_recent_asset(asset_id)
	_update_asset_hint()
	_controller.refresh_ghost()


func _on_search_changed(_new_text: String) -> void:
	_rebuild_asset_buttons()


## Track recently used assets for quick access.
func _add_recent_asset(asset_id: StringName) -> void:
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


func _update_asset_hint() -> void:
	var asset := FurnishingAssetCatalogScript.get_asset(_controller.current_asset_id)
	if asset == null:
		_asset_hint.text = ""
		return
	var size := asset.footprint_m()
	_asset_hint.text = "%s\nРазмер: %.2f×%.2f×%.2f м" % [asset.description, size.x, size.y, size.z]


func _select_snap_step(step: float) -> void:
	if not _snap_buttons.has(step):
		return
	_controller.current_snap_step = step
	for snap_step in _snap_buttons.keys():
		(_snap_buttons[snap_step] as Button).button_pressed = is_equal_approx(float(snap_step), step)
	_controller.refresh_ghost()
