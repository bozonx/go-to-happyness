extends SceneTree

## End-to-end test of the editor.s fill mode against the real scene: mode
## switching, snapping, the click path, selection, dragging, property bindings,
## undo and save/load.
##
## It drives BuildingEditor + BuildingFillModeController the way the UI does, which is
## what the previous unit-only coverage missed — fill mode could not place a
## single object while every catalog assertion still passed.

const EditorScene = preload("res://game/features/buildings/presentation/editor/building_editor.tscn")
const FillObjectRecordScript = preload("res://game/features/buildings/domain/editor/fill_object_record.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")


func _initialize() -> void:
	# The scene tree is not up during `_init`, so defer until it is.
	call_deferred("_run")


func _run() -> void:
	print("--- Running test_fill_mode_editor.gd ---")
	var editor := EditorScene.instantiate()
	root.add_child(editor)
	await process_frame

	var fill = editor.fill_mode
	assert(fill != null, "controller exists")
	var top_bar := editor.get_node("EditorUI/Root/TopBar") as Control
	var top_scroll := editor.get_node("EditorUI/Root/TopBar/Margin/Scroll") as ScrollContainer
	var palette := editor.get_node("%FillPanel") as Control
	var inspector := editor.get_node("%FillInspectorPanel") as Control
	assert(top_bar.get_combined_minimum_size().y <= 55.0, "building top bar keeps its compact height")
	assert(top_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
		"building top bar preserves access to overflowing actions")
	assert(palette.custom_minimum_size.x + inspector.custom_minimum_size.x + 16.0 <= 1280.0,
		"building palettes and inspector fit the supported 1280 px viewport")
	assert(inspector.custom_minimum_size.x <= 280.0, "fill inspector stays compact")
	editor._orbiting = true
	editor._release_pointer_capture(MOUSE_BUTTON_RIGHT)
	assert(not editor._orbiting, "release over UI ends camera orbit")
	editor._panning = true
	editor._release_pointer_capture(MOUSE_BUTTON_MIDDLE)
	assert(not editor._panning, "release over UI ends camera pan")

	# Keyboard events must reach the shared router. This catches an indentation
	# regression that disabled Z/X/C and Esc in every ordinary editor mode.
	editor.frame_mode.select_block(&"cube", &"1")
	editor.current_rot = 0
	editor._unhandled_input(_key(KEY_C))
	assert(editor.current_rot == 1, "C rotates the frame brush through real input routing")
	editor._unhandled_input(_key(KEY_ESCAPE))
	assert(editor.current_block_id.is_empty(), "Esc clears the frame brush through real input routing")

	# The parameters window owns both mouse and keyboard while open. The editor's
	# polled camera path and its 3D ghosts must be suspended as well.
	editor.frame_mode.select_block(&"cube", &"1")
	editor.cursor_valid = true
	editor.frame_mode.refresh_ghost()
	assert(editor.get_node("%Ghost").visible, "frame ghost visible before opening parameters")
	editor.frame_mode.sync_metadata_fields()
	editor.frame_mode.refresh_cost_ui()
	editor._suspend_viewport_interaction()
	editor._metadata_panel.show()
	assert(editor._metadata_panel.visible and editor._metadata_panel.exclusive,
		"building parameters are an exclusive modal")
	var rotation_while_modal: int = editor.current_rot
	editor._unhandled_input(_key(KEY_C))
	editor._process(0.016)
	assert(editor.current_rot == rotation_while_modal, "editor shortcuts are blocked by the parameters modal")
	assert(not editor.get_node("%Ghost").visible, "frame ghost hides behind the parameters modal")
	editor._metadata_panel.hide()
	editor.frame_mode.clear_block_selection()

	# Shared schema inspector debounces each field independently and cancels
	# timers when selection rebuilds its controls.
	var common_inspector := EditorPropertyInspector.new()
	root.add_child(common_inspector)
	var commits: Array[StringName] = []
	common_inspector.property_committed.connect(func(property_name: StringName, _value: Variant) -> void:
		commits.append(property_name))
	common_inspector.queue_commit(&"first", 1)
	common_inspector.queue_commit(&"second", 2)
	await create_timer(EditorPropertyInspector.COMMIT_DEBOUNCE_SEC + 0.05).timeout
	assert(commits == [&"first", &"second"], "independent inspector fields both commit")
	common_inspector.queue_commit(&"stale", 3)
	common_inspector.set_fields([], {})
	await create_timer(EditorPropertyInspector.COMMIT_DEBOUNCE_SEC + 0.05).timeout
	assert(&"stale" not in commits, "inspector rebuild cancels stale field commits")
	common_inspector.queue_free()

	# Enter fill mode the way the UI does.
	editor.get_node("%Ghost").visible = true
	editor._select_mode(editor.EditMode.FILL)
	assert(fill.is_active(), "fill panel visible")
	assert(not editor._metadata_panel.visible, "settings dialog is not open")
	assert(editor.get_node("%FillToolbar").visible, "fill toolbar visible")
	assert(not editor.get_node("%FrameToolbar").visible, "frame toolbar hidden")
	assert(not editor.get_node("%Ghost").visible, "frame ghost hidden outside frame mode")
	var inspector_scroll := inspector.get_node("Scroll") as ScrollContainer
	var objects_panel := inspector.get_node("FillObjectsPanel") as Control
	assert(inspector_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"fill inspector has only vertical scrolling")
	assert(editor.get_node("%FillObjectList").get_parent().get_parent().get_parent() == inspector,
		"object list is a fixed lower block outside the inspector scroll")
	assert(is_equal_approx(objects_panel.size.y, 300.0), "object list block keeps a fixed height")
	assert(inspector_scroll.position.y + inspector_scroll.size.y <= objects_panel.position.y,
		"scrolling inspector and fixed object list do not overlap")
	assert(editor.get_node("%Compass") is EditorViewportCompass, "building editor uses the shared compass")
	print("  mode switch ok, asset=", fill.current_asset_id)

	# Постановка идёт по клеткам: якорь 1×1-объекта — центр клетки под курсором.
	var snapped: Vector3 = fill.snapped_position(Vector3(3.13, 0.0, -1.4), &"campfire")
	assert(snapped.is_equal_approx(Vector3(3.5, 0.0, -1.5)), "cell anchor -> %s" % snapped)
	# Половинных шагов больше нет: подстройка — это авторское смещение.
	snapped = fill.snapped_position(Vector3(3.9, 0.0, 2.1), &"campfire")
	assert(snapped.is_equal_approx(Vector3(3.5, 0.0, 2.5)), "cell anchor rounds to its own cell -> %s" % snapped)
	print("  cell snapping ok")

	# Moving above the initial document height grows it instead of imposing a
	# floor limit chosen by the editor.
	editor._set_layer(12)
	assert(editor.active_layer == 12 and editor.blueprint.grid_bounds.y == 13,
		"building height follows the author's layer")
	editor._set_layer(0)

	# Place two objects through the real click path.
	editor.cursor_valid = true
	fill.current_asset_id = &"campfire"
	editor.cursor_hit_pos = Vector3(2.2, 0.0, 2.2)
	fill.on_left_pressed()
	editor.cursor_hit_pos = Vector3(5.4, 0.0, 5.4)
	fill.current_asset_id = &"flag"
	fill.on_left_pressed()
	await process_frame
	assert(editor.blueprint.objects.size() == 2, "two objects placed, got %d" % editor.blueprint.objects.size())
	assert(fill._nodes.size() == 2, "two instances spawned")
	assert(fill.selected_object_id.is_empty(),
		"placement clears object selection consistently instead of leaving a stale selected inspector")
	print("  placement ok, ids=", editor.blueprint.objects.map(func(r): return r.id))

	# The contextual tool never stacks on an existing object: it selects it.
	editor.cursor_hit_pos = Vector3(2.2, 0.0, 2.2)
	fill.on_left_pressed()
	assert(editor.blueprint.objects.size() == 2, "placement mode must not stack fill under the cursor")
	assert(fill.selected_object_id == editor.blueprint.objects[0].id,
		"placement mode selects the object under the cursor")
	fill.refresh_ghost()
	assert(fill._ghost == null or not fill._ghost.visible, "ghost hides while the cursor is over fill")
	assert(fill._hover_marker.visible, "hover marker identifies the object a click will select")
	assert(not editor.get_node("%FillDeleteSelectionBtn").disabled, "toolbar delete enables for selection")
	print("  occupied placement selects instead of stacking")

	# The same contextual click handles selection and dragging.
	editor.cursor_hit_pos = Vector3(2.3, 0.0, 2.3)
	fill.on_left_pressed()
	assert(fill.selected_object_id == editor.blueprint.objects[0].id, "picked the campfire")
	assert(editor.get_node("%FillInspectorPanel").visible, "inspector shown")
	assert(fill._controls_vbox.get_child_count() > 0, "shared property inspector renders appearance")
	assert(editor.get_node_or_null("%FillDuplicateBtn") == null, "duplicate is not repeated in inspector")
	assert(editor.get_node_or_null("%FillDeleteBtn") == null, "delete remains in the top toolbar only")
	print("  selection ok ->", fill.selected_object_id)
	var selected_record = fill.find_record(fill.selected_object_id)
	var selected_cells: Rect2i = fill.occupied_cells(
		selected_record.anchor_pos(), selected_record.asset_id, selected_record.scale.x, selected_record.rot.y)
	fill._pos_x_spin.value = selected_cells.position.x + 1
	var after_x: Rect2i = fill.occupied_cells(
		selected_record.anchor_pos(), selected_record.asset_id, selected_record.scale.x, selected_record.rot.y)
	assert(after_x.position == selected_cells.position + Vector2i(1, 0),
		"инспектор X двигает только X выбранного объекта")
	fill._pos_z_spin.value = after_x.position.y + 1
	var after_z: Rect2i = fill.occupied_cells(
		selected_record.anchor_pos(), selected_record.asset_id, selected_record.scale.x, selected_record.rot.y)
	assert(after_z.position == selected_cells.position + Vector2i(1, 1),
		"инспектор Z двигает только Z выбранного объекта")

	# Drag it.
	var before: Vector3 = editor.blueprint.objects[0].pos
	editor.cursor_hit_pos = Vector3(4.3, 0.0, 2.3)
	fill.on_drag()
	fill.on_left_released()
	assert(editor.blueprint.objects[0].pos != before, "drag moved the object")
	print("  drag ok ", before, " -> ", editor.blueprint.objects[0].pos)

	# Properties reach the instance.
	fill._set_property("visual_flame_visible", false)
	var node = fill._nodes[fill.selected_object_id]
	assert(node.get_node("Fire").visible == false, "visual_flame_visible=false hides the flame")
	fill._set_property("light_color", "44aaff")
	assert(node.get_node("Light").light_color.is_equal_approx(Color("44aaff")), "colour binding applied")
	fill._on_appearance_property_reset(&"light_color")
	assert(editor.blueprint.objects[0].appearance["light_color"] != "44aaff", "shared reset restores asset default")
	print("  property bindings ok")

	# Пипетка вместо дублирования: она снимает полный образец, и следующий клик
	# ставит такой же объект. Отдельного «дублировать» больше нет.
	fill.select_object(editor.blueprint.objects[0].id)
	editor.cursor_hit_pos = editor.blueprint.objects[0].pos
	fill.pick_asset_at_cursor()
	editor.cursor_hit_pos = Vector3(0.4, 0.0, 7.4)
	fill.on_left_pressed()
	assert(editor.blueprint.objects.size() == 3, "пипетка + клик заменяют дублирование")
	var copy = editor.blueprint.objects[2]
	var source = editor.blueprint.objects[0]
	assert(copy.asset_id == source.asset_id and copy.appearance == source.appearance,
		"копия несёт свойства образца")
	fill.select_object(copy.id)
	fill.delete_selection()
	assert(editor.blueprint.objects.size() == 2, "deleted")
	fill.undo()
	assert(editor.blueprint.objects.size() == 3, "undo restored the delete")
	fill.redo()
	assert(editor.blueprint.objects.size() == 2, "redo re-applied the delete")
	fill.undo()
	assert(editor.blueprint.objects.size() == 3, "undo restored the delete again")
	var camera_before_undo: Dictionary = editor._camera_state()
	fill.undo()
	assert(editor.blueprint.objects.size() == 2, "undo restored the placement")
	assert(editor._camera_state() == camera_before_undo, "undo does not restore camera state")
	print("  eyedropper copy + undo/redo ok")

	# Collision overlay: toggling on builds overlays, toggling off clears them.
	fill._on_collision_overlay_toggled(true)
	assert(not fill._collision_overlay.is_empty(), "collision overlays built for blocking objects")
	fill._on_collision_overlay_toggled(false)
	assert(fill._collision_overlay.is_empty(), "collision overlays cleared on toggle off")
	print("  collision overlay ok")

	# Zone filter: create a zone, assign an object, filter by it, then delete zone.
	# Re-select first object since undo/redo may have cleared the selection.
	fill.select_object(editor.blueprint.objects[0].id)
	assert(fill.find_record(fill.selected_object_id) != null, "object re-selected before zone test")
	var zone := ZoneAreaRecord.new()
	zone.id = &"test_zone_1"
	zone.area_name = "Тестовая зона"
	zone.add_rect(Rect2i(2, 2, 1, 1))
	editor.blueprint.areas.append(zone)
	fill._refresh_zone_filter_options()
	# Assign selected object to the zone.
	fill.find_record(fill.selected_object_id).owner_zone_id = &"test_zone_1"
	fill._refresh_inspector()
	assert(fill.find_record(fill.selected_object_id).owner_zone_id == &"test_zone_1", "object assigned to zone")
	# Filter object list by zone — should show only 1 object.
	fill._zone_filter_option.select(1)
	fill._on_zone_filter_selected(1)
	assert(fill._object_list.item_count() == 1, "zone filter shows only objects in zone")
	# Reset filter.
	fill._zone_filter_option.select(0)
	fill._on_zone_filter_selected(0)
	assert(fill._object_list.item_count() == 2, "all zones filter shows all objects")
	var object_search := fill._object_list.get_node("Search") as LineEdit
	var object_list_items := fill._object_list.get_node("List") as ItemList
	assert("ID:" not in object_list_items.get_item_text(0) and "этаж" in object_list_items.get_item_text(0),
		"object rows contain only the asset name and floor")
	assert(fill._format_floor_height(1.24) == "1.25" and fill._format_floor_height(2.0) == "2",
		"fractional floors are rounded to the authored height step")
	object_search.text = object_list_items.get_item_text(0).split("  ·  ")[0]
	object_search.text_changed.emit(object_search.text)
	assert(fill._object_list.item_count() == 1, "object list searches by the displayed asset name")
	object_search.text = ""
	object_search.text_changed.emit("")
	# Delete the zone — on_zone_deleted should clear owner_zone_id.
	fill.on_zone_deleted(&"test_zone_1")
	assert(fill.find_record(fill.selected_object_id).owner_zone_id == &"", "zone deletion clears owner_zone_id")
	print("  zone filter + deletion ok")

	# Replace object: compatible appearance properties must be preserved.
	# campfire and cooking_campfire both share visual_flame_visible (bool) and
	# light_energy (float). Setting non-default values on the campfire, then
	# replacing with cooking_campfire, must carry them over.
	fill.select_object(editor.blueprint.objects[0].id)
	fill._set_property("visual_flame_visible", false)
	fill._set_property("light_energy", 3.5)
	fill.current_asset_id = &"cooking_campfire"
	# Замена спрашивает подтверждение, если свойства теряются: без свободных
	# свойств этот путь не проверить, поэтому сначала убеждаемся, что он реален.
	assert(fill._lost_property_count(editor.blueprint.objects[0], WorldAssetCatalog.get_asset(&"cooking_campfire")) > 0,
		"замена campfire → cooking_campfire теряет хотя бы одно свойство")
	editor.confirm_handler = func(_message: String, _title: String) -> bool: return true
	await fill._replace_selected_object()
	assert(editor.blueprint.objects[0].asset_id == &"cooking_campfire",
		"object replaced with cooking_campfire")
	assert(editor.blueprint.objects[0].appearance.get("visual_flame_visible", null) == false,
		"visual_flame_visible must be carried over during replace")
	assert(editor.blueprint.objects[0].appearance.get("light_energy", null) == 3.5,
		"light_energy must be carried over during replace")
	print("  replace preserves appearance ok")

	# The eyedropper copies the placed asset and rotations into the placement
	# brush, then Esc first clears scene selection and then clears that brush.
	editor.cursor_hit_pos = editor.blueprint.objects[0].pos
	fill.pick_asset_at_cursor()
	assert(fill.current_asset_id == editor.blueprint.objects[0].asset_id, "fill eyedropper copies asset")
	fill.select_object(editor.blueprint.objects[0].id)
	fill.cancel_current_action()
	assert(fill.selected_object_id.is_empty(), "first Esc clears fill selection")
	assert(not fill.current_asset_id.is_empty(), "first Esc keeps the placement brush")
	fill.cancel_current_action()
	assert(fill.current_asset_id.is_empty(), "second Esc clears the placement brush")

	# All rotation axes are authorable and Esc does not leave a pending drag.
	fill.current_asset_id = &"campfire"
	fill.select_object(editor.blueprint.objects[0].id)
	editor._unhandled_input(_key(KEY_X))
	editor._unhandled_input(_key(KEY_Z))
	assert(not is_zero_approx(editor.blueprint.objects[0].rot.x), "X rotation applied")
	assert(not is_zero_approx(editor.blueprint.objects[0].rot.z), "Z rotation applied")
	editor._unhandled_input(_key(KEY_ESCAPE))
	assert(fill.selected_object_id.is_empty(), "Esc clears fill selection")
	fill.select_object(editor.blueprint.objects[0].id)
	print("  multi-axis rotation + Esc ok")
	var ui_record = editor.blueprint.objects[0]
	var ui_yaw_before: float = ui_record.rot.y
	fill._yaw_spin.value = ui_yaw_before + EditorFillConventions.ROTATION_STEP_DEG
	assert(is_equal_approx(ui_record.rot.y, ui_yaw_before + EditorFillConventions.ROTATION_STEP_DEG),
		"реальный value_changed общего SpinBox применяет трансформацию")

	# Шаг поворота общий на оба редактора и не зависит от ассета.
	fill.select_object("")
	fill.current_asset_id = &"campfire"
	fill._refresh_inspector()
	fill._off_x_spin.value = 0.5
	fill._scale_spin.value = 1.2
	assert(is_equal_approx(fill.current_offset.x, 0.5), "поле смещения меняет кисть через реальный UI-сигнал")
	assert(is_equal_approx(fill.current_scale, 1.2), "поле масштаба меняет кисть через реальный UI-сигнал")
	fill.current_pitch_deg = 0.0
	fill.current_yaw_deg = 0.0
	fill.current_roll_deg = 0.0
	fill.current_offset = Vector3.ZERO
	fill.current_scale = 1.0
	fill._sync_brush_transform_fields()
	fill.rotate_selection("y", 1)
	assert(is_equal_approx(fill.current_yaw_deg, EditorFillConventions.ROTATION_STEP_DEG),
		"шаг быстрого поворота — общий, а не заданный ассетом")

	# Кисть несёт в постановку все три оси: призрак и результат совпадают.
	fill.current_asset_id = &"campfire"
	fill.current_pitch_deg = 15.0
	fill.current_yaw_deg = 30.0
	fill.current_roll_deg = 345.0
	editor.cursor_hit_pos = Vector3(1.4, 0.0, 6.4)
	var count_before: int = editor.blueprint.objects.size()
	fill.on_left_pressed()
	assert(editor.blueprint.objects.size() == count_before + 1, "объект поставлен")
	var placed = editor.blueprint.objects[editor.blueprint.objects.size() - 1]
	assert(is_equal_approx(placed.rot.x, 15.0) and is_equal_approx(placed.rot.z, 345.0),
		"постановка сохраняет поворот кисти по всем осям, а не только Y")

	# Смещение — авторская подстройка внутри своих клеток: клетка остаётся той же.
	fill.select_object(placed.id)
	var cell_before: Rect2i = fill.occupied_cells(placed.anchor_pos(), placed.asset_id, placed.scale.x, placed.rot.y)
	fill._syncing_ui = true
	fill._off_x_spin.value = 0.5
	fill._syncing_ui = false
	fill._on_transform_spin_changed(0.5)
	assert(is_equal_approx(placed.offset.x, 0.5), "смещение записано")
	assert(fill.current_offset.is_zero_approx(),
		"смещение выбранного объекта не меняет смещение кисти и фантома")
	assert(fill.occupied_cells(placed.anchor_pos(), placed.asset_id, placed.scale.x, placed.rot.y) == cell_before,
		"смещение не переселяет объект в соседнюю клетку")
	fill.reset_offset()
	assert(placed.offset.is_zero_approx(), "кнопка ↺ сбрасывает смещение")
	assert(fill.current_offset.is_zero_approx(), "сброс объекта не затрагивает кисть")

	# Множественное выделение: клетка применяется сдвигом ко всему выделению.
	fill.select_object(editor.blueprint.objects[0].id)
	fill.toggle_object_selection(placed.id)
	assert(fill.selected_object_ids().size() == 2, "Ctrl+клик набирает выделение")
	var other_pos_before: Vector3 = placed.pos
	fill._syncing_ui = true
	fill._pos_x_spin.value = fill._pos_x_spin.value + 1.0
	fill._syncing_ui = false
	fill._on_transform_spin_changed(0.0)
	assert(placed.pos.is_equal_approx(other_pos_before + Vector3(1.0, 0.0, 0.0)),
		"клетка применяется сдвигом ко всему выделению, а не абсолютом в одну клетку")
	var other_rot_before: float = placed.rot.y
	fill.rotate_selection("y", 1)
	assert(is_equal_approx(placed.rot.y, fposmod(other_rot_before + EditorFillConventions.ROTATION_STEP_DEG, 360.0)),
		"поворот применён ко всему выделению")
	var total_before: int = editor.blueprint.objects.size()
	fill.delete_selection()
	assert(editor.blueprint.objects.size() == total_before - 2, "Delete удаляет всё выделение")
	editor.undo()
	assert(editor.blueprint.objects.size() == total_before, "удаление выделения отменяется одним шагом")
	# Убираем добавленный объект, чтобы дальнейшие проверки видели те же два.
	fill.select_object(placed.id)
	fill.delete_selection()
	assert(editor.blueprint.objects.size() == 2, "тест продолжается с исходными двумя объектами")
	print("  multi-selection + brush rotation ok")

	# The same validation boundary protects placement and inspector fields from
	# frame/circulation volumes.
	editor.blueprint.blocks.append(BlueprintBlockScript.new(Vector3i(7, 0, 7), &"cube"))
	fill.current_asset_id = &"campfire"
	var blocked_before: int = editor.blueprint.objects.size()
	editor.cursor_hit_pos = Vector3(7.5, 0.0, 7.5)
	fill.on_left_pressed()
	assert(editor.blueprint.objects.size() == blocked_before, "frame volume blocks fill placement")
	fill.select_object(editor.blueprint.objects[0].id)
	var original_pos: Vector3 = editor.blueprint.objects[0].pos
	fill._syncing_ui = true
	fill._pos_x_spin.value = 7.5
	fill._pos_z_spin.value = 7.5
	fill._syncing_ui = false
	fill._on_transform_spin_changed(7.5)
	assert(editor.blueprint.objects[0].pos.is_equal_approx(original_pos), "inspector rejects frame overlap")
	editor.blueprint.blocks.clear()
	print("  frame collision validation ok")

	# Fixture edits share the fill history and deleting a visual leaves an
	# explicit, valid invisible fixture rather than a dangling reference.
	fill._add_fixture()
	assert(editor.blueprint.fixtures.size() == 1, "fixture added")
	fill._fixture_panel._on_fixture_capability_selected(1)
	assert(editor.blueprint.fixtures[0].capabilities.has(FixtureDefinition.CAP_FIRE_SOURCE) \
		and editor.blueprint.fixtures[0].capabilities.has(FixtureDefinition.CAP_COOKING_STATION),
		"fixture capability menu supports multiple services")
	fill.undo()
	assert(editor.blueprint.fixtures[0].capabilities == [FixtureDefinition.CAP_FIRE_SOURCE],
		"multi-capability edit participates in fill history")
	fill._on_fixture_visual_selected(1)
	var fixture_id: String = editor.blueprint.fixtures[0].visual_object_id
	assert(not fixture_id.is_empty(), "fixture visual linked")
	fill.select_object(fixture_id)
	fill.delete_selection()
	assert(editor.blueprint.fixtures[0].visual_object_id.is_empty(), "visual delete unlinks fixture")
	fill.undo()
	assert(editor.blueprint.fixtures[0].visual_object_id == fixture_id, "undo restores fixture link")
	fill.undo()
	assert(editor.blueprint.fixtures.is_empty(), "fixture creation and automatic visual link undo together")
	print("  fixture links + history ok")

	# Zone bounds: an object at cell centre (x=1.5) must map to cell 1 via floor,
	# not cell 2 via round. Create a zone at cell (1,0,1) and assign the object.
	var zone2 := ZoneAreaRecord.new()
	zone2.id = &"test_zone_bounds"
	zone2.area_name = "Зона проверки границ"
	zone2.add_rect(Rect2i(1, 1, 1, 1))
	editor.blueprint.areas.append(zone2)
	var bounds_obj: FillObjectRecordScript = editor.blueprint.objects[0]
	bounds_obj.pos = Vector3(1.5, 0.0, 1.5)
	bounds_obj.owner_zone_id = &"test_zone_bounds"
	fill.select_object(bounds_obj.id)
	fill._refresh_inspector()
	# _update_zone_highlight is called during _refresh_inspector.
	# With floor, position 1.5 -> cell 1, which is in the zone — no warning.
	assert(not fill._zone_out_of_bounds_label.visible,
		"Object at cell-centre 1.5 must not trigger false out-of-zone warning (floor, not round)")
	print("  zone bounds floor ok")

	# Clean up: remove the zone and revert the object.
	fill.on_zone_deleted(&"test_zone_bounds")
	editor.blueprint.areas.erase(zone2)

	# A room must be reachable, so the blueprint needs a door before it validates
	# (active_zones.md §8.1) — the fill test authors rooms, not just labels.
	var door := ZoneAnchorRecord.new()
	door.id = &"door"
	door.role = ZoneAnchorRecord.ROLE_DOOR
	door.pos = Vector3(0.5, 0.0, 0.0)
	editor.blueprint.anchors.append(door)

	# The whole thing must serialize.
	var json: String = editor.blueprint.to_json()
	assert(not json.is_empty(), "blueprint serializes")
	var reloaded = load("res://game/features/buildings/domain/editor/building_blueprint.gd").from_json(json)
	assert(editor.blueprint.validation_errors().is_empty(),
		"a fill-only blueprint must validate: %s" % [editor.blueprint.validation_errors()])
	assert(reloaded != null, "serialized blueprint is valid")
	assert(reloaded.objects.size() == 2, "objects survive save/load")
	assert(reloaded.objects[0].appearance["visual_flame_visible"] == false, "authored property survives")
	print("  save/load ok")

	# Leaving fill mode cleans up.
	editor._select_mode(editor.EditMode.FRAME)
	assert(not fill.is_active(), "fill deactivated")
	assert(not editor._metadata_panel.visible, "settings dialog stays closed outside fill mode too")
	print("--- test_fill_mode_editor.gd PASSED ---")
	quit(0)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event
