class_name FillPlacementValidator
extends RefCounted

## Pure placement logic extracted from BuildingFillModeController: snapping, bounds
## checks, AABB intersection, collision conflicts, picking, and record lookup.
## No nodes, no UI — only deterministic math over blueprint state.

const FillObjectRecordScript = preload("res://game/features/buildings/domain/editor/fill_object_record.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")

## Minimum click radius, so thin objects (a flag pole) stay pickable.
const MIN_PICK_RADIUS := 0.35

enum GhostState { VALID, INTERSECTION, OUT_OF_BOUNDS }

## Cycle-selection state: when the cursor is over overlapping objects,
## repeated clicks cycle through them instead of always picking the nearest.
var _last_pick_pos: Vector3 = Vector3(INF, INF, INF)
var _pick_cycle_index: int = 0
var _last_picked_ids: Array[String] = []


## Placement is per cell: an object occupies a whole number of cells and its
## anchor is the centre of that rectangle. Sub-cell positioning is a separate,
## explicitly authored `offset` — not a second snapping grid (design §6.2).
func snapped_position(raw_hit: Vector3, active_layer: int, asset_id: StringName, scale: float = 1.0, yaw_deg: float = 0.0) -> Vector3:
	var span := cell_span(asset_id, scale, yaw_deg)
	var base := EditorFillConventions.base_cell_at(raw_hit.x, raw_hit.z, span)
	var anchor := EditorFillConventions.anchor_of_cells(base, span)
	return Vector3(anchor.x, float(active_layer), anchor.y)


## How many whole cells the asset takes, rotation and scale included.
func cell_span(asset_id: StringName, scale: float = 1.0, yaw_deg: float = 0.0) -> Vector2i:
	var asset := WorldAssetCatalog.get_asset(asset_id)
	var size := Vector2i(1, 1)
	if asset != null:
		size = Vector2i(maxi(1, asset.size_in_blocks.x), maxi(1, asset.size_in_blocks.z))
	return EditorFillConventions.cell_span(size, scale, yaw_deg)


## The cells an object standing at `anchor` claims.
func occupied_cells(anchor: Vector3, asset_id: StringName, scale: float = 1.0, yaw_deg: float = 0.0) -> Rect2i:
	return EditorFillConventions.occupied_rect(anchor.x, anchor.z, cell_span(asset_id, scale, yaw_deg))


## Returns true when every claimed cell is inside the building footprint.
func is_in_bounds(pos: Vector3, blueprint: RefCounted, asset_id: StringName, scale: Vector3, yaw_deg: float = 0.0) -> bool:
	if blueprint == null:
		return true
	var footprint: Vector2i = blueprint.footprint
	var cells := occupied_cells(pos, asset_id, scale.x, yaw_deg)
	return cells.position.x >= 0 and cells.position.y >= 0 \
		and cells.end.x <= footprint.x and cells.end.y <= footprint.y


func fill_aabb(pos: Vector3, asset_id: StringName, scale: Vector3) -> AABB:
	var asset := WorldAssetCatalog.get_asset(asset_id)
	var size := (asset.footprint_m() if asset != null else Vector3.ONE) * scale
	return AABB(pos - Vector3(size.x * 0.5, 0.0, size.z * 0.5), size)


func aabbs_intersect(a: AABB, b: AABB) -> bool:
	const EPSILON := 0.0001
	return a.position.x < b.end.x - EPSILON and b.position.x < a.end.x - EPSILON \
		and a.position.y < b.end.y - EPSILON and b.position.y < a.end.y - EPSILON \
		and a.position.z < b.end.z - EPSILON and b.position.z < a.end.z - EPSILON


## Returns true only for conflicts that affect physical collision/navigation.
## Decorative objects with `none` policy may intentionally overlap.
##
## Objects claim **cells**, and two claims on one cell are refused. The authored
## `offset` is deliberately not part of this: it moves the model inside the cells
## the object already owns, and re-checking it would mean an object could be
## refused for a nudge the author made on purpose (design §6.2).
func is_collision_conflict(pos: Vector3, blueprint: RefCounted, asset_id: StringName, scale: Vector3, exclude_id: String = "", yaw_deg: float = 0.0) -> bool:
	var asset := WorldAssetCatalog.get_asset(asset_id)
	if asset == null:
		return false
	var candidate := fill_aabb(pos, asset_id, scale)
	var candidate_blocks := asset.collision_policy != WorldAssetDef.COLLISION_NONE or asset.blocking_navigation
	# Frame volumes and circulation are authoring obstacles. This deliberately
	# uses the same occupied volumes as the frame editor, not a second grid.
	for block in blueprint.blocks:
		var block_aabb := BuildingBlockCatalogScript.occupied_aabb(block.pos, block.block_id, block.variant, block.rot, block.anchor, block.rot_x, block.rot_z)
		if aabbs_intersect(candidate, block_aabb):
			return true
	if not candidate_blocks:
		return false
	var candidate_cells := occupied_cells(pos, asset_id, scale.x, yaw_deg)
	for record: FillObjectRecordScript in blueprint.objects:
		if record.id == exclude_id:
			continue
		# Objects on other floors share cells in plan and never conflict.
		if not is_equal_approx(record.anchor_pos().y, pos.y):
			continue
		var other_asset := WorldAssetCatalog.get_asset(record.asset_id)
		if other_asset == null:
			continue
		if other_asset.collision_policy == WorldAssetDef.COLLISION_NONE and not other_asset.blocking_navigation:
			continue
		var other_cells := occupied_cells(record.anchor_pos(), record.asset_id, record.scale.x, record.rot.y)
		if EditorFillConventions.rects_overlap(candidate_cells, other_cells):
			return true
	return false


func is_valid_transform(pos: Vector3, rot: Vector3, scale: Vector3, asset_id: StringName, blueprint: RefCounted, exclude_id: String = "") -> bool:
	var asset := WorldAssetCatalog.get_asset(asset_id)
	if asset != null:
		if not asset.is_scale_allowed(scale.x) or not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
			return false
		for axis in ["x", "y", "z"]:
			var value := rot.x if axis == "x" else (rot.y if axis == "y" else rot.z)
			if not is_zero_approx(value) and not asset.is_rotation_axis_allowed(axis):
				return false
	return is_in_bounds(pos, blueprint, asset_id, scale, rot.y) \
		and not is_collision_conflict(pos, blueprint, asset_id, scale, exclude_id, rot.y)


## Computes the current ghost state for placement feedback.
func compute_ghost_state(pos: Vector3, blueprint: RefCounted, asset_id: StringName, yaw_deg: float = 0.0) -> int:
	if not is_in_bounds(pos, blueprint, asset_id, Vector3.ONE, yaw_deg):
		return GhostState.OUT_OF_BOUNDS
	if is_collision_conflict(pos, blueprint, asset_id, Vector3.ONE, "", yaw_deg):
		return GhostState.INTERSECTION
	return GhostState.VALID


## Objects whose cells contain `world_pos`, sorted nearest first. Picking follows
## the claimed cells rather than a radius, so a long table is clickable along its
## whole length instead of only near its centre.
func pick_objects_at(world_pos: Vector3, blueprint: RefCounted) -> Array[String]:
	var candidates: Array[Dictionary] = []
	var pointer_cell := Vector2i(int(floor(world_pos.x)), int(floor(world_pos.z)))
	for record: FillObjectRecordScript in blueprint.objects:
		var anchor := record.anchor_pos()
		var cells := occupied_cells(anchor, record.asset_id, record.scale.x, record.rot.y)
		var distance := Vector2(record.pos.x - world_pos.x, record.pos.z - world_pos.z).length()
		if cells.has_point(pointer_cell) or distance <= MIN_PICK_RADIUS:
			candidates.append({"id": record.id, "dist": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) < float(b["dist"]))
	var result: Array[String] = []
	for c in candidates:
		result.append(String(c["id"]))
	return result


## Picks one object at `world_pos`. On repeated clicks at the same position,
## cycles through overlapping candidates instead of always returning the nearest.
func pick_object_at(world_pos: Vector3, blueprint: RefCounted) -> String:
	var ids := pick_objects_at(world_pos, blueprint)
	if ids.is_empty():
		_last_pick_pos = Vector3(INF, INF, INF)
		_pick_cycle_index = 0
		_last_picked_ids = []
		return ""
	# If the cursor moved significantly, reset cycle state.
	if world_pos.distance_to(_last_pick_pos) > MIN_PICK_RADIUS:
		_last_pick_pos = world_pos
		_pick_cycle_index = 0
		_last_picked_ids = ids
	elif ids != _last_picked_ids:
		# Object list changed (e.g. after placement); reset.
		_last_pick_pos = world_pos
		_pick_cycle_index = 0
		_last_picked_ids = ids
	var idx := _pick_cycle_index % ids.size()
	_pick_cycle_index += 1
	return ids[idx]


static func find_record_in(object_id: String, blueprint: RefCounted) -> FillObjectRecordScript:
	if object_id.is_empty():
		return null
	for record: FillObjectRecordScript in blueprint.objects:
		if record.id == object_id:
			return record
	return null
