extends SceneTree

## Diagnostic: builds a contact sheet of world assets and saves it as a PNG.
##
## Hand-authored primitives pass every structural test — the scene loads, the
## bindings resolve, the bounds are sane — and can still be a palm tree with its
## fronds on backwards. This renders them so that can be seen.
##
##   godot --path . --script res://tests/repro/diag_asset_gallery.gd -- <out.png> [ids...]

const COLUMNS := 4
const SPACING := 5.0


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var output_path := arguments[0] if arguments.size() > 0 else "res://asset_gallery.png"
	var ids: Array[StringName] = []
	for index in range(1, arguments.size()):
		ids.append(StringName(arguments[index]))
	if ids.is_empty():
		for asset in WorldAssetCatalog.get_all_assets():
			ids.append(asset.id)
	_build(ids)
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	var image := root.get_texture().get_image()
	image.save_png(output_path)
	print("saved %s (%d assets)" % [output_path, ids.size()])
	quit(0)


func _build(ids: Array[StringName]) -> void:
	var world := Node3D.new()
	root.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -40, 0)
	light.light_energy = 1.2
	world.add_child(light)

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.42, 0.47, 0.52)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.55, 0.58, 0.62)
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	world.add_child(environment)

	var rows := int(ceil(float(ids.size()) / COLUMNS))
	for index in ids.size():
		var asset := WorldAssetCatalog.get_asset(ids[index])
		if asset == null or not ResourceLoader.exists(asset.scene_path):
			continue
		var instance := (load(asset.scene_path) as PackedScene).instantiate() as Node3D
		if instance == null:
			continue
		instance.position = Vector3(
			(index % COLUMNS) * SPACING, 0.0, (index / COLUMNS) * SPACING
		)
		world.add_child(instance)
		var label := Label3D.new()
		label.text = String(asset.id)
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = instance.position + Vector3(0, -0.4, 2.2)
		world.add_child(label)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(COLUMNS * SPACING + 20.0, rows * SPACING + 20.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.38, 0.33)
	plane.material = ground_material
	ground.mesh = plane
	ground.position = Vector3((COLUMNS - 1) * SPACING * 0.5, -0.02, (rows - 1) * SPACING * 0.5)
	world.add_child(ground)

	var camera := Camera3D.new()
	var centre := Vector3((COLUMNS - 1) * SPACING * 0.5, 1.5, (rows - 1) * SPACING * 0.5)
	var distance := maxf(COLUMNS, rows) * SPACING * 0.85
	camera.fov = 55.0
	world.add_child(camera)
	camera.look_at_from_position(centre + Vector3(0, distance * 0.75, distance), centre, Vector3.UP)
	camera.make_current()
