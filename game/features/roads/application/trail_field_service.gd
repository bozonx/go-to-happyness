class_name TrailFieldService
extends RefCounted

## Sparse-in-time, continuous-in-world trail field. Texels are only a rendering
## detail: no navigation or gameplay code reads this field in the first pass.

const TEXELS_PER_METER := 4
const SAMPLE_DISTANCE := 0.45
const TRAIL_RADIUS_METERS := 0.34
const NORMAL_STAMP_STRENGTH := 9
const ROAD_WALKING_STAMP_STRENGTH := 16
const DAILY_DECAY := 7

var _world_size := 0.0
var _resolution := 0
var _pixels := PackedByteArray()
var _texture: ImageTexture
var _image: Image
var _last_positions: Dictionary = {}
var _dirty := false
var _has_content := false
var _last_upload_time := -INF


func configure(world_size: float) -> void:
	_world_size = maxf(world_size, 1.0)
	_resolution = ceili(_world_size * TEXELS_PER_METER)
	_pixels.resize(_resolution * _resolution)
	_pixels.fill(0)
	_dirty = true
	_has_content = false


func record_walker_position(walker_id: int, position_on_board: Vector3, road_walking: bool) -> void:
	if _resolution <= 0:
		return
	if not _last_positions.has(walker_id):
		_last_positions[walker_id] = position_on_board
		return
	var previous: Vector3 = _last_positions[walker_id]
	var horizontal_distance := Vector2(position_on_board.x - previous.x, position_on_board.z - previous.z).length()
	if horizontal_distance < SAMPLE_DISTANCE:
		return
	_last_positions[walker_id] = position_on_board
	var stamp_strength := ROAD_WALKING_STAMP_STRENGTH if road_walking else NORMAL_STAMP_STRENGTH
	_stamp_segment(previous, position_on_board, stamp_strength)


func forget_walker(walker_id: int) -> void:
	_last_positions.erase(walker_id)


func total_strength() -> int:
	var total := 0
	for value in _pixels:
		total += int(value)
	return total


func apply_daily_decay() -> void:
	if not _has_content:
		return
	var has_visible_trail := false
	for index in _pixels.size():
		var next_value := maxi(0, int(_pixels[index]) - DAILY_DECAY)
		_pixels[index] = next_value
		has_visible_trail = has_visible_trail or next_value > 0
	_has_content = has_visible_trail
	_dirty = true


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
