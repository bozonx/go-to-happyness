class_name CitizenAnimationController
extends RefCounted

const WALK_SPEED := 2.2

const STATE_ANIMATIONS := {
	Citizen.State.IDLE: "idle",
	Citizen.State.WAITING: "idle",
	Citizen.State.CHOPPING: "interact-right",
	Citizen.State.SAWING: "interact-right",
	Citizen.State.CONSTRUCTING: "interact-right",
	Citizen.State.EXCAVATING: "interact-right",
	Citizen.State.GATHERING: "interact-right",
	Citizen.State.CLEANING_PILE: "interact-right",
	Citizen.State.EATING: "sit",
	Citizen.State.RESTING: "sit",
	Citizen.State.STUDYING: "sit",
	Citizen.State.RELAXING: "sit",
	Citizen.State.USING_TOILET: "crouch",
	Citizen.State.USING_BUSH: "crouch",
	Citizen.State.FACTORY_WORK: "interact-right",
	Citizen.State.CRAFT_WORK: "interact-right",
	Citizen.State.SCHOOL_WORK: "interact-right",
	Citizen.State.MARKET_WORK: "interact-right",
	Citizen.State.OFFICIAL_WORK: "interact-right",
	Citizen.State.RESEARCHING: "interact-right",
	Citizen.State.EMPLOYMENT_PROCESSING: "interact-right",
	Citizen.State.AI_MOVING: "walk",
	Citizen.State.WORK_POSITION: "interact-right",
	Citizen.State.LEAVING: "walk",
}

# A transient full-body gesture (e.g. "pick-up") that plays once and then hands
# control back to the state/locomotion animation. Cleared as soon as it elapses
# or the citizen starts moving.
var _one_shot_anim: String = ""
var _one_shot_remaining: float = 0.0


func play_one_shot(actor: Citizen, anim_name: String) -> void:
	if actor.animation_player == null:
		return
	var anim := actor.animation_player.get_animation(anim_name)
	if anim == null:
		return
	_one_shot_anim = anim_name
	_one_shot_remaining = anim.length
	actor.animation_player.play(anim_name, 0.15)


func play_hunting_shot(actor: Citizen) -> void:
	for anim_name in ["shoot", "shot", "rifle-shot", "interact-right"]:
		if actor.animation_player != null and actor.animation_player.get_animation(anim_name) != null:
			play_one_shot(actor, anim_name)
			return


# Locomotion picker shared by AI and the player-controlled hero. Walking speeds
# past the sprint threshold (bicycle couriers, hero holding shift) break into a run.
func _locomotion_animation(horizontal_speed: float) -> String:
	if horizontal_speed <= 0.15:
		return ""
	return "sprint" if horizontal_speed > WALK_SPEED * 1.3 else "walk"


func play_animation(actor: Citizen, anim_to_play: String) -> void:
	if actor.animation_player == null or actor.animation_player.get_animation(anim_to_play) == null:
		return
	# A non-looping imported clip can have the right current name after it has
	# ended. Restart it instead of leaving the character frozen in its last pose.
	if actor.animation_player.current_animation != anim_to_play or not actor.animation_player.is_playing():
		actor.animation_player.play(anim_to_play, 0.2)


func update_animations(actor: Citizen, delta: float) -> void:
	if actor.animation_player == null:
		return
	var horizontal_speed := Vector3(actor.velocity.x, 0.0, actor.velocity.z).length()
	# A running one-shot owns the rig until it ends or the citizen starts moving.
	if not _one_shot_anim.is_empty():
		_one_shot_remaining -= delta
		if _one_shot_remaining > 0.0 and horizontal_speed <= 0.15:
			return
		_one_shot_anim = ""
	var locomotion := _locomotion_animation(horizontal_speed)
	var state_anim := STATE_ANIMATIONS.get(actor.state, "idle") as String
	if actor.state == Citizen.State.CONSTRUCTING and actor.is_waiting_for_materials:
		state_anim = "idle"
	var anim_to_play := locomotion if not locomotion.is_empty() else state_anim
	play_animation(actor, anim_to_play)


# Driven every frame by the settlement while the hero is under direct control, so
# the player character animates (walk/run/jump/fall) just like an AI citizen.
func drive_player_animation(actor: Citizen, is_sprinting: bool) -> void:
	if actor.animation_player == null:
		return
	var horizontal_speed := Vector3(actor.velocity.x, 0.0, actor.velocity.z).length()
	var anim_to_play := "idle"
	if not actor.is_on_floor():
		anim_to_play = "jump" if actor.velocity.y > 0.5 else "fall"
	elif horizontal_speed > 0.15:
		anim_to_play = "sprint" if is_sprinting else "walk"
	play_animation(actor, anim_to_play)
