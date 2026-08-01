class_name SurfaceModeController
extends MapEditorMode

## Mode 2, surface: ground and coverage (map_editor.md §5.2).
##
## Everything a cell is covered with: the natural material of the ground, and the
## surface built over it — a park path, a pavement, a road, an alien deck.
##
## **One mode, two layers, and that is deliberate.** The layers are genuinely
## separate in storage — erasing coverage has to reveal the ground that was always
## under it — but a mode is a set of tools, not the name of a file. The brush, the
## overlay, the shape and radius, the undo record and the author's question are the
## same, so splitting them would put internal storage in the top bar. The rule the
## water mode already states applies here: the palette shows the author's choice,
## not the internal registry (§5.3).
##
## Which layer a stroke writes into therefore follows from the palette entry, not
## from a tab: pick a material and the ground brush paints, pick a coverage and
## the coverage brush lays it.
##
## None of it moves a vertex. Both layers keep a dirty set separate from the dirty
## chunks, so a whole drag rebuilds no geometry at all — the pending-chunk counter
## staying at zero while this mode is used is that promise made visible.
##
## The material half of the palette is the material catalog and nothing else. The
## catalog has a hard entry rule — a material is something that changes the angle
## of repose, the cost of walking, the soil dug out of it or the rock it cliffs
## into; a surface the player builds is never one of them. The editor does not get
## to widen that rule: a road reaches the map through the coverage group or not at
## all.

const OPTION_VARIANT_PREFIX := "variant_"
const OPTION_WEAR := &"wear"
const OPTION_SNOW := &"snow"
const OPTION_BRUSH_UP := &"brush_up"
const OPTION_BRUSH_DOWN := &"brush_down"
const OPTION_COVERAGE_WEAR := &"coverage_wear"

## Palette ids of coverage entries are prefixed, so a catalog that one day names a
## surface after a material cannot collide with it.
const COVERAGE_ENTRY_PREFIX := "coverage:"
const ENTRY_ERASE_COVERAGE := &"coverage:none"

## Sub-tools cycled with `Tab`: what the left button paints on the GROUND. The
## coverage half has its own two — lay and erase — and they are chosen by the
## palette, not by this cycle.
const TOOL_MATERIAL := &"material"
const TOOL_WEAR := &"wear"
const TOOL_SNOW := &"snow"
const TOOLS: Array[StringName] = [TOOL_MATERIAL, TOOL_WEAR, TOOL_SNOW]

var _tool: StringName = TOOL_MATERIAL
## True while the palette selection is a coverage entry. It is derived state, not
## a mode switch: selecting a material clears it again.
var _coverage_selected := false
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
	if _coverage_brush() != null:
		_coverage_brush().set_painting(false)


func clear_hover() -> void:
	if context != null and context.brush != null:
		context.brush.clear_hover()
	if _coverage_brush() != null:
		_coverage_brush().clear_hover()


## The marker follows whichever brush the palette armed, so an author laying a
## road sees the width they are about to pave and not the material brush.
func hover_brush() -> BaseBrushController:
	if context == null:
		return null
	return _coverage_brush() if _coverage_selected and _coverage_brush() != null else context.brush


func adjust_brush_size(delta: int) -> void:
	var brush := hover_brush()
	if brush != null:
		brush.adjust_brush_size(delta)


func pick_from_cell() -> void:
	if context == null:
		return
	var brush := hover_brush()
	if brush == null:
		return
	brush.update_hover(context.camera, context.space_state(), context.mouse_position())
	if _coverage_selected:
		(brush as CoverageBrushController).pick_coverage()
	else:
		(brush as TerrainBrushController).pick_material()
	notify_ui_changed()


func process(_delta: float) -> void:
	if _coverage_selected and _coverage_brush() != null:
		# The coverage brush rasterises its own stroke between cursor samples, so
		# it only needs the hover; the drag lives inside it.
		_coverage_brush().update_hover(context.camera, context.space_state(), context.mouse_position())
		return
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
		if _coverage_selected and _coverage_brush() != null:
			context.set_edit_label("покрытие")
			_coverage_brush().set_painting(button.pressed, _erases_coverage())
			notify_ui_changed()
			return true
		_painting = button.pressed
		if button.pressed:
			_paint()
		notify_ui_changed()
		return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		return _handle_key(event as InputEventKey)
	return false


func _coverage_brush() -> CoverageBrushController:
	return context.coverage_brush if context != null else null


## The eraser is the "no coverage" palette entry rather than a modifier key: it is
## a thing the author picks and keeps, and the status line can then say which of
## the two the next stroke does.
func _erases_coverage() -> bool:
	return _coverage_brush() != null and _coverage_brush().coverage_index == CoverageCatalog.NONE_INDEX


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
			adjust_brush_size(-1)
		KEY_BRACKETRIGHT:
			adjust_brush_size(1)
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
const ACCORDION_COVERAGE := &"accordion_coverage"

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

	# The second group: what is BUILT over the ground. It sits in the same palette
	# because it is the same question and the same brush; the entry decides which
	# layer the stroke lands in (§5.2).
	var coverage_open := _expanded_accordion == &"coverage"
	entries.append(PaletteEntry.header(ACCORDION_COVERAGE, "Покрытие", coverage_open))
	if coverage_open:
		# The eraser is an entry and not a modifier key: removing coverage is a
		# thing the author picks and keeps, and it reveals the ground under it
		# rather than painting anything.
		entries.append(PaletteEntry.of(ENTRY_ERASE_COVERAGE, "  снять покрытие", Color(0, 0, 0, 0)))
		for index in CoverageCatalog.indices():
			entries.append(PaletteEntry.of(
				_coverage_entry_id(index),
				"  " + CoverageCatalog.title_of_index(index),
				CoverageLibrary.colour_of_index(index),
			))

	return entries


func selected_palette_entry() -> StringName:
	if _coverage_selected and _coverage_brush() != null:
		return _coverage_entry_id(_coverage_brush().coverage_index)
	return context.brush.material_id()


static func _coverage_entry_id(index: int) -> StringName:
	if index == CoverageCatalog.NONE_INDEX:
		return ENTRY_ERASE_COVERAGE
	return StringName(COVERAGE_ENTRY_PREFIX + String(CoverageCatalog.id_of_index(index)))


static func _is_coverage_entry(entry_id: StringName) -> bool:
	return String(entry_id).begins_with(COVERAGE_ENTRY_PREFIX)


func _select_coverage_entry(entry_id: StringName) -> void:
	var brush := _coverage_brush()
	if brush == null:
		return
	var index := CoverageCatalog.NONE_INDEX
	if entry_id != ENTRY_ERASE_COVERAGE:
		index = CoverageCatalog.index_of_id(StringName(String(entry_id).trim_prefix(COVERAGE_ENTRY_PREFIX)))
	brush.set_coverage_index(index)
	_coverage_selected = true
	_expanded_accordion = &"coverage"
	notify_ui_changed()


func select_palette_entry(entry_id: StringName) -> void:
	if _is_coverage_entry(entry_id):
		_select_coverage_entry(entry_id)
		return
	if entry_id == ACCORDION_COVERAGE:
		_expanded_accordion = &"" if _expanded_accordion == &"coverage" else &"coverage"
		notify_ui_changed()
		return
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
		# Picking a material disarms the coverage brush and returns to material tool.
		_coverage_selected = false
		context.brush.set_material_index(index)
		_tool = TOOL_MATERIAL
		if EXOPLANET_MATERIALS.has(entry_id):
			_expanded_accordion = &"exoplanet"
		else:
			_expanded_accordion = &"earth"
		notify_ui_changed()


func tool_options() -> Array:
	if _coverage_selected:
		return _coverage_tool_options()
	var options: Array = []
	options.append(ToolOption.of(&"brush_size", "Кисть: %d" % (context.brush.brush_size - 1), &"brush", false, true))
	options.append(ToolOption.of(OPTION_BRUSH_DOWN, "−", &"brush"))
	options.append(ToolOption.of(OPTION_BRUSH_UP, "+", &"brush"))
	var variant_count := TerrainMaterialVariants.variant_count(context.brush.material_index)
	for variant_index in variant_count:
		options.append(ToolOption.of(
			_variant_option_id(variant_index),
			String(TerrainMaterialVariants.variant_name(context.brush.material_index, variant_index)),
			&"variants", variant_index == context.brush.variant and _tool == TOOL_MATERIAL,
		))
	# The wear brush is only useful on recoverable natural cover; do not offer a
	# misleading brown path on rock, ice or extraterrestrial ground.
	if _selected_material_supports_wear():
		options.append(ToolOption.of(OPTION_WEAR, "Износ: %d" % _wear_level, &"tools", _tool == TOOL_WEAR))
	options.append(ToolOption.of(OPTION_SNOW, "Снег: %d" % _snow_level, &"tools", _tool == TOOL_SNOW))
	return options


## The coverage half has no snow brush and no material variants: snow on a road is
## weather, and the variant of a surface follows its catalog entry. What is left
## is the width of the stroke and how worn it is laid.
func _coverage_tool_options() -> Array:
	var brush := _coverage_brush()
	var options: Array = []
	var width := brush.brush_size * 2 - 1 if brush != null else 1
	options.append(ToolOption.of(&"brush_size", "Ширина: %d" % width, &"brush", false, true))
	options.append(ToolOption.of(OPTION_BRUSH_DOWN, "−", &"brush"))
	options.append(ToolOption.of(OPTION_BRUSH_UP, "+", &"brush"))
	if brush != null and CoverageCatalog.supports_wear_index(brush.coverage_index):
		options.append(ToolOption.of(OPTION_COVERAGE_WEAR, "Износ: %d" % brush.wear))
	return options


func activate_option(option_id: StringName) -> void:
	if option_id == OPTION_COVERAGE_WEAR and _coverage_brush() != null:
		var brush := _coverage_brush()
		brush.set_wear((brush.wear + 1) % (TerrainDetailCodec.MAX_WEAR + 1))
		notify_ui_changed()
		return
	if _coverage_selected and (option_id == OPTION_BRUSH_UP or option_id == OPTION_BRUSH_DOWN):
		adjust_brush_size(1 if option_id == OPTION_BRUSH_UP else -1)
		notify_ui_changed()
		return
	if String(option_id).begins_with(OPTION_VARIANT_PREFIX):
		context.set_edit_label("вариант")
		context.brush.set_variant(String(option_id).trim_prefix(OPTION_VARIANT_PREFIX).to_int())
		_tool = TOOL_MATERIAL
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
			_wear_level = (_wear_level + 1) % (TerrainDetailCodec.MAX_WEAR + 1)
			_tool = TOOL_WEAR
		OPTION_SNOW:
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
	return []


func status_text() -> String:
	if _coverage_selected:
		return _coverage_status_text()
	if not context.brush.has_hover:
		return "клетка —"
	var cell := context.brush.hovered_cell
	var index := context.terrain.material_index_at(cell)
	return "клетка %d,%d · %s/%s · осыпание %s · грунт %s · обрыв %s · износ %d · снег %d · вес ×%.2f" % [
		cell.x, cell.y, context.terrain.material_of(cell),
		TerrainMaterialVariants.variant_name(index, context.terrain.variant_at(cell)),
		SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of_index(index)),
		TerrainMaterialCatalog.soil_of_index(index),
		TerrainMaterialCatalog.cliff_material_of_index(index),
		context.terrain.wear_at(cell), context.terrain.snow_depth_at(cell),
		context.terrain.surface_weight_at(cell),
	]


func _coverage_status_text() -> String:
	var brush := _coverage_brush()
	if brush == null or not brush.has_hover:
		return "клетка —"
	var cell := brush.hovered_cell
	var layer := context.coverage
	var laid := layer.index_at(cell) if layer != null else CoverageCatalog.NONE_INDEX
	var index := context.terrain.material_index_at(cell)
	return "клетка %d,%d · покрытие %s · земля %s (осыпание %s, грунт %s, обрыв %s) · вес %s" % [
		cell.x, cell.y,
		CoverageCatalog.title_of_index(laid),
		context.terrain.material_of(cell),
		SlopeCatalog.id_of_class(TerrainMaterialCatalog.repose_class_of_index(index)),
		TerrainMaterialCatalog.soil_of_index(index),
		TerrainMaterialCatalog.cliff_material_of_index(index),
		"%.2f" % CoverageCatalog.weight_of_index(laid) if laid != CoverageCatalog.NONE_INDEX \
			else "×%.2f" % context.terrain.surface_weight_at(cell),
	]


func list_title() -> String:
	return ""


func empty_list_hint() -> String:
	return ""


## The palette reads the same generated swatch as terrain rendering. Keeping a
## second match here made every catalog addition require an editor-only colour.
func _swatch_of(index: int) -> Color:
	return TerrainMaterialLibrary.swatch_of(index)
