class_name MapEditorContext
extends RefCounted

signal status_message_changed(message: String, is_error: bool)
## Raised by a mode that changed the document outside the usual service commits —
## a captured multi-layer action (see `begin_capture`). The editor answers it by
## telling every mode to rebuild, which is what it does after undo anyway.
signal document_change_requested()
## Массовое наполнение изменилось (кисть-разброс, §9.2). Отдельный сигнал, а не
## `document_change_requested`: тот заставляет перестроиться КАЖДЫЙ режим, а
## перестройка чанков наполнения — это ровно одна нода, и звать ради неё общий
## пересбор значило бы платить всей картой за один мазок.
signal scatter_changed()

## Everything a mode is allowed to reach (map_editor.md §3.5).
##
## Handed to every mode instead of the editor node itself. That is the whole
## point: a mode that held `map_editor.gd` would start calling its panels and
## its siblings, and the modes would stop being separable — which is exactly how
## `building_editor.gd` reached 2159 lines before decor was pulled out of it.
##
## What is here is the document, the services that act on it, the shared undo
## stack and the few scene nodes a mode legitimately needs to draw with.

var document: MapDocument = null

var terrain: TerrainGrid = null
var terrain_service: TerrainService = null
var wear_service: SurfaceWearService = null
var brush: TerrainBrushController = null
var water: WaterGrid = null
var water_service: WaterService = null
var water_brush: WaterBrushController = null
## The built-coverage layer and its tools (map_editor.md §5.2). They live beside
## the ground brush rather than in a mode of their own, because coverage is a
## second layer of the same question and not a second tool set.
var coverage: CoverageLayer = null
var coverage_service: CoverageService = null
var coverage_brush: CoverageBrushController = null
var nav_grid: NavGrid = null
var nav_publisher: TerrainNavigationPublisher = null
## The one owner of "put a blueprint on the ground" (`building_placement.md` §2).
## The tool in the Fill mode drives it; a session drives the same object with a
## different policy.
var placement_service: BuildingPlacementService = null

var history: MapEditorHistory = null
var camera: MapEditorCamera = null
var terrain_world: GridTerrainWorld = null
var water_world: WaterWorld = null
var nav_overlay: NavTerrainOverlay = null
var hover_marker: Node3D = null
var ramp_preview: RampPreview = null
var water_highlight: WaterBodyHighlight = null
var water_flood_preview: WaterFloodPreview = null

## Set by the editor so a mode can raycast without knowing the scene tree.
var world_3d: World3D = null
var viewport: Viewport = null


## What the next ground edit should be called on the undo stack. A mode sets it
## before it touches the brush; the editor reads it when the service reports the
## commit.
##
## Modes do NOT push commands themselves. The editor listens to
## `TerrainService.edit_committed` and records one command per delta, which is the
## only way the two stacks stay aligned: a drag across twenty columns commits
## twenty deltas, and a mode that pushed once per click would leave nineteen of
## them unreachable from undo.
var pending_edit_label := "правка"


## One author action that touches several layers, collected into one undo entry.
##
## The editor records a command per committed delta, which is right for a brush:
## a drag across twenty columns is twenty deltas and twenty commands. Placing a
## building is the opposite case — the heights, the cut-outs, the water that
## reflows behind them, the anchors and the placement record are ONE thing the
## author did (`building_placement.md` §11.1), and one Ctrl+Z has to take all of
## it back.
##
## While a capture is open the editor appends the commands it would have pushed
## here instead. The mode closes it, adds its own record command and pushes a
## single composite. Deliberately generic: this is not "the placement hook", it is
## the same mechanism the border-ocean fill already needs.
var _capturing := false
var _captured: Array[MapEditorCommand] = []


func begin_capture() -> void:
	_capturing = true
	_captured.clear()


func is_capturing() -> bool:
	return _capturing


## Called by the editor for every command produced while a capture is open.
func capture_command(command: MapEditorCommand) -> void:
	if command != null:
		_captured.append(command)


func end_capture() -> Array[MapEditorCommand]:
	_capturing = false
	var parts := _captured.duplicate()
	_captured.clear()
	return parts


func request_document_refresh() -> void:
	document_change_requested.emit()


## Mouse position in the viewport the 3D view is rendered into.
func mouse_position() -> Vector2:
	return viewport.get_mouse_position() if viewport != null else Vector2.ZERO


func space_state() -> PhysicsDirectSpaceState3D:
	return world_3d.direct_space_state if world_3d != null else null


func set_edit_label(label: String) -> void:
	pending_edit_label = label


func notify_scatter_changed() -> void:
	scatter_changed.emit()


func set_status_message(message: String, is_error: bool = false) -> void:
	status_message_changed.emit(message, is_error)


## Подтверждение действия, которое нельзя откатить бесплатно (замена архетипа
## теряет настроенные свойства). Диалог принадлежит сцене редактора, поэтому
## контекст держит только колбэк: режим не знает про дерево сцены. Без
## обработчика действие считается подтверждённым — тесты гоняют режимы без UI.
var confirm_handler: Callable = Callable()


func confirm_action(message: String, title: String = "Подтверждение") -> bool:
	if not confirm_handler.is_valid():
		return true
	return await confirm_handler.call(message, title)
