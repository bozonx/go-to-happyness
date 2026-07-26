class_name MapEditorCamera
extends Camera3D

## Free orbital camera of the territory editor (map_editor.md §3.4).
##
## WASD across the plane, `Q`/`E` up and down the orbit, right mouse to turn,
## middle mouse to pan, wheel to zoom, `F` to focus what is selected, `Home` to
## frame the whole board. This matches the settlement view and building editor.
##
## The distance limits scale with the board: framing a 512 m map from the 90 m
## ceiling the laboratory uses would put the author inside a hillside. `Home` is
## therefore not a fixed number but a fit computed from the field of view.

const PAN_SPEED := 24.0
const ORBIT_SPEED := 90.0
const MOUSE_ORBIT := 0.35
const MOUSE_PAN_FACTOR := 0.00075
const ZOOM_STEP := 0.08
const MIN_DISTANCE := 4.0
const MIN_PITCH := 5.0
const MAX_PITCH := 88.0

var target := Vector3.ZERO
var yaw := 42.0
var pitch := 52.0
var distance := 48.0

var _orbiting := false
var _panning := false
var _max_distance := 400.0
var _board_metres := 128.0
## Fraction of the window height the 3D view actually occupies, and how far the
## centre of that view sits from the centre of the window, in pixels.
var _view_fraction := 1.0
var _view_pixel_shift := 0.0
var _window_height := 1.0


## The 3D fills the whole window, but the author only sees the hole between the
## panels: the top bar, the palette and the status line cover a fifth of the
## screen between them. Framing against the window instead of against that hole
## puts the near corner of the board behind the palette — which is exactly where
## "show me the whole map" must not put it.
func set_view_rect(view: Rect2, window_size: Vector2) -> void:
	if window_size.y <= 0.0 or view.size.y <= 0.0:
		return
	_window_height = window_size.y
	_view_fraction = clampf(view.size.y / window_size.y, 0.1, 1.0)
	# Positive means the visible centre is above the window's, so the image has to
	# ride up by that much.
	_view_pixel_shift = (window_size.y * 0.5) - (view.position.y + view.size.y * 0.5)


func configure(board_metres: float) -> void:
	_board_metres = maxf(board_metres, 1.0)
	# Far enough out to see the whole board from any angle, and no further: an
	# unbounded zoom is how an author loses their map off the edge of the screen.
	_max_distance = _board_metres * 2.0
	far = maxf(far, _board_metres * 4.0)
	frame_board()


## Fits the whole board in view, using the vertical field of view so the fit holds
## on any window shape.
##
## What has to fit is the board's DIAGONAL, not its side: seen from a corner at
## 42°, the far corner is √2 half-widths away, and fitting the side instead leaves
## two corners off the screen. The extra tenth is margin so the edge of the world
## is not flush against the edge of the window.
const FRAME_MARGIN := 1.1


func frame_board() -> void:
	target = Vector3.ZERO
	yaw = 42.0
	pitch = 52.0
	var half_diagonal := _board_metres * 0.5 * sqrt(2.0) * FRAME_MARGIN
	distance = clampf(
		half_diagonal / (tan(deg_to_rad(fov * 0.5)) * _view_fraction),
		MIN_DISTANCE, _max_distance,
	)
	apply()


func focus_on(point: Vector3, span := 8.0) -> void:
	target = point
	distance = clampf(span * 2.5, MIN_DISTANCE, _max_distance)
	apply()


## Sustained input, read once a frame. Returns true when anything moved, so the
## host can refresh what depends on the view.
func process_keys(delta: float) -> bool:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		pan.x += 1.0
	var orbit := 0.0
	if Input.is_key_pressed(KEY_Q):
		orbit -= 1.0
	if Input.is_key_pressed(KEY_E):
		orbit += 1.0
	if pan == Vector2.ZERO and is_zero_approx(orbit):
		return false
	var radians := deg_to_rad(yaw)
	var forward := Vector3(sin(radians), 0.0, cos(radians))
	var right := Vector3(cos(radians), 0.0, -sin(radians))
	# Panning scales with zoom: a step that reads as a nudge up close would crawl
	# when the whole board is in view.
	var speed := PAN_SPEED * delta * maxf(distance / 40.0, 0.25)
	target += (forward * pan.y + right * pan.x) * speed
	var reach := _board_metres * 0.75
	target.x = clampf(target.x, -reach, reach)
	target.z = clampf(target.z, -reach, reach)
	yaw = fposmod(yaw + orbit * ORBIT_SPEED * delta, 360.0)
	apply()
	return true


## Mouse events the camera claims. Returns true when it consumed the event, so
## the host does not also hand it to the active mode.
func handle_mouse_button(event: InputEventMouseButton) -> bool:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			return true
		MOUSE_BUTTON_RIGHT:
			# Shift+right belongs to an active tool's inverse operation.  On release
			# it may already be up, so claim only a drag this camera actually began.
			if event.pressed:
				if event.shift_pressed:
					return false
				_orbiting = true
				return true
			if _orbiting:
				_orbiting = false
				return true
			return false
		MOUSE_BUTTON_WHEEL_UP:
			if event.shift_pressed or event.ctrl_pressed:
				return false
			if event.pressed:
				_zoom(-1.0)
			return true
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.shift_pressed or event.ctrl_pressed:
				return false
			if event.pressed:
				_zoom(1.0)
			return true
	# `Alt`+left is the second way to orbit, for mice without a usable right button.
	if event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed:
		_orbiting = event.pressed
		return true
	return false


func handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if not _orbiting:
		if not _panning:
			return false
		_pan(event.relative)
		return true
	yaw = fposmod(yaw - event.relative.x * MOUSE_ORBIT, 360.0)
	pitch = clampf(pitch + event.relative.y * MOUSE_ORBIT, MIN_PITCH, MAX_PITCH)
	apply()
	return true


func is_orbiting() -> bool:
	return _orbiting


func _pan(mouse_delta: Vector2) -> void:
	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var speed := distance * MOUSE_PAN_FACTOR
	target -= right * mouse_delta.x * speed
	target += forward * mouse_delta.y * speed
	var reach := _board_metres * 0.75
	target.x = clampf(target.x, -reach, reach)
	target.z = clampf(target.z, -reach, reach)
	apply()


func apply() -> void:
	var radians := deg_to_rad(yaw)
	var tilt := deg_to_rad(pitch)
	global_position = target + Vector3(
		sin(radians) * cos(tilt),
		sin(tilt),
		cos(radians) * cos(tilt),
	) * distance
	look_at(target, Vector3.UP)
	if is_zero_approx(_view_pixel_shift):
		return
	# Slide the camera along its own up axis so what it is aimed at lands in the
	# middle of the visible hole rather than the middle of the window. Moving the
	# camera down raises the image, hence the sign.
	var view_height := 2.0 * distance * tan(deg_to_rad(fov * 0.5))
	global_translate(-global_transform.basis.y * (_view_pixel_shift / _window_height) * view_height)


## Proportional, so one wheel notch means the same amount of "closer" at every
## scale instead of a fixed number of metres.
func _zoom(direction: float) -> void:
	distance = clampf(distance * (1.0 + ZOOM_STEP * direction), MIN_DISTANCE, _max_distance)
	apply()
