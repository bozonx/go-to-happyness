class_name DecorPlacementValidator
extends RefCounted

## Pure placement logic extracted from DecorModeController: snapping, bounds
## checks, AABB intersection, collision conflicts, picking, and record lookup.
## No nodes, no UI — only deterministic math over blueprint state.

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")
const FurnishingAssetDefScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_def.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")
const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")

## Minimum click radius, so thin objects (a flag pole) stay pickable.
const MIN_PICK_RADIUS := 0.35

enum GhostState { VALID, INTERSECTION, OUT_OF_BOUNDS }

## Cycle-selection state: when the cursor is over overlapping objects,
## repeated clicks cycle through them instead of always picking the nearest.
var _last_pick_pos: Vector3 = Vector3(INF, INF, INF)
var _pick_cycle_index: int = 0
var _last_picked_ids: Array[String] = []


## Snap grid points are the *centres* of `step`-sized cells, so an object always
## lands centred in its snap cell (1.0 → block centres, 0.5 → half-block centres).
## Free placement (step 0) is only allowed when the asset's snap_steps includes 0.
func snapped_position(raw_hit: Vector3, active_layer: int, asset_id: StringName, snap_step: float) -> Vector3:
	var y := float(active_layer)
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	var step := snap_step
	# If the asset restricts snap steps, clamp to the closest allowed one.
	if asset != null and not asset.snap_steps.is_empty():
		var best_step := asset.snap_steps[0]
		var best_diff := absf(step - best_step)
		for allowed in asset.snap_steps:
			var diff := absf(step - allowed)
			if diff < best_diff:
				best_step = allowed
				best_diff = diff
		step = best_step
	if step <= 0.001:
		return Vector3(raw_hit.x, y, raw_hit.z)
	var half := step * 0.5
	return Vector3(
		snappedf(raw_hit.x - half, step) + half,
		y,
		snappedf(raw_hit.z - half, step) + half)


## Returns true when the position is inside the building footprint.
func is_in_bounds(pos: Vector3, blueprint: RefCounted, asset_id: StringName, scale: Vector3) -> bool:
	if blueprint == null:
		return true
	var footprint: Vector2i = blueprint.footprint
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	var size := asset.footprint_m() if asset != null else Vector3.ONE
	var half_x := size.x * scale.x * 0.5
	var half_z := size.z * scale.z * 0.5
	return pos.x - half_x >= 0.0 and pos.x + half_x <= float(footprint.x) and pos.z - half_z >= 0.0 and pos.z + half_z <= float(footprint.y)


func decor_aabb(pos: Vector3, asset_id: StringName, scale: Vector3) -> AABB:
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	var size := (asset.footprint_m() if asset != null else Vector3.ONE) * scale
	return AABB(pos - Vector3(size.x * 0.5, 0.0, size.z * 0.5), size)


func aabbs_intersect(a: AABB, b: AABB) -> bool:
	const EPSILON := 0.0001
	return a.position.x < b.end.x - EPSILON and b.position.x < a.end.x - EPSILON \
		and a.position.y < b.end.y - EPSILON and b.position.y < a.end.y - EPSILON \
		and a.position.z < b.end.z - EPSILON and b.position.z < a.end.z - EPSILON


## Returns true only for conflicts that affect physical collision/navigation.
## Decorative objects with `none` policy may intentionally overlap.
func is_collision_conflict(pos: Vector3, blueprint: RefCounted, asset_id: StringName, scale: Vector3, exclude_id: String = "") -> bool:
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	if asset == null:
		return false
	var candidate := decor_aabb(pos, asset_id, scale)
	var candidate_blocks := asset.collision_policy != FurnishingAssetDefScript.COLLISION_NONE or asset.blocking_navigation
	# Frame volumes and circulation are authoring obstacles. This deliberately
	# uses the same occupied volumes as the frame editor, not a second grid.
	for block in blueprint.blocks:
		var block_aabb := BuildingBlockCatalogScript.occupied_aabb(block.pos, block.block_id, block.variant, block.rot, block.anchor, block.rot_x, block.rot_z)
		if aabbs_intersect(candidate, block_aabb):
			return true
	if not candidate_blocks:
		return false
	for record: DecorObjectRecordScript in blueprint.objects:
		if record.id == exclude_id:
			continue
		var other_asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
		if other_asset == null:
			continue
		if other_asset.collision_policy == FurnishingAssetDefScript.COLLISION_NONE and not other_asset.blocking_navigation:
			continue
		if aabbs_intersect(candidate, decor_aabb(record.pos, record.asset_id, record.scale)):
			return true
	return false


func is_valid_transform(pos: Vector3, rot: Vector3, scale: Vector3, asset_id: StringName, blueprint: RefCounted, exclude_id: String = "") -> bool:
	var asset := FurnishingAssetCatalogScript.get_asset(asset_id)
	if asset != null:
		if not asset.is_scale_allowed(scale.x) or not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
			return false
		for axis in ["x", "y", "z"]:
			var value := rot.x if axis == "x" else (rot.y if axis == "y" else rot.z)
			if not is_zero_approx(value) and not asset.is_rotation_axis_allowed(axis):
				return false
	return is_in_bounds(pos, blueprint, asset_id, scale) and not is_collision_conflict(pos, blueprint, asset_id, scale, exclude_id)


## Computes the current ghost state for placement feedback.
func compute_ghost_state(pos: Vector3, blueprint: RefCounted, asset_id: StringName) -> int:
	if not is_in_bounds(pos, blueprint, asset_id, Vector3.ONE):
		return GhostState.OUT_OF_BOUNDS
	if is_collision_conflict(pos, blueprint, asset_id, Vector3.ONE):
		return GhostState.INTERSECTION
	return GhostState.VALID


## Objects whose footprint contains `world_pos`, sorted nearest first.
## Returns all candidates so the caller can cycle through overlapping ones.
func pick_objects_at(world_pos: Vector3, blueprint: RefCounted) -> Array[String]:
	var candidates: Array[Dictionary] = []
	for record: DecorObjectRecordScript in blueprint.objects:
		var asset := FurnishingAssetCatalogScript.get_asset(record.asset_id)
		var size := asset.footprint_m() if asset != null else Vector3.ONE
		var radius := maxf(MIN_PICK_RADIUS, maxf(size.x, size.z) * 0.5 * maxf(record.scale.x, record.scale.z))
		var distance := Vector2(record.pos.x - world_pos.x, record.pos.z - world_pos.z).length()
		if distance <= radius:
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


static func find_record_in(object_id: String, blueprint: RefCounted) -> DecorObjectRecordScript:
	if object_id.is_empty():
		return null
	for record: DecorObjectRecordScript in blueprint.objects:
		if record.id == object_id:
			return record
	return null
