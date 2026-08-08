class_name BuildingPlacementTool
extends RefCounted

## Placing buildings, inside the Fill mode (design_docs/engine/building_placement.md §8).
##
## There is no mode of its own: the palette, the selection, the inspector and the
## undo stack are the ones the Fill mode already has. What differs is the tool —
## because **a building edits the terrain and an object does not**, and every tree
## must not drag a cascade behind it.
##
## Everything that decides anything lives in `BuildingPlacementService`. This
## file is presentation: it turns hover into a dry run, paints the answer, and
## turns a click into one entry on the shared history. Any rule that appears here
## instead of in the service is a rule the game's own construction will not have.

const PALETTE_PREFIX := "building:"
const PALETTE_HEADER := &"placement_header"

const OPTION_MODE_MEDIAN := &"placement_median"
const OPTION_MODE_TOP := &"placement_top"
const OPTION_MODE_BOTTOM := &"placement_bottom"
const OPTION_MODE_MANUAL := &"placement_manual"
const OPTION_ROTATE := &"placement_rotate"
const OPTION_LEVEL_UP := &"placement_level_up"
const OPTION_LEVEL_DOWN := &"placement_level_down"
const OPTION_SHOW_SKIRT := &"placement_show_skirt"

const OPTION_MODES := {
	OPTION_MODE_MEDIAN: PlacementLevel.MODE_MEDIAN,
	OPTION_MODE_TOP: PlacementLevel.MODE_TOP,
	OPTION_MODE_BOTTOM: PlacementLevel.MODE_BOTTOM,
	OPTION_MODE_MANUAL: PlacementLevel.MODE_MANUAL,
}

## §8.3. Cut is blue and fill is yellow, as in `grid_terrain_system.md` §5.3; the
## two colours this document adds are the edge that gets a wall instead of a ramp,
## and the cells that end up under water.
const COLOR_CUT := Color(0.30, 0.62, 1.0, 0.55)
const COLOR_FILL := Color(1.0, 0.85, 0.25, 0.55)
const COLOR_KEEP := Color(0.55, 0.85, 0.55, 0.35)
const COLOR_BLOCKED := Color(1.0, 0.25, 0.18, 0.55)
const COLOR_CLIFF := Color(1.0, 0.5, 0.1, 0.85)
const COLOR_SUBMERGED := Color(0.35, 0.95, 1.0, 0.45)

var context: MapEditorContext = null

var _blueprint_key := ""
var _orientation := 0
var _level_mode: StringName = PlacementLevel.MODE_MEDIAN
var _manual_level := 0
var _show_skirts := true
var _selected_id: StringName = &""

var _root: Node3D = null
var _views: Dictionary = {}
var _ghost: Node3D = null
var _ghost_key := ""
var _ghost_orientation := -1
var _ghost_material: StandardMaterial3D = null
var _pad_overlay: MeshInstance3D = null
var _pad_mesh: ImmediateMesh = null
## The dry run behind what is currently drawn. Recomputed when the cursor changes
## cell, never on every frame: it runs a full cascade on a copy of the region.
var _plan: PlacementPlan = null
var _plan_cell := Vector2i(-999999, -999999)


func configure(next_context: MapEditorContext, parent: Node3D) -> void:
	context = next_context
	if _root == null or not is_instance_valid(_root):
		_root = Node3D.new()
		_root.name = "PlacementViews"
		parent.add_child(_root)
	rebuild_views()


func service() -> BuildingPlacementService:
	return context.placement_service if context != null else null


func layer() -> MapPlacementLayer:
	return context.document.placements if context != null and context.document != null else null


# --- Palette --------------------------------------------------------------------

## The blueprint group of the Fill palette (§8.1). Every installed blueprint,
## from all three content sources: a bakery assembled in the building editor is
## in the map palette at once, with no import and no conversion.
func palette_entries() -> Array:
	var entries: Array = []
	var rows: Array[Dictionary] = []
	for entry: Dictionary in BuildingBlueprintLibrary.authored_entries():
		var blueprint := BuildingBlueprintLibrary.get_blueprint(String(entry["runtime_key"]))
		if blueprint == null or blueprint.kind != &"building":
			continue
		rows.append({"key": String(entry["runtime_key"]), "name": blueprint.name})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	if rows.is_empty():
		return entries
	entries.append(MapEditorMode.PaletteEntry.header(PALETTE_HEADER, "Здания", true))
	for row: Dictionary in rows:
		entries.append(MapEditorMode.PaletteEntry.of(
			StringName(PALETTE_PREFIX + String(row["key"])), String(row["name"])))
	return entries


static func is_palette_entry(entry_id: StringName) -> bool:
	return String(entry_id).begins_with(PALETTE_PREFIX)


## Returns true when the entry belonged to this tool, so the Fill mode knows the
## click was not about an asset archetype.
func select_palette_entry(entry_id: StringName) -> bool:
	if entry_id == PALETTE_HEADER:
		return true
	if not is_palette_entry(entry_id):
		return false
	_blueprint_key = String(entry_id).trim_prefix(PALETTE_PREFIX)
	_selected_id = &""
	_invalidate_plan()
	return true


func selected_palette_entry() -> StringName:
	return StringName(PALETTE_PREFIX + _blueprint_key) if has_brush() else &""


func has_brush() -> bool:
	return service() != null and not _blueprint_key.is_empty() and blueprint() != null


func has_selection() -> bool:
	return selected_record() != null


func is_engaged() -> bool:
	return has_brush() or has_selection()


func blueprint() -> BuildingBlueprint:
	return BuildingBlueprintLibrary.get_blueprint(_blueprint_key) if not _blueprint_key.is_empty() else null


func selected_record() -> MapPlacementRecord:
	var placements := layer()
	if placements == null or service() == null:
		return null
	return placements.by_id(_selected_id)


func clear_brush() -> void:
	_blueprint_key = ""
	_invalidate_plan()
	_hide_ghost()


func deselect() -> void:
	_selected_id = &""


# --- Tool options ----------------------------------------------------------------

## §8.2: the height reference, the manual level, the orientation, the skirt
## toggle and the earthworks counter — which is what honestly shows the price of
## the chosen reference before the author confirms it.
func tool_options() -> Array:
	var options: Array = []
	if not is_engaged():
		return options
	options.append(MapEditorMode.ToolOption.header(&"placement_level_title", "Уровень площадки"))
	for option_id: StringName in OPTION_MODES:
		options.append(MapEditorMode.ToolOption.of(
			option_id, PlacementLevel.label_of(OPTION_MODES[option_id]), &"placement_modes",
			_level_mode == OPTION_MODES[option_id]))
	if _level_mode == PlacementLevel.MODE_MANUAL:
		options.append(MapEditorMode.ToolOption.of(
			OPTION_LEVEL_DOWN, "− терраса", &"placement_manual"))
		options.append(MapEditorMode.ToolOption.of(
			OPTION_LEVEL_UP, "уровень %d  +" % _manual_level, &"placement_manual"))
	options.append(MapEditorMode.ToolOption.of(
		OPTION_ROTATE, "Повернуть (C/R) — %s" % BuildingFootprint.orientation_label(_orientation)))
	options.append(MapEditorMode.ToolOption.of(
		OPTION_SHOW_SKIRT, "Показывать откосы", &"", _show_skirts))
	return options


func activate_option(option_id: StringName) -> bool:
	if OPTION_MODES.has(option_id):
		_level_mode = OPTION_MODES[option_id]
		if _level_mode == PlacementLevel.MODE_MANUAL and _plan != null:
			# Starting from where the automatic reference just landed is the only
			# starting point that does not throw away what the author was looking at.
			_manual_level = _plan.level
		_invalidate_plan()
		_apply_to_selection()
		return true
	match option_id:
		OPTION_ROTATE:
			return rotate(1)
		OPTION_LEVEL_UP:
			return nudge_manual_level(1)
		OPTION_LEVEL_DOWN:
			return nudge_manual_level(-1)
		OPTION_SHOW_SKIRT:
			_show_skirts = not _show_skirts
			return true
	return false


func rotate(direction: int) -> bool:
	if not is_engaged():
		return false
	_orientation = BuildingFootprint.normalized_orientation(_orientation + direction)
	_invalidate_plan()
	_apply_to_selection()
	return true


## PageUp/PageDown, and the two buttons beside the manual level. Only in the
## manual mode: in the others the level is derived, and a control that pretended
## otherwise would be lying.
func nudge_manual_level(steps: int) -> bool:
	if _level_mode != PlacementLevel.MODE_MANUAL:
		return false
	_manual_level += steps * PlacementLevel.TERRACE_STEP
	_invalidate_plan()
	_apply_to_selection()
	return true


# --- Input ------------------------------------------------------------------------

## LMB: place the brush, or select the building under the cursor.
func click(cell: Vector2i) -> bool:
	var record := _record_at(cell)
	if record != null:
		_selected_id = record.id
		_orientation = record.orientation
		_level_mode = record.level_mode
		_manual_level = record.level_value
		rebuild_views()
		context.set_status_message("Выбрано здание %s." % record.id)
		return true
	if not has_brush():
		return false
	return place_at(cell)


## Shift+LMB. The eyedropper takes the blueprint, the orientation AND the height
## reference from under the cursor, which is what makes a separate "duplicate"
## unnecessary (§8.4).
func pick_at(cell: Vector2i) -> bool:
	var record := _record_at(cell)
	if record == null:
		return false
	var key := BuildingBlueprintLibrary.resolve_reference(record.blueprint_ref)
	if key.is_empty():
		key = BuildingBlueprintLibrary.resolve_role(record.blueprint_role())
	if key.is_empty():
		context.set_status_message("Чертёж этого здания не установлен — пипетка ни при чём.", true)
		return false
	_blueprint_key = key
	_orientation = record.orientation
	_level_mode = record.level_mode
	_manual_level = record.level_value
	_selected_id = &""
	_invalidate_plan()
	context.set_status_message("Пипетка: чертёж, ориентация и режим высоты взяты из-под курсора.")
	return true


func erase_at(cell: Vector2i) -> bool:
	var record := _record_at(cell)
	if record == null:
		return false
	return remove(record)


func _record_at(cell: Vector2i) -> MapPlacementRecord:
	var placement_service := service()
	return placement_service.placement_at(cell) if placement_service != null else null


# --- Placing --------------------------------------------------------------------

## The whole action, as one entry on the shared stack: heights, cut-outs, the
## water that reflows behind them, the anchors that pin the pad, and the record.
## §11.1 asks for exactly this — partial undo is impossible because there is
## nothing to undo partially.
func place_at(cell: Vector2i) -> bool:
	var current := blueprint()
	if current == null:
		return false
	var origin := _origin_for(cell, current)
	var plan_result := _plan_for(origin, current)
	if not plan_result.ok:
		context.set_status_message("Здесь нельзя поставить: %s." % plan_result.reason_text(), true)
		return true
	var before := layer().to_json()
	context.set_edit_label("постановка здания")
	context.begin_capture()
	var record := service().commit(plan_result, current)
	var parts := context.end_capture()
	if record == null:
		context.set_status_message("Постановка не удалась: рельеф отказал в последний момент.", true)
		return true
	_selected_id = record.id
	_push(parts, before, "постановка здания «%s»" % current.name)
	_report_warnings(plan_result, record)
	_invalidate_plan()
	return true


func remove(record: MapPlacementRecord) -> bool:
	var before := layer().to_json()
	context.set_edit_label("снос здания")
	context.begin_capture()
	# The ground stays graded (§11.4): undo brings it back, demolition does not.
	var removed := service().release(record)
	var parts := context.end_capture()
	if not removed:
		return false
	if _selected_id == record.id:
		_selected_id = &""
	_push(parts, before, "снос здания")
	context.set_status_message("Здание снято. Рельеф остаётся спланированным.")
	return true


## Moving is a lift and a placement that KEEPS the id, in one command. The id is
## what scenario rules, quests and saves address (`map_fill_mode.md` §8.3);
## "delete and put a new one" tears those references silently.
func move_selected(origin_cell: Vector2i, orientation: int) -> bool:
	var record := selected_record()
	if record == null:
		return false
	var current := BuildingPlacementService.blueprint_of(record)
	if current == null:
		context.set_status_message("Чертёж не установлен: переносить нечего.", true)
		return false
	var plan_result := service().plan(
		current, origin_cell, orientation, _level_mode, _manual_level,
		PlacementPolicy.editor(), record.id)
	if not plan_result.ok:
		context.set_status_message("Перенос невозможен: %s." % plan_result.reason_text(), true)
		return false
	var before := layer().to_json()
	context.set_edit_label("перенос здания")
	context.begin_capture()
	service().release(record)
	var moved := service().commit(plan_result, current, record.id)
	var parts := context.end_capture()
	if moved == null:
		return false
	_selected_id = moved.id
	_push(parts, before, "перенос здания")
	_report_warnings(plan_result, moved)
	return true


## Re-places the selected building with the tool's current orientation and height
## reference. Rotating or re-levelling a standing building is a move to the same
## cell — there is no second code path that edits a pad in place.
func _apply_to_selection() -> void:
	var record := selected_record()
	if record != null:
		move_selected(record.cell, _orientation)


func _push(parts: Array[MapEditorCommand], before: Array, label: String) -> void:
	var command := MapPlacementCommand.of(context.document, before, layer().to_json(), label)
	parts.append(command)
	context.history.push(
		parts[0] if parts.size() == 1 else MapEditorCompositeCommand.of(parts, label))
	context.document.mark_dirty()
	# The ground moved under everything else on the board, and the captured
	# commits never reached the editor's usual "the document changed" path.
	context.request_document_refresh()


func _report_warnings(plan_result: PlacementPlan, record: MapPlacementRecord) -> void:
	var messages := plan_result.warnings.duplicate()
	# Entrances are checked against the published navigation field, which only
	# exists after the ground has actually moved — so this runs on the committed
	# state, not on the dry run (§7).
	messages.append_array(BuildingPlacementService.entrance_warnings(
		BuildingPlacementService.footprint_of(record), context.nav_grid, "здание %s" % record.id))
	if messages.is_empty():
		return
	context.set_status_message("Предупреждение: %s" % "; ".join(messages), true)


## The north-west cell of a footprint centred on the cursor. The author points at
## the middle of the building, which is where they think it is.
func _origin_for(cell: Vector2i, current: BuildingBlueprint) -> Vector2i:
	var span := BuildingFootprint.of(current, Vector2i.ZERO, _orientation).span()
	return cell - Vector2i(span.x / 2, span.y / 2)


func _plan_for(origin: Vector2i, current: BuildingBlueprint) -> PlacementPlan:
	return service().plan(
		current, origin, _orientation, _level_mode, _manual_level, PlacementPolicy.editor())


func _invalidate_plan() -> void:
	_plan = null
	_plan_cell = Vector2i(-999999, -999999)


# --- Views and ghost ---------------------------------------------------------------

## One node per placement, built from the blueprint's own modules — the author
## looks at the real building rather than at a box the editor invented.
func rebuild_views() -> void:
	if _root == null or not is_instance_valid(_root) or context == null or context.document == null:
		return
	for child in _root.get_children():
		if child == _ghost:
			continue
		_root.remove_child(child)
		child.queue_free()
	_views.clear()
	for record: MapPlacementRecord in layer().placements:
		var view := _build_view(record)
		if view == null:
			continue
		_root.add_child(view)
		_views[record.id] = view
		if record.id == _selected_id:
			var ring := EditorFillConventions.make_ring_marker(EditorFillConventions.COLOR_SELECTION)
			ring.position.y = 0.05
			view.add_child(ring)


func _build_view(record: MapPlacementRecord) -> Node3D:
	var view := Node3D.new()
	view.name = String(record.id)
	var current := BuildingPlacementService.blueprint_of(record)
	var footprint := BuildingPlacementService.footprint_of(record)
	view.position = _pivot_position(footprint, record.level_value)
	view.rotation_degrees.y = -90.0 * float(record.orientation)
	if current == null:
		# A map whose blueprint is not installed still has to be editable, and the
		# author has to be able to see WHERE the missing building stands (§12).
		view.add_child(_missing_marker())
		return view
	for module: Dictionary in BuildingBlueprintLibrary.modules_of(current):
		var node := BuildingBlueprints.create_module(module)
		if node != null:
			view.add_child(node)
	_disable_collision(view)
	return view


## The modules a building is made of are `StaticBody3D`s with real shapes,
## because that is what the game needs them to be. In the editor they must not be
## solid: the brush finds the hovered cell by raycasting the physics space, and a
## building that answered that ray would make the ground beside it unhoverable —
## you could no longer put a second building next to the first.
static func _disable_collision(root: Node3D) -> void:
	var targets: Array[Node] = [root]
	targets.append_array(root.find_children("*", "", true, false))
	for node: Node in targets:
		if node is CollisionObject3D:
			var body := node as CollisionObject3D
			body.collision_layer = 0
			body.collision_mask = 0
			body.input_ray_pickable = false


func _pivot_position(footprint: BuildingFootprint, level: int) -> Vector3:
	var cell_size := context.terrain.cell_size
	var span := footprint.span()
	return Vector3(
		(float(footprint.origin.x) + float(span.x) * 0.5) * cell_size,
		float(level) * TerrainGrid.HEIGHT_STEP,
		(float(footprint.origin.y) + float(span.y) * 0.5) * cell_size)


func _missing_marker() -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 1.6, 0.8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.15, 0.85)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	marker.mesh = mesh
	marker.position.y = 0.8
	return marker


## The ghost of §8.3: the building where it would stand, and under it the pad
## painted with what the merge is about to do. Computed on a copy of the region
## and never touching the document.
func refresh_ghost() -> void:
	if not has_brush() or context.brush == null or not context.brush.has_hover:
		_hide_ghost()
		return
	var current := blueprint()
	var cell := context.brush.hovered_cell
	if _record_at(cell) != null:
		# Hovering a building means "the click will select", and drawing a ghost
		# over it would be a lie about what is going to happen.
		_hide_ghost()
		return
	if cell != _plan_cell or _plan == null:
		_plan = _plan_for(_origin_for(cell, current), current)
		_plan_cell = cell
	_ensure_ghost(current)
	var footprint := _plan.footprint
	if footprint == null:
		footprint = BuildingFootprint.of(current, _origin_for(cell, current), _orientation)
	_ghost.position = _pivot_position(footprint, _plan.level)
	_ghost.rotation_degrees.y = -90.0 * float(_orientation)
	_ghost.visible = true
	_ghost_material_resource().albedo_color = EditorFillConventions.COLOR_GHOST_BLOCKED if not _plan.ok \
		else (EditorFillConventions.COLOR_GHOST_WARNING if not _plan.warnings.is_empty()
			else EditorFillConventions.COLOR_GHOST_VALID)
	_paint_pad(footprint)


func _ensure_ghost(current: BuildingBlueprint) -> void:
	if is_instance_valid(_ghost) and _ghost_key == _blueprint_key and _ghost_orientation == _orientation:
		return
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.name = "PlacementGhost"
	for module: Dictionary in BuildingBlueprintLibrary.modules_of(current):
		var node := BuildingBlueprints.create_module(module)
		if node != null:
			_ghost.add_child(node)
	_root.add_child(_ghost)
	EditorFillConventions.apply_preview_look(_ghost, _ghost_material_resource())
	_disable_collision(_ghost)
	_ghost_key = _blueprint_key
	_ghost_orientation = _orientation


func _ghost_material_resource() -> StandardMaterial3D:
	if _ghost_material == null:
		_ghost_material = EditorFillConventions.make_ghost_material()
	return _ghost_material


## The pad, cell by cell: blue where ground is cut, yellow where it is filled,
## red where the placement is refused, and an orange rim on the edges that will
## get a retaining wall instead of a ramp.
func _paint_pad(footprint: BuildingFootprint) -> void:
	_ensure_pad_overlay()
	_pad_mesh.clear_surfaces()
	_pad_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell_size := context.terrain.cell_size
	var refused := not _plan.ok
	var cliffs: Dictionary = {}
	for cell: Vector2i in _plan.cliff_edges:
		cliffs[cell] = true
	var submerged: Dictionary = {}
	for cell: Vector2i in _plan.submerged_cells:
		submerged[cell] = true
	for cell: Vector2i in footprint.cells():
		if not context.terrain.is_inside(cell):
			continue
		var before := context.terrain.height_of(cell)
		var after := _plan.level + footprint.relative_height(cell)
		var colour := COLOR_BLOCKED if refused \
			else (COLOR_CUT if after < before else (COLOR_FILL if after > before else COLOR_KEEP))
		if not refused and _show_skirts and cliffs.has(cell):
			colour = COLOR_CLIFF
		if not refused and submerged.has(cell):
			colour = COLOR_SUBMERGED
		_cell_quad(cell, after, colour, cell_size)
	if _show_skirts and _plan.delta != null:
		# The skirt is ground the operation moves OUTSIDE the footprint. It is what
		# the author is really choosing between when they pick a height reference,
		# and until it is drawn the earthworks counter is the only hint it exists.
		for index in _plan.delta.cells.size():
			var cell: Vector2i = _plan.delta.cells[index]
			if footprint.contains(cell):
				continue
			var before := _plan.delta.old_state_at(index)[TerrainDelta.STATE_HEIGHT]
			var after := _plan.delta.new_state_at(index)[TerrainDelta.STATE_HEIGHT]
			if after == before:
				continue
			var skirt := COLOR_CUT if after < before else COLOR_FILL
			skirt.a *= 0.5
			_cell_quad(cell, after, skirt, cell_size)
	_pad_mesh.surface_end()
	_pad_overlay.visible = true


func _cell_quad(cell: Vector2i, height: int, colour: Color, cell_size: float) -> void:
	var y := float(height) * TerrainGrid.HEIGHT_STEP + 0.06
	var x0 := float(cell.x) * cell_size
	var z0 := float(cell.y) * cell_size
	_quad(Vector3(x0, y, z0), Vector3(x0 + cell_size, y, z0 + cell_size), colour)


func _quad(from_corner: Vector3, to_corner: Vector3, colour: Color) -> void:
	var a := from_corner
	var b := Vector3(to_corner.x, from_corner.y, from_corner.z)
	var c := to_corner
	var d := Vector3(from_corner.x, from_corner.y, to_corner.z)
	for vertex: Vector3 in [a, b, c, a, c, d]:
		_pad_mesh.surface_set_color(colour)
		_pad_mesh.surface_add_vertex(vertex)


func _ensure_pad_overlay() -> void:
	if is_instance_valid(_pad_overlay):
		return
	_pad_mesh = ImmediateMesh.new()
	_pad_overlay = MeshInstance3D.new()
	_pad_overlay.name = "PlacementPad"
	_pad_overlay.mesh = _pad_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	_pad_overlay.material_override = material
	_root.add_child(_pad_overlay)


func _hide_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.visible = false
	if is_instance_valid(_pad_overlay):
		_pad_overlay.visible = false


# --- Panels -------------------------------------------------------------------------

func inspector_lines() -> Array[String]:
	var record := selected_record()
	if record != null:
		var current := BuildingPlacementService.blueprint_of(record)
		var lines: Array[String] = [
			"Здание: %s" % (current.name if current != null else "чертёж не установлен"),
			"id: %s" % record.id,
			"клетка %d, %d · ориентация %s" % [
				record.cell.x, record.cell.y, BuildingFootprint.orientation_label(record.orientation)],
			"уровень %d (%s)" % [record.level_value, PlacementLevel.label_of(record.level_mode)],
			"состояние: %s" % record.state,
		]
		if current != null and current.revision_id() != record.blueprint_revision() \
				and not record.blueprint_revision().is_empty():
			lines.append("чертёж изменился с момента постановки")
		return lines
	var brush := blueprint()
	if brush == null:
		return []
	var lines: Array[String] = [
		"Кисть: %s" % brush.name,
		"пятно %d×%d · ориентация %s" % [
			brush.footprint.x, brush.footprint.y, BuildingFootprint.orientation_label(_orientation)],
		"уровень: %s" % PlacementLevel.label_of(_level_mode),
	]
	if _plan != null:
		lines.append("земляные работы: срез %d, насыпь %d" % [_plan.cut_cells, _plan.fill_cells])
		if not _plan.ok:
			lines.append("отказ: %s" % _plan.reason_text())
		for warning: String in _plan.warnings:
			lines.append("⚠ %s" % warning)
	return lines


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	if layer() == null:
		return entries
	for record: MapPlacementRecord in layer().placements:
		var current := BuildingPlacementService.blueprint_of(record)
		entries.append("⌂ %s  ·  %d, %d  ·  %s" % [
			current.name if current != null else String(record.blueprint_role()),
			record.cell.x, record.cell.y, record.id])
	return entries


func selected_list_index() -> int:
	if layer() == null:
		return -1
	var placements := layer().placements
	for index in placements.size():
		if placements[index].id == _selected_id:
			return index
	return -1


func select_list_index(index: int) -> void:
	if layer() == null:
		return
	var placements := layer().placements
	if index < 0 or index >= placements.size():
		return
	_selected_id = placements[index].id
	_orientation = placements[index].orientation
	rebuild_views()


## §8.5: the status line answers "why not". A refusal without a named reason is
## the worst kind of refusal.
func status_text() -> String:
	if not is_engaged():
		return ""
	var parts: Array[String] = []
	if context.brush != null and context.brush.has_hover:
		var cell := context.brush.hovered_cell
		parts.append("клетка %d,%d" % [cell.x, cell.y])
	parts.append("север ↑ −Z · ориентация %s" % BuildingFootprint.orientation_label(_orientation))
	if _plan != null:
		parts.append("уровень %d (%s)" % [_plan.level, PlacementLevel.label_of(_level_mode)])
		parts.append("срез %d / насыпь %d" % [_plan.cut_cells, _plan.fill_cells])
		if not _plan.ok:
			parts.append("нельзя: %s" % _plan.reason_text())
		elif not _plan.warnings.is_empty():
			parts.append("⚠ %s" % _plan.warnings[0])
	parts.append("C/R — поворот · Shift+ПКМ — снести")
	return " · ".join(parts)
