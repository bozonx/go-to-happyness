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
var _search_edit: LineEdit = null
var _recent_label: Label = null
var _recent_container: HFlowContainer = null
var _asset_container: VBoxContainer = null
var _snap_buttons: Dictionary = {}
var _asset_buttons: Dictionary = {}
var _recent_buttons: Dictionary = {}
var _recent_assets: Array[StringName] = []
var _expanded_categories: Dictionary = {}
var _expanded_group: StringName = &""


func setup(controller: Node, editor: Node) -> void:
	_controller = controller
	_search_edit = editor.get_node("%DecorSearchEdit")
	_recent_label = editor.get_node("%DecorRecentLbl")
	_recent_container = editor.get_node("%DecorRecentContainer")
	_asset_container = editor.get_node("%DecorAssetContainer")

	_search_edit.text_changed.connect(_on_search_changed)

	_build_snap_options(editor)


func activate() -> void:
	if _expanded_group.is_empty():
		for group_id in FurnishingAssetCatalogScript.GROUPS.keys():
			if _controller.current_category in FurnishingAssetCatalogScript.categories_in_group(group_id):
				_expanded_group = group_id
				break
	_rebuild_asset_buttons()
	_rebuild_recent_assets()


func _build_snap_options(editor: Node) -> void:
	_snap_buttons = {1.0: editor.get_node("%DecorSnap1Btn"), 0.5: editor.get_node("%DecorSnapHalfBtn"), 0.25: editor.get_node("%DecorSnapQuarterBtn")}
	for step in _snap_buttons.keys():
		(_snap_buttons[step] as Button).pressed.connect(_select_snap_step.bind(float(step)))


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
	for group_id in FurnishingAssetCatalogScript.GROUPS.keys():
		var group_box := VBoxContainer.new()
		var group_header := Button.new()
		group_header.flat = true
		group_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var group_expanded: bool = group_id == _expanded_group
		group_header.text = ("▾ " if group_expanded else "▸ ") + String(FurnishingAssetCatalogScript.GROUPS[group_id])
		group_header.pressed.connect(_toggle_catalog_group.bind(group_id))
		group_box.add_child(group_header)
		if not group_expanded:
			_asset_container.add_child(group_box)
			continue
		for category_id in FurnishingAssetCatalogScript.categories_in_group(group_id):
			var assets := FurnishingAssetCatalogScript.get_assets_by_category(category_id)
			if not search_text.is_empty():
				var all_set: Dictionary = {}
				for a in all_assets:
					all_set[a] = true
				assets = assets.filter(func(asset): return all_set.has(asset))
			var header := Button.new()
			header.flat = true
			header.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var expanded := bool(_expanded_categories.get(category_id, category_id == _controller.current_category))
			header.text = ("▾ " if expanded else "▸ ") + "%s (%d)" % [FurnishingAssetCatalogScript.category_display_name(category_id), assets.size()]
			header.disabled = assets.is_empty()
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
	if all_assets.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Ничего не найдено." if not search_text.is_empty() else "В каталоге пока нет ассетов."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.4))
		_asset_container.add_child(empty_label)
		if search_text.is_empty():
			_controller.current_asset_id = &""
	_controller.refresh_ghost()


func _toggle_catalog_group(group_id: StringName) -> void:
	# The inline catalog is a true accordion: exactly one group stays open.
	_expanded_group = group_id
	_controller.current_group = group_id
	_rebuild_asset_buttons()


func _toggle_catalog_category(category_id: StringName) -> void:
	_expanded_categories[category_id] = not bool(_expanded_categories.get(category_id, category_id == _controller.current_category))
	_controller.current_category = category_id
	_rebuild_asset_buttons()


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
