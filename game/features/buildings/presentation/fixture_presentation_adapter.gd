class_name FixturePresentationAdapter
extends RefCounted

## Translates FixtureRuntimeState (fire_source) into visual changes on the
## building node: flame visibility, ember particles, light intensity, and
## wood stack appearance.
##
## The adapter is called from FireManagementService.update_fire_visual.
## It reads the fire phase from FireSourceState and drives the child nodes
## of the building (or the fill object referenced by visual_object_id).
##
## Phase 2A: the adapter walks the building's children directly, matching
## the existing visual layout. When fill objects are spawned at runtime
## (future phase), it will resolve visual_object_id to the correct child.

const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")

## Flame node names in the campfire scene hierarchy.
const NODE_FIRE := "Fire"
const NODE_EMBERS := "Embers"
const NODE_LIGHT := "Light"
const NODE_LOGS := "Logs"

## Light energy by phase.
const LIGHT_BURNING := 1.8
const LIGHT_EMBERS := 0.22
const LIGHT_OUT := 0.0


## Apply fire visual state to a building node.
## building: the completed building Node3D
## fire_state: FireSourceState from fixture or legacy meta
## minute: current game minute for phase calculation
func apply_fire_visual(building: Node3D, fire_state: RefCounted, minute: int) -> void:
	if not is_instance_valid(building) or fire_state == null:
		return
	var phase: int = fire_state.phase_at(minute)
	_apply_phase_to_building(building, phase)


## Apply fire visual state to a specific fill object node (future use,
## when fixtures reference visual_object_id and fill objects are spawned
## at runtime).
func apply_fire_visual_to_node(visual_node: Node3D, fire_state: RefCounted, minute: int) -> void:
	if not is_instance_valid(visual_node) or fire_state == null:
		return
	var phase: int = fire_state.phase_at(minute)
	_apply_phase_to_node(visual_node, phase)


func _apply_phase_to_building(building: Node3D, phase: int) -> void:
	# Walk immediate children and any nested fill objects.
	for child in building.get_children():
		if child is OmniLight3D:
			_apply_light(child, phase)
		# Check if this child is a campfire fill object (has Fire/Embers/Light children).
		if child is Node3D:
			_apply_phase_to_node(child, phase)


func _apply_phase_to_node(node: Node3D, phase: int) -> void:
	# Drive flame visibility.
	var fire_node := node.get_node_or_null(NODE_FIRE)
	if fire_node != null:
		fire_node.visible = phase != FireSourceStateScript.Phase.OUT

	# Drive ember particles.
	var embers_node := node.get_node_or_null(NODE_EMBERS)
	if embers_node is GPUParticles3D:
		(embers_node as GPUParticles3D).emitting = phase != FireSourceStateScript.Phase.OUT

	# Drive light.
	var light_node := node.get_node_or_null(NODE_LIGHT)
	if light_node is OmniLight3D:
		_apply_light(light_node, phase)

	# Drive wood stack visibility (logs remain visible even when out, but
	# could be hidden when completely consumed in a future refinement).
	var logs_node := node.get_node_or_null(NODE_LOGS)
	if logs_node != null:
		logs_node.visible = true


func _apply_light(light: OmniLight3D, phase: int) -> void:
	match phase:
		FireSourceStateScript.Phase.BURNING:
			light.visible = true
			light.light_energy = LIGHT_BURNING
		FireSourceStateScript.Phase.EMBERS:
			light.visible = true
			light.light_energy = LIGHT_EMBERS
		FireSourceStateScript.Phase.DYING:
			light.visible = true
			light.light_energy = LIGHT_EMBERS
		FireSourceStateScript.Phase.OUT:
			light.visible = false
			light.light_energy = LIGHT_OUT
