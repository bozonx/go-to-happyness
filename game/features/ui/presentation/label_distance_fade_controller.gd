class_name LabelDistanceFadeController
extends RefCounted

const LABEL_FADE_NEAR := 8.0
const LABEL_FADE_FAR := 22.0

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func update_label_distance_fading() -> void:
	if simulation == null or simulation.camera == null:
		return
	var cam_pos: Vector3 = simulation.camera.global_position
	# Resource pile labels
	for pile in simulation.resource_piles:
		var pile_node := pile.get("node") as Node3D
		if not is_instance_valid(pile_node):
			continue
		var label := pile_node.get_node_or_null("PileLabel") as Label3D
		if label == null:
			continue
		if not simulation.is_first_person:
			label.modulate.a = 1.0
			continue
		var dist: float = cam_pos.distance_to(pile_node.global_position)
		var alpha: float = _label_alpha_for_distance(dist)
		if alpha <= 0.0:
			label.visible = false
		else:
			label.visible = true
			label.modulate.a = alpha
	# Gather progress labels
	for node in simulation.gather_progress_labels:
		var gp_label := simulation.gather_progress_labels[node] as Label3D
		if not is_instance_valid(gp_label):
			continue
		if not simulation.is_first_person:
			gp_label.modulate.a = 1.0
			continue
		var node3d := node as Node3D
		if not is_instance_valid(node3d):
			continue
		var dist2: float = cam_pos.distance_to(node3d.global_position)
		var alpha2: float = _label_alpha_for_distance(dist2)
		if alpha2 <= 0.0:
			gp_label.visible = false
		else:
			gp_label.visible = true
			gp_label.modulate.a = alpha2
	# Citizen idle indicators
	for citizen in simulation.citizens:
		if not is_instance_valid(citizen):
			continue
		if not simulation.is_first_person:
			citizen.label_distance_alpha = 1.0
			continue
		var dist3: float = cam_pos.distance_to(citizen.global_position)
		citizen.label_distance_alpha = _label_alpha_for_distance(dist3)


func _label_alpha_for_distance(dist: float) -> float:
	if dist <= LABEL_FADE_NEAR:
		return 1.0
	if dist >= LABEL_FADE_FAR:
		return 0.0
	return 1.0 - (dist - LABEL_FADE_NEAR) / (LABEL_FADE_FAR - LABEL_FADE_NEAR)
