class_name CitizenVisualBuilder
extends RefCounted

const MODEL_PREFIXES := {
	"unassigned": "common",
	"builder": "worker",
	"forestry": "worker",
	"farming": "worker",
	"excavation": "worker",
	"courier": "courier",
	"cook": "common",
	"teacher": "teacher",
	"factory_worker": "worker",
	"engineer": "worker",
	"seller": "common",
	"craftsman": "worker",
	"official": "official",
}

const RANDOM_HEADS_MALE := [
	"common-male", "courier-male", "official-male", "teacher-male", "worker-male"
]
const RANDOM_HEADS_FEMALE := [
	"common-female", "courier-female", "official-female", "teacher-female", "worker-female"
]

const SKIN_COLORS := [
	Color("f1976e"),
	Color("f1c09a"),
	Color("af6142"),
	Color("d8a27d"),
	Color("753a22"),
]

const HAIR_COLORS := [
	Color("1c1d1f"),
	Color("3b2219"),
	Color("7a431d"),
	Color("b58135"),
	Color("5a5c5e"),
]

const CLOTHING_COLORS := [
	Color("1e3d59"),
	Color("ff6e40"),
	Color("17b890"),
	Color("868ba2"),
	Color("4a4552"),
	Color("a83232"),
	Color("d4af37"),
	Color("228b22"),
]

# These clips represent persistent states, not one-off gestures. Imported GLB
# animations default to non-looping, so configure the runtime copy explicitly.
const LOOPING_ANIMATIONS := [
	"idle", "walk", "sprint", "crouch", "sit", "interact-right",
]

static var _shared_shader_material: ShaderMaterial
static var _model_scene_cache: Dictionary = {}
static var _head_mesh_cache: Dictionary = {}


func setup_visuals(actor: Citizen) -> void:
	_randomize_appearance(actor)
	_update_character_model(actor)
	_setup_idle_indicator(actor)
	_setup_privacy_blur(actor)


func update_character_model(actor: Citizen) -> void:
	_update_character_model(actor)


func _randomize_appearance(actor: Citizen) -> void:
	if actor.skin_color == Color.WHITE:
		actor.skin_color = SKIN_COLORS.pick_random()
	if actor.shirt_color == Color.WHITE:
		actor.shirt_color = CLOTHING_COLORS.pick_random()
	if actor.pants_color == Color.WHITE:
		actor.pants_color = CLOTHING_COLORS.pick_random()
		while actor.pants_color == actor.shirt_color:
			actor.pants_color = CLOTHING_COLORS.pick_random()
	if actor.hair_color == Color.WHITE:
		actor.hair_color = HAIR_COLORS.pick_random()


func _setup_idle_indicator(actor: Citizen) -> void:
	var idle_indicator := Label3D.new()
	idle_indicator.position = Vector3(0.0, 2.05, 0.0)
	idle_indicator.text = "No permanent work"
	idle_indicator.font_size = 32
	idle_indicator.outline_size = 6
	idle_indicator.modulate = Color("f0c45d")
	idle_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	idle_indicator.no_depth_test = true
	idle_indicator.visible = false
	actor.add_child(idle_indicator)
	actor.idle_indicator = idle_indicator


func _setup_privacy_blur(actor: Citizen) -> void:
	var blur := MeshInstance3D.new()
	blur.name = "PrivacyBlur"
	blur.visible = false
	blur.position = Vector3(0.0, 1.1, 0.0)
	blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.4)
	blur.mesh = quad

	var material := ShaderMaterial.new()
	material.shader = load("res://game/features/citizens/presentation/privacy_pixelize.gdshader")
	material.render_priority = 1
	blur.material_override = material

	actor.add_child(blur)
	actor._privacy_blur = blur


func _setup_body_mesh(actor: Citizen) -> void:
	var body := MeshInstance3D.new()
	body.name = "FallbackBody"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 1.15
	body.mesh = body_mesh
	body.position.y = 0.65
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("5d92b2")
	body.material_override = body_material
	actor.add_child(body)
	actor.body_material = body_material


func _setup_head_mesh(actor: Citizen) -> void:
	var head := MeshInstance3D.new()
	head.name = "FallbackHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	head.position.y = 1.5
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("b8d8c1")
	head.material_override = head_material
	actor.add_child(head)


func _resolve_model_prefix(actor: Citizen) -> String:
	# The hero always wears the constable model, regardless of their civic role.
	if actor.is_hero:
		return "policeman"
	return MODEL_PREFIXES.get(actor.specialization, "common")


func _update_character_model(actor: Citizen) -> void:
	var prefix := _resolve_model_prefix(actor)
	var path := "res://assets/characters/%s-%s.glb" % [prefix, actor.gender]
	if DisplayServer.get_name() == "headless":
		if is_instance_valid(actor.current_character_mesh):
			actor.current_character_mesh.queue_free()
			actor.current_character_mesh = null
		actor.current_body_mesh = null
		actor.current_head_mesh = null
		actor.animation_player = null
		actor.current_model_path = ""
		_setup_fallback_mesh(actor)
		return

	if not FileAccess.file_exists(path):
		path = "res://assets/characters/common-%s.glb" % [actor.gender]

	if not FileAccess.file_exists(path):
		actor.current_body_mesh = null
		actor.current_head_mesh = null
		actor.animation_player = null
		actor.current_model_path = ""
		_setup_fallback_mesh(actor)
		return

	if actor.current_model_path == path:
		_update_mesh_colors(actor)
		return

	# Clean up fallback mesh or previous model if it exists
	if is_instance_valid(actor.current_character_mesh):
		actor.current_character_mesh.queue_free()
		actor.current_character_mesh = null
	actor.current_body_mesh = null
	actor.current_head_mesh = null
	actor.animation_player = null

	var fallback_body = actor.get_node_or_null("FallbackBody")
	if fallback_body:
		fallback_body.queue_free()
	var fallback_head = actor.get_node_or_null("FallbackHead")
	if fallback_head:
		fallback_head.queue_free()
	var dummy_mesh = actor.get_node_or_null("VisualMeshAnchor")
	if dummy_mesh:
		dummy_mesh.queue_free()

	var scene := _character_scene(path)
	if scene != null:
		var inst := scene.instantiate() as Node3D
		# Rotate 180 degrees to align face with movement direction (-Z forward)
		inst.rotation.y = PI
		inst.scale = Vector3(2.65, 2.65, 2.65)

		# Regular citizens get a stable, randomly assigned head; the hero keeps the
		# constable model's own head so their appearance never shuffles.
		if not actor.is_hero:
			_randomize_head_on_instance(actor, inst)

		actor.add_child(inst)
		actor.current_character_mesh = inst
		actor.current_model_path = path

		# Apply shader material and colors
		if _shared_shader_material == null:
			_shared_shader_material = ShaderMaterial.new()
			_shared_shader_material.shader = load("res://game/features/citizens/presentation/citizen_color_swap.gdshader")
			_shared_shader_material.set_shader_parameter("albedo_texture", load("res://assets/characters/Textures/colormap.png"))

		actor.current_body_mesh = _find_node_by_name(inst, "body-mesh") as MeshInstance3D
		actor.current_head_mesh = _find_node_by_name(inst, "head-mesh") as MeshInstance3D
		if actor.current_body_mesh:
			actor.current_body_mesh.material_override = _shared_shader_material
		if actor.current_head_mesh:
			actor.current_head_mesh.material_override = _shared_shader_material
			actor.current_head_mesh.visible = actor.head_visible

		_update_mesh_colors(actor)

		# To satisfy existing startup tests that assert an immediate MeshInstance3D child exists:
		var anchor := MeshInstance3D.new()
		anchor.name = "VisualMeshAnchor"
		anchor.visible = false
		actor.add_child(anchor)

		# Set up animations
		actor.animation_player = inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if actor.animation_player != null:
			for anim_name in LOOPING_ANIMATIONS:
				var anim = actor.animation_player.get_animation(anim_name)
				if anim != null:
					anim.loop_mode = Animation.LOOP_LINEAR
			actor._play_animation("idle")


func _update_mesh_colors(actor: Citizen) -> void:
	if actor.current_character_mesh == null:
		return
	# Clothing is only recoloured on the generic "common" citizen, so the tailored
	# professional models (worker/teacher/courier/official) keep their uniform. The
	# hero keeps everything the constable texture provides and only takes a skin tone.
	var uses_common_model := _resolve_model_prefix(actor) == "common"
	var swap_clothing := 1.0 if uses_common_model and not actor.is_hero else 0.0
	var swap_hair := 0.0 if actor.is_hero else 1.0
	for mesh in [actor.current_body_mesh, actor.current_head_mesh]:
		if mesh == null:
			continue
		mesh.set_instance_shader_parameter("skin_color", actor.skin_color)
		mesh.set_instance_shader_parameter("shirt_color", actor.shirt_color)
		mesh.set_instance_shader_parameter("pants_color", actor.pants_color)
		mesh.set_instance_shader_parameter("hair_color", actor.hair_color)
		mesh.set_instance_shader_parameter("swap_skin", 1.0)
		mesh.set_instance_shader_parameter("swap_shirt", swap_clothing)
		mesh.set_instance_shader_parameter("swap_pants", swap_clothing)
		mesh.set_instance_shader_parameter("swap_hair", swap_hair)


func _randomize_head_on_instance(actor: Citizen, inst: Node3D) -> void:
	# Pick the donor head exactly once; every later rebuild reuses it so the face
	# stays constant for the citizen's whole life.
	if actor.head_model_name.is_empty():
		var pool := RANDOM_HEADS_MALE if actor.gender == "male" else RANDOM_HEADS_FEMALE
		actor.head_model_name = pool.pick_random()
	var donor_mesh := _donor_head_mesh(actor.head_model_name)
	var target_head = _find_node_by_name(inst, "head-mesh") as MeshInstance3D
	if donor_mesh != null and target_head != null:
		target_head.mesh = donor_mesh


func _setup_fallback_mesh(actor: Citizen) -> void:
	if not actor.has_node("FallbackBody"):
		_setup_body_mesh(actor)
	if not actor.has_node("FallbackHead"):
		_setup_head_mesh(actor)


static func _character_scene(path: String) -> PackedScene:
	if not _model_scene_cache.has(path):
		_model_scene_cache[path] = load(path) as PackedScene
	return _model_scene_cache[path] as PackedScene


static func _donor_head_mesh(model_name: String) -> Mesh:
	if _head_mesh_cache.has(model_name):
		return _head_mesh_cache[model_name] as Mesh
	var path := "res://assets/characters/%s.glb" % model_name
	var mesh: Mesh = null
	if FileAccess.file_exists(path):
		var donor_scene := _character_scene(path)
		if donor_scene != null:
			var donor_inst := donor_scene.instantiate()
			var donor_head = _find_node_by_name(donor_inst, "head-mesh") as MeshInstance3D
			if donor_head != null:
				mesh = donor_head.mesh
			donor_inst.free()
	_head_mesh_cache[model_name] = mesh
	return mesh


static func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var res = _find_node_by_name(child, node_name)
		if res:
			return res
	return null
