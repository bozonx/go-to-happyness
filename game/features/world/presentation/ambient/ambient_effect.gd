class_name AmbientEffect
extends Node3D

## Base for world effects that react to weather and daylight but own no gameplay:
## fireflies, smoke, spray, a flock of birds (design_docs/engine/map_fill_mode.md
## §9.2.1, design_docs/engine/world_environment.md).
##
## The contract exists because the first such effect did not have one. Fireflies
## were reached through a typed `Array[FirefliesEffect]` that `MapEntityPresenter`
## collected, `WorldSetup` republished and `SkyAndWeatherController` iterated by
## name — four files that had to be edited to add a second effect, and a fifth to
## add a third. Here the weather controller publishes one snapshot to a group, and
## a new effect is a scene plus a catalog entry, exactly like every other asset.
##
## An effect must not read the clock or the weather model itself. `EnvironmentSnapshot`
## is the single outward-facing answer to "what is the world doing right now"; an
## effect that queried the model directly would be a second reader that drifts the
## moment the director interpolates.

## Effects announce themselves rather than being registered by whoever built them:
## a firefly cluster placed by the map presenter, one dropped into a hand-authored
## scene and one instanced by a test all have to be driven the same way.
const GROUP := &"ambient_effect"


func _ready() -> void:
	add_to_group(GROUP)


## Called every visual update with the world's current state. The default does
## nothing, so an effect that is purely decorative stays a scene with no script.
func apply_environment(_snapshot: EnvironmentSnapshot) -> void:
	pass


## Authoring props from the placed entity's archetype, applied before `_ready`
## (see `MapEntityPresenter._make_view`).
func apply_entity_props(_props: Dictionary) -> void:
	pass


## Editors draw the world at no particular hour, so an effect that only shows at
## night would be invisible exactly when the author is placing it. In preview it
## must show itself and its extent instead — an author who cannot see what they
## placed cannot place it well.
##
## This is deliberately an explicit call from the editor rather than "nobody has
## published to me yet": at map load the game has also published nothing yet, and
## guessing would flash every night effect on in broad daylight.
func set_authoring_preview(_enabled: bool) -> void:
	pass


## Hands the snapshot to every live effect. One call site, so "what drives ambient
## effects" has one answer.
static func publish(tree: SceneTree, snapshot: EnvironmentSnapshot) -> void:
	if tree == null or snapshot == null:
		return
	for node: Node in tree.get_nodes_in_group(GROUP):
		var effect := node as AmbientEffect
		if effect != null and is_instance_valid(effect):
			effect.apply_environment(snapshot)
