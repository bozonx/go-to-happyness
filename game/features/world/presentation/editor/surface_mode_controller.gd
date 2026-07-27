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
			_tool = TOOLS[(TOOLS.find(_tool) + 1) % TOOLS.size()]
		KEY_B:
			context.set_edit_label("вариант")
			context.brush.cycle_variant()
		KEY_U:
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
			context.set_edit_label("износ")
			context.brush.paint_wear(_wear_level)
		TOOL_SNOW:
			context.set_edit_label("снег")
			context.brush.paint_snow(_snow_level)


# --- Panels -------------------------------------------------------------------

## The whole catalog, each entry carrying the colour it paints so the palette is
## readable without a texture atlas.
func palette_entries() -> Array:
	var entries: Array = []
	for index in TerrainMaterialCatalog.count():
		var material_id: StringName = TerrainMaterialCatalog.ids()[index]
		entries.append(PaletteEntry.of(material_id, String(material_id), _swatch_of(index)))
	return entries


func selected_palette_entry() -> StringName:
	return context.brush.material_id()


func select_palette_entry(entry_id: StringName) -> void:
	var index := TerrainMaterialCatalog.index_of(entry_id)
	if index >= 0:
		context.brush.set_material_index(index)
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
	# The level is part of the brush, so it is shown on the button that selects it.
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
	return "Объекты поверхности"


func empty_list_hint() -> String:
	return "В режиме «Поверхность» объектов в списке пока нет"


## Approximate colour of a material, for the palette swatch. Deliberately derived
## from the catalog rather than stored beside it: a swatch is a convenience of
## this panel and must not become a second place where materials are defined.
func _swatch_of(index: int) -> Color:
	match TerrainMaterialCatalog.ids()[index]:
		TerrainMaterialCatalog.GRASS: return Color("6f9e4c")
		TerrainMaterialCatalog.GRASS_TALL: return Color("587f3c")
		TerrainMaterialCatalog.DIRT: return Color("7c5a3c")
		TerrainMaterialCatalog.STONE: return Color("8b8d90")
		TerrainMaterialCatalog.SAND: return Color("d8c58a")
		TerrainMaterialCatalog.GRAVEL: return Color("9a9187")
		TerrainMaterialCatalog.MUD: return Color("5c4632")
		TerrainMaterialCatalog.SCORCHED: return Color("3a3532")
		TerrainMaterialCatalog.ICE: return Color("bcd8e6")
		TerrainMaterialCatalog.LUNAR_REGOLITH: return Color("9a9a97")
		TerrainMaterialCatalog.LUNAR_ROCK: return Color("6e6e6c")
		TerrainMaterialCatalog.MARS_REGOLITH: return Color("b5714a")
		TerrainMaterialCatalog.MARS_ROCK: return Color("8a4a30")
		_:
			assert(false, "Unknown material index %d — add a swatch" % index)
			return Color("808080")
