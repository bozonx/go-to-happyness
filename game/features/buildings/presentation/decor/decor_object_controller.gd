class_name DecorObjectController
extends Node3D

## Base controller script attached to decor object scenes.
## Receives runtime/editor properties and updates node visuals (lights, particles, text).

@export var is_lit: bool = true:
	set(val):
		is_lit = val
		_update_state()

@export var light_energy: float = 1.5:
	set(val):
		light_energy = val
		_update_state()

@export var light_color: Color = Color("ffaa44"):
	set(val):
		light_color = val
		_update_state()

@export var sign_text: String = "Happyness":
	set(val):
		sign_text = val
		_update_state()

@export var has_pot: bool = true:
	set(val):
		has_pot = val
		_update_state()

@export var has_lantern: bool = true:
	set(val):
		has_lantern = val
		_update_state()

var _properties: Dictionary = {}


func _ready() -> void:
	_update_state()


func apply_decor_properties(props: Dictionary) -> void:
	_properties = props.duplicate()
	if props.has("is_lit"):
		is_lit = bool(props["is_lit"])
	if props.has("light_energy"):
		light_energy = float(props["light_energy"])
	if props.has("light_color"):
		var c = props["light_color"]
		if c is Color:
			light_color = c
		elif c is String:
			light_color = Color(c)
	if props.has("sign_text"):
		sign_text = String(props["sign_text"])
	if props.has("has_pot"):
		has_pot = bool(props["has_pot"])
	if props.has("has_lantern"):
		has_lantern = bool(props["has_lantern"])
	_update_state()


func get_decor_properties() -> Dictionary:
	return {
		"is_lit": is_lit,
		"light_energy": light_energy,
		"light_color": light_color.to_html(false),
		"sign_text": sign_text,
		"has_pot": has_pot,
		"has_lantern": has_lantern
	}


func _update_state() -> void:
	var light_node := find_child("Light", true, false) as Light3D
	if light_node != null:
		light_node.visible = is_lit
		light_node.light_energy = light_energy
		light_node.light_color = light_color

	var fire_particles := find_child("FireParticles", true, false)
	if fire_particles != null:
		fire_particles.visible = is_lit

	var fire_mesh := find_child("FireMesh", true, false)
	if fire_mesh != null:
		fire_mesh.visible = is_lit

	var pot_node := find_child("CookingPot", true, false)
	if pot_node != null:
		pot_node.visible = has_pot

	var lantern_node := find_child("Lantern", true, false)
	if lantern_node != null:
		lantern_node.visible = has_lantern

	var label_node := find_child("SignLabel", true, false) as Label3D
	if label_node != null:
		label_node.text = sign_text
