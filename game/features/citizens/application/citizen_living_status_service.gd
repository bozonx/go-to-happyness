class_name CitizenLivingStatusService
extends RefCounted

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")


func refresh_all(citizens: Array, has_lit_communal_fire: bool, is_night: bool) -> void:
	for citizen in citizens:
		refresh_citizen(citizen, has_lit_communal_fire, is_night)


func refresh_citizen(citizen: Citizen, has_lit_communal_fire: bool, is_night: bool) -> void:
	if not is_instance_valid(citizen):
		return
	_apply_home_status(citizen)
	_apply_communal_fire_status(citizen, has_lit_communal_fire, is_night)


func _apply_home_status(citizen: Citizen) -> void:
	if not is_instance_valid(citizen.home):
		citizen.set_status_effect(CitizenStatusEffectScript.NO_HOME, "No home", 1.0)
		citizen.clear_status_effect(CitizenStatusEffectScript.TENT_SHELTER)
		return
	citizen.clear_status_effect(CitizenStatusEffectScript.NO_HOME)
	if citizen.home.has_meta("is_tent"):
		citizen.set_status_effect(CitizenStatusEffectScript.TENT_SHELTER, "Tent shelter", 0.0)
	else:
		citizen.clear_status_effect(CitizenStatusEffectScript.TENT_SHELTER)


func _apply_communal_fire_status(citizen: Citizen, has_lit_communal_fire: bool, is_night: bool) -> void:
	if is_night and not has_lit_communal_fire:
		citizen.set_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE, "No lit communal fire", 1.0)
	else:
		citizen.clear_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE)
