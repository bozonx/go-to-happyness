class_name SurfaceModeController
extends MapEditorMode

## Mode 2, surface (map_editor.md §5.2).
##
## Painting material, variant, wear and snow. None of it moves a vertex: the grid
## keeps a dirty set for the surface separate from its dirty chunks, so a whole
## drag of the material brush rebuilds no geometry at all. The pending-chunk
## counter staying at zero while this mode is used is that promise made visible.
##
## The palette is the material catalog and nothing else. The catalog has a hard
## entry rule — a material is something that changes the angle of repose, the cost
## of walking, the soil dug out of it or the rock it cliffs into; everything else
## is a variant, decor, a road surface or a state of the detail byte. The editor
## does not get to widen that rule by offering paints the catalog does not have.

const OPTION_VARIANT_PREFIX := "variant_"
const OPTION_WEAR := &"wear"
const OPTION_SNOW := &"snow"
const OPTION_BRUSH_UP := &"brush_up"
const OPTION_BRUSH_DOWN := &"brush_down"

## Sub-tools cycled with `Tab`: what the left button paints.
const TOOL_MATERIAL := &"material"
const TOOL_WEAR := &"wear"
const TOOL_SNOW := &"snow"
const TOOLS: Array[StringName] = [TOOL_MATERIAL, TOOL_WEAR, TOOL_SNOW]

var _tool: StringName = TOOL_MATERIAL
var _painting := false
## The levels the wear and snow brushes PAINT. They are chosen once and then
## stamped, rather than stepped per stroke: a drag overlaps its own path, so a
## brush defined as "one more than what is here" paints a stripe of every value
## instead of a band of one.
var _wear_level := TerrainDetailCodec.MAX_WEAR
var _snow_level := TerrainDetailCodec.MAX_SNOW_DEPTH


func _init() -> void:
	id = &"surface"
	title = "Поверхность"
	icon = "🌿"


func deactivate() -> void:
	_painting = false


func clear_hover() -> void:
	if context != null and context.brush != null:
		context.brush.clear_hover()


func hover_brush() -> BaseBrushController:
	return context.brush if context != null else null


func adjust_brush_size(delta: int) -> void:
	if context != null and context.brush != null:
		context.brush.adjust_brush_size(delta)


func pick_from_cell() -> void:
	if context != null and context.brush != null:
		context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
		context.brush.pick_material()
		notify_ui_changed()


func process(_delta: float) -> void:
	var was := context.brush.hovered_cell
	var had := context.brush.has_hover
	context.brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	# A surface drag repaints as it crosses into a new column. The brush's own
	# drag belongs to the height tool, so this mode tracks its own.
	if _painting and context.brush.has_hover and (not had or was != context.brush.hovered_cell):
		_paint()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if _handle_common_mouse(button):
			return true
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		_painting = button.pressed
		if button.pressed:
			_paint()
		notify_ui_changed()
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _handle_key(event as InputEventKey)
	return false


func _handle_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_TAB:
			_cycle_tool()
		KEY_B:
			context.set_edit_label("вариант")
			context.brush.cycle_variant()
		KEY_U:
			if _selected_material_supports_wear():
				_wear_level = (_wear_level + 1) % (TerrainDetailCodec.MAX_WEAR + 1)
				_tool = TOOL_WEAR
		KEY_J:
			_snow_level = (_snow_level + 1) % (TerrainDetailCodec.MAX_SNOW_DEPTH + 1)
			_tool = TOOL_SNOW
		KEY_BRACKETLEFT:
			context.brush.adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			context.brush.adjust_brush_size(1)
		_:
			return false
	notify_ui_changed()
	return true


func _paint() -> void:
	match _tool:
		TOOL_MATERIAL:
			context.set_edit_label("покраска")
			context.brush.apply_material()
		TOOL_WEAR:
			if _selected_material_supports_wear():
				context.set_edit_label("износ")
				context.brush.paint_wear(_wear_level)
			else:
				_tool = TOOL_MATERIAL
		TOOL_SNOW:
			context.set_edit_label("снег")
			_paint_snow()


func _paint_snow() -> void:
	var cells := context.brush.brush_cells(context.brush.hovered_cell)
	# Clearing snow must also work on cells that became water or steep after an
	# earlier authoring pass. Adding it follows the physical placement rule.
	if _snow_level == 0:
		context.brush.paint_snow_cells(cells, 0)
		return
	var eligible: Array[Vector2i] = []
	var rejected := 0
	for cell: Vector2i in cells:
		if _snow_can_rest_on(cell):
			eligible.append(cell)
		else:
			rejected += 1
	if context.brush.paint_snow_cells(eligible, _snow_level) and rejected > 0:
		context.brush.last_message += " · %d клеток пропущено" % rejected
	elif eligible.is_empty():
		context.brush.last_message = "снег: нет подходящей поверхности"


func _snow_can_rest_on(cell: Vector2i) -> bool:
	if not context.terrain.is_inside(cell) or context.terrain.is_hole(cell):
		return false
	# Open water has no ground surface for snow. Frozen water has an ice floor and
	# is intentionally eligible: snowfall on a frozen lake is normal and its cost
	# remains a weight, not a topology change.
	if context.water != null and context.water.is_wet(context.terrain, cell) and not context.water.is_frozen(cell):
		return false
	return context.terrain.slope_class_at(cell) < SlopeCatalog.CLASS_VERY_STEEP


const ACCORDION_EARTH := &"accordion_earth"
const ACCORDION_EXOPLANET := &"accordion_exoplanet"

const EXOPLANET_MATERIALS: Array[StringName] = [
	TerrainMaterialCatalog.LUNAR_REGOLITH,
	TerrainMaterialCatalog.LUNAR_ROCK,
	TerrainMaterialCatalog.MARS_REGOLITH,
	TerrainMaterialCatalog.MARS_ROCK,
]

var _expanded_accordion: StringName = &"earth"


# --- Panels -------------------------------------------------------------------

## The catalog split into Earth and Exoplanet accordions, with only one open at a time.
func palette_entries() -> Array:
	var entries: Array = []
	var earth_open := _expanded_accordion == &"earth"
	entries.append(PaletteEntry.header(ACCORDION_EARTH, "Земля", earth_open))
	if earth_open:
		for index in TerrainMaterialCatalog.count():
			var material_id: StringName = TerrainMaterialCatalog.ids()[index]
			if not EXOPLANET_MATERIALS.has(material_id):
				entries.append(PaletteEntry.of(material_id, "  " + String(material_id), _swatch_of(index)))

	var exo_open := _expanded_accordion == &"exoplanet"
	entries.append(PaletteEntry.header(ACCORDION_EXOPLANET, "Экзопланеты", exo_open))
	if exo_open:
		for index in TerrainMaterialCatalog.count():
			var material_id: StringName = TerrainMaterialCatalog.ids()[index]
			if EXOPLANET_MATERIALS.has(material_id):
				entries.append(PaletteEntry.of(material_id, "  " + String(material_id), _swatch_of(index)))

	return entries


func selected_palette_entry() -> StringName:
	return context.brush.material_id()


func select_palette_entry(entry_id: StringName) -> void:
	if entry_id == ACCORDION_EARTH:
		_expanded_accordion = &"" if _expanded_accordion == &"earth" else &"earth"
		notify_ui_changed()
		return
	elif entry_id == ACCORDION_EXOPLANET:
		_expanded_accordion = &"" if _expanded_accordion == &"exoplanet" else &"exoplanet"
		notify_ui_changed()
		return

	var index := TerrainMaterialCatalog.index_of(entry_id)
	if index >= 0:
		context.brush.set_material_index(index)
		if EXOPLANET_MATERIALS.has(entry_id):
			_expanded_accordion = &"exoplanet"
		else:
			_expanded_accordion = &"earth"
		if _tool == TOOL_WEAR and not _selected_material_supports_wear():
			_tool = TOOL_MATERIAL
		notify_ui_changed()


func tool_options() -> Array:
	var options: Array = []
	options.append(ToolOption.of(&"brush_size", "Кисть: %d" % (context.brush.brush_size - 1), &"brush", false, true))
	options.append(ToolOption.of(OPTION_BRUSH_DOWN, "−", &"brush"))
	options.append(ToolOption.of(OPTION_BRUSH_UP, "+", &"brush"))
	var variant_count := TerrainMaterialVariants.variant_count(context.brush.material_index)
	for variant_index in variant_count:
		options.append(ToolOption.of(
			_variant_option_id(variant_index),
			String(TerrainMaterialVariants.variant_name(context.brush.material_index, variant_index)),
			&"variants", variant_index == context.brush.variant,
		))
	# The wear brush is only useful on recoverable natural cover; do not offer a
	# misleading brown path on rock, ice or extraterrestrial ground.
	if _selected_material_supports_wear():
		options.append(ToolOption.of(OPTION_WEAR, "Износ: %d" % _wear_level))
	options.append(ToolOption.of(OPTION_SNOW, "Снег: %d" % _snow_level))
	return options


func activate_option(option_id: StringName) -> void:
	if String(option_id).begins_with(OPTION_VARIANT_PREFIX):
		context.set_edit_label("вариант")
		context.brush.set_variant(String(option_id).trim_prefix(OPTION_VARIANT_PREFIX).to_int())
		notify_ui_changed()
		return
	match option_id:
		OPTION_BRUSH_UP:
			context.brush.adjust_brush_size(1)
		OPTION_BRUSH_DOWN:
			context.brush.adjust_brush_size(-1)
		OPTION_WEAR:
			if not _selected_material_supports_wear():
				return
			# Pressing it again steps the level, so one button both picks the
			# tool and sets what it paints.
			if _tool == TOOL_WEAR:
				_wear_level = (_wear_level + 1) % (TerrainDetailCodec.MAX_WEAR + 1)
			_tool = TOOL_WEAR
		OPTION_SNOW:
			if _tool == TOOL_SNOW:
				_snow_level = (_snow_level + 1) % (TerrainDetailCodec.MAX_SNOW_DEPTH + 1)
			_tool = TOOL_SNOW
	notify_ui_changed()


func _selected_material_supports_wear() -> bool:
	return TerrainMaterialCatalog.supports_wear(context.brush.material_index)


func _cycle_tool() -> void:
	var available: Array[StringName] = [TOOL_MATERIAL, TOOL_SNOW]
	if _selected_material_supports_wear():
		available.insert(1, TOOL_WEAR)
	_tool = available[(available.find(_tool) + 1) % available.size()] if available.has(_tool) else available[0]


func _variant_option_id(variant_index: int) -> StringName:
	return StringName("%s%d" % [OPTION_VARIANT_PREFIX, variant_index])


func inspector_lines() -> Array[String]:
	var index := context.brush.material_index
	var lines: Array[String] = []
	lines.append("Инструмент: %s" % _tool)
	lines.append("Материал: %s" % context.brush.material_id())
	lines.append("Вариант: %s" % TerrainMaterialVariants.variant_name(index, context.brush.variant))
	lines.append("Кисть: %d×%d" % [context.brush.brush_size * 2 - 1, context.brush.brush_size * 2 - 1])
	lines.append("")
	# The four properties that make this a material and not a decoration.
	lines.append("Осыпание: %s" % SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of_index(index)))
	lines.append("Грунт: %s" % TerrainMaterialCatalog.soil_of_index(index))
	lines.append("Обрыв: %s" % TerrainMaterialCatalog.cliff_material_of_index(index))
	lines.append("Вес прохода: ×%.2f" % TerrainMaterialCatalog.nav_weight_of_index(index))
	lines.append("")
	lines.append("Кисть износа: %d, кисть снега: %d" % [_wear_level, _snow_level])
	return lines


func status_text() -> String:
	if not context.brush.has_hover:
		return "клетка —"
	var cell := context.brush.hovered_cell
	var index := context.terrain.material_index_at(cell)
	return "клетка %d,%d · %s/%s · износ %d · снег %d · вес ×%.2f · чанков в очереди %d" % [
		cell.x, cell.y, context.terrain.material_of(cell),
		TerrainMaterialVariants.variant_name(index, context.terrain.variant_at(cell)),
		context.terrain.wear_at(cell), context.terrain.snow_depth_at(cell),
		context.terrain.surface_weight_at(cell),
		context.terrain_world.pending_chunk_count() if context.terrain_world != null else 0,
	]


func list_title() -> String:
	return ""


func empty_list_hint() -> String:
	return ""


## The palette reads the same generated swatch as terrain rendering. Keeping a
## second match here made every catalog addition require an editor-only colour.
func _swatch_of(index: int) -> Color:
	return TerrainMaterialLibrary.swatch_of(index)
