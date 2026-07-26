class_name MapEditorContext
extends RefCounted

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
var nav_grid: NavGrid = null
var nav_publisher: TerrainNavigationPublisher = null

var history: MapEditorHistory = null
var camera: MapEditorCamera = null
var terrain_world: GridTerrainWorld = null
var water_world: WaterWorld = null
var nav_overlay: NavTerrainOverlay = null
var hover_marker: Node3D = null

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


## Mouse position in the viewport the 3D view is rendered into.
func mouse_position() -> Vector2:
	return viewport.get_mouse_position() if viewport != null else Vector2.ZERO


func space_state() -> PhysicsDirectSpaceState3D:
	return world_3d.direct_space_state if world_3d != null else null


func set_edit_label(label: String) -> void:
	pending_edit_label = label
