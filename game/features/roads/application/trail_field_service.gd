class_name TrailFieldService
extends RefCounted

## Sparse-in-time, continuous-in-world trail field. Texels are a rendering detail;
## navigation reads the aggregated nav-cell projection through NavGrid weights.

const TEXELS_PER_METER := 4
const SAMPLE_DISTANCE := 0.45
const TRAIL_RADIUS_METERS := 0.34
const NORMAL_STAMP_STRENGTH := 9
const ROAD_WALKING_STAMP_STRENGTH := 16
const DAILY_DECAY := 7
const NORMAL_TRAFFIC_STRENGTH := 1.0
const ROAD_WALKING_TRAFFIC_STRENGTH := 2.0
const CELL_DAILY_DECAY_RATE := 0.18
const CELL_EPSILON := 0.05
const PATH_CREATE_THRESHOLD := 4.0
const PATH_MATURE_THRESHOLD := 9.0
const PATH_DEGRADE_THRESHOLD := 2.5
const PATH_DEGRADE_DAYS := 3
const YOUNG_PATH_WEIGHT := 1.4
const MATURE_PATH_WEIGHT := 1.0

enum TrailState { NONE, YOUNG, MATURE, DEGRADING }

var _world_size := 0.0
var _cell_size := 1.0
var _resolution := 0
var _pixels := PackedByteArray()
var _texture: ImageTexture
var _image: Image
var _last_positions: Dictionary = {}
var _last_cells: Dictionary = {}
var _cell_strengths: Dictionary = {}
var _cell_states: Dictionary = {}
var _cell_low_days: Dictionary = {}
var _trail_weight_overrides: Dictionary = {}
var _nav_grid: NavGrid
var _dirty := false
var _has_content := false
var _last_upload_time := -INF


func configure(world_size: float, cell_size := 1.0, nav_grid: NavGrid = null) -> void:
	_world_size = maxf(world_size, 1.0)
	_cell_size = maxf(cell_size, 0.001)
	_nav_grid = nav_grid
	_resolution = ceili(_world_size * TEXELS_PER_METER)
	_pixels.resize(_resolution * _resolution)
	_pixels.fill(0)
	_last_positions.clear()
	_last_cells.clear()
	_cell_strengths.clear()
	_cell_states.clear()
	_cell_low_days.clear()
	_trail_weight_overrides.clear()
	_dirty = true
	_has_content = false
	_sync_nav_grid_weights()


func record_walker_position(walker_id: int, position_on_board: Vector3, road_walking: bool) -> void:
	if _resolution <= 0:
		return
	if not _last_positions.has(walker_id):
		_last_positions[walker_id] = position_on_board
		_last_cells[walker_id] = _cell_from_position(position_on_board)
		return
	var previous: Vector3 = _last_positions[walker_id]
	var horizontal_distance := Vector2(position_on_board.x - previous.x, position_on_board.z - previous.z).length()
	if horizontal_distance < SAMPLE_DISTANCE:
		return
	_last_positions[walker_id] = position_on_board
	var stamp_strength := ROAD_WALKING_STAMP_STRENGTH if road_walking else NORMAL_STAMP_STRENGTH
	_stamp_segment(previous, position_on_board, stamp_strength)
	var traffic_strength := ROAD_WALKING_TRAFFIC_STRENGTH if road_walking else NORMAL_TRAFFIC_STRENGTH
	_register_segment_cell_entries(walker_id, previous, position_on_board, traffic_strength)


func forget_walker(walker_id: int) -> void:
	_last_positions.erase(walker_id)
	_last_cells.erase(walker_id)


func total_strength() -> int:
	var total := 0
	for value in _pixels:
		total += int(value)
	return total


func cell_strength(cell: Vector2i) -> float:
	return float(_cell_strengths.get(cell, 0.0))


func cell_state(cell: Vector2i) -> int:
	return int(_cell_states.get(cell, TrailState.NONE))


func active_weight_overrides() -> Dictionary:
	return _trail_weight_overrides.duplicate()


func apply_daily_decay() -> void:
	if not _has_content:
		_decay_nav_cells()
		return
	var has_visible_trail := false
	for index in _pixels.size():
		var next_value := maxi(0, int(_pixels[index]) - DAILY_DECAY)
		_pixels[index] = next_value
		has_visible_trail = has_visible_trail or next_value > 0
	_has_content = has_visible_trail
	_dirty = true
	_decay_nav_cells()


func flush_texture(now_seconds: float) -> Texture2D:
	if _resolution <= 0:
		return null
	if _texture != null and (not _dirty or now_seconds - _last_upload_time < 0.25):
		return _texture
	_image = Image.create_from_data(_resolution, _resolution, false, Image.FORMAT_R8, _pixels)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	_dirty = false
	_last_upload_time = now_seconds
	return _texture


func _stamp_segment(from: Vector3, to: Vector3, strength: int) -> void:
	var delta := Vector2(to.x - from.x, to.z - from.z)
	var distance := delta.length()
	var steps := maxi(1, ceili(distance * TEXELS_PER_METER * 1.5))
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		_stamp(Vector2(lerpf(from.x, to.x, t), lerpf(from.z, to.z, t)), strength)
	_dirty = true


func _register_segment_cell_entries(walker_id: int, from: Vector3, to: Vector3, traffic_strength: float) -> void:
	var previous_registered: Vector2i = _last_cells.get(walker_id, _cell_from_position(from))
	var changed := false
	for cell in _cells_crossed_by_segment(from, to):
		if cell == previous_registered:
			continue
		previous_registered = cell
		_last_cells[walker_id] = cell
		if not _is_nav_cell(cell):
			continue
		_cell_strengths[cell] = float(_cell_strengths.get(cell, 0.0)) + traffic_strength
		_cell_low_days.erase(cell)
		changed = _update_cell_state(cell, false) or changed
	if changed:
		_sync_nav_grid_weights()


func _decay_nav_cells() -> void:
	if _cell_strengths.is_empty() and _cell_states.is_empty():
		return
	var changed := false
	for cell in _cell_strengths.keys().duplicate():
		var strength := float(_cell_strengths[cell]) * (1.0 - CELL_DAILY_DECAY_RATE)
		if strength < CELL_EPSILON and not _cell_states.has(cell):
			_cell_strengths.erase(cell)
			_cell_low_days.erase(cell)
			continue
		_cell_strengths[cell] = strength
		changed = _update_cell_state(cell, true) or changed
	if changed:
		_sync_nav_grid_weights()


func _update_cell_state(cell: Vector2i, from_daily_decay: bool) -> bool:
	var previous_state := int(_cell_states.get(cell, TrailState.NONE))
	var previous_weight: Variant = _trail_weight_overrides.get(cell, null)
	var strength := float(_cell_strengths.get(cell, 0.0))
	var next_state := previous_state
	if strength >= PATH_MATURE_THRESHOLD:
		next_state = TrailState.MATURE
		_cell_low_days.erase(cell)
	elif strength >= PATH_CREATE_THRESHOLD:
		next_state = TrailState.YOUNG
		_cell_low_days.erase(cell)
	elif previous_state != TrailState.NONE and strength < PATH_DEGRADE_THRESHOLD:
		var low_days := int(_cell_low_days.get(cell, 0)) + (1 if from_daily_decay else 0)
		_cell_low_days[cell] = low_days
		if low_days >= PATH_DEGRADE_DAYS:
			next_state = TrailState.NONE
			_cell_states.erase(cell)
			_cell_strengths.erase(cell)
			_cell_low_days.erase(cell)
			_trail_weight_overrides.erase(cell)
			return previous_state != TrailState.NONE or previous_weight != null
		next_state = TrailState.DEGRADING
	elif previous_state != TrailState.NONE:
		_cell_low_days.erase(cell)

	if next_state == TrailState.NONE:
		_cell_states.erase(cell)
		_trail_weight_overrides.erase(cell)
	elif next_state == TrailState.MATURE:
		_cell_states[cell] = next_state
		_trail_weight_overrides[cell] = MATURE_PATH_WEIGHT
	else:
		_cell_states[cell] = next_state
		_trail_weight_overrides[cell] = YOUNG_PATH_WEIGHT
	return previous_state != next_state or previous_weight != _trail_weight_overrides.get(cell, null)


func _sync_nav_grid_weights() -> void:
	if _nav_grid != null:
		_nav_grid.set_profile_cell_weights(NavGrid.PEDESTRIAN_PROFILE, _trail_weight_overrides)


func _cells_crossed_by_segment(from: Vector3, to: Vector3) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := Vector2(to.x - from.x, to.z - from.z)
	var distance := delta.length()
	var steps := maxi(1, ceili(distance / (_cell_size * 0.5)))
	var seen: Dictionary = {}
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var cell := _cell_from_position(Vector3(lerpf(from.x, to.x, t), 0.0, lerpf(from.z, to.z, t)))
		if seen.has(cell):
			continue
		seen[cell] = true
		cells.append(cell)
	return cells


func _cell_from_position(position_on_board: Vector3) -> Vector2i:
	if _nav_grid != null:
		return _nav_grid.cell_from_position(position_on_board)
	return Vector2i(floori(position_on_board.x / _cell_size), floori(position_on_board.z / _cell_size))


func _is_nav_cell(cell: Vector2i) -> bool:
	return _nav_grid == null or _nav_grid.is_board_cell(cell)


func _stamp(world_position: Vector2, strength: int) -> void:
	var center := _texel_from_world(world_position)
	var radius := ceili(TRAIL_RADIUS_METERS * TEXELS_PER_METER)
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= _resolution:
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= _resolution:
				continue
			var distance := Vector2(float(x - center.x), float(y - center.y)).length() / float(radius)
			if distance > 1.0:
				continue
			var contribution := roundi(float(strength) * (1.0 - distance * distance))
			var index := y * _resolution + x
			_pixels[index] = mini(255, int(_pixels[index]) + contribution)
	_has_content = true


func _texel_from_world(world_position: Vector2) -> Vector2i:
	var half_size := _world_size * 0.5
	var x := floori((world_position.x + half_size) / _world_size * _resolution)
	var y := floori((world_position.y + half_size) / _world_size * _resolution)
	return Vector2i(clampi(x, 0, _resolution - 1), clampi(y, 0, _resolution - 1))
