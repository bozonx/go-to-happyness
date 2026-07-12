extends Node3D
## Демо terraforming на godot_voxel (гладкий SDF-террейн, стиль 7 Days to Die).
## Управление: WASD + мышь — полёт; ЛКМ — копать; ПКМ — насыпать; Esc — отпустить мышь.

const DIG_RADIUS := 3.0     # радиус сферы редактирования
const REACH := 40.0         # дальность луча "куда копаем"
const FLY_SPEED := 24.0
const MOUSE_SENS := 0.0025

var terrain: VoxelLodTerrain
var cam: Camera3D
var _yaw := 0.0
var _pitch := -0.5


func _ready() -> void:
	# --- Освещение / окружение (иначе меши чёрные) ---
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# --- Гладкий воксельный террейн ---
	terrain = VoxelLodTerrain.new()
	terrain.mesher = VoxelMesherTransvoxel.new()

	var gen := VoxelGeneratorNoise2D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.004
	gen.noise = noise
	gen.channel = VoxelBuffer.CHANNEL_SDF   # SDF => гладкая поверхность + копаемость
	gen.height_start = -40.0
	gen.height_range = 70.0
	terrain.generator = gen

	terrain.generate_collisions = true
	terrain.view_distance = 256

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.52, 0.35)
	terrain.material = mat

	add_child(terrain)

	# --- Камера + VoxelViewer (террейн стримится вокруг него) ---
	cam = Camera3D.new()
	cam.position = Vector3(0, 55, 40)
	add_child(cam)
	cam.add_child(VoxelViewer.new())
	_apply_look()

	_make_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "WASD+мышь — полёт   ЛКМ — копать   ПКМ — насыпать   Esc — курсор"
	lbl.position = Vector2(12, 8)
	layer.add_child(lbl)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)
		_apply_look()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_edit(VoxelTool.MODE_REMOVE)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_edit(VoxelTool.MODE_ADD)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _apply_look() -> void:
	cam.transform.basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)


func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_SPACE): dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT): dir -= Vector3.UP
	cam.position += dir.normalized() * FLY_SPEED * delta


## Копание / насыпание сферой в точке, куда смотрит камера.
func _edit(mode: int) -> void:
	var vt := terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_SDF
	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	var hit := vt.raycast(origin, forward, REACH)
	if hit != null:
		vt.mode = mode
		vt.do_sphere(hit.position, DIG_RADIUS)
