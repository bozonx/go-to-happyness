class_name CitizenNeedsState
extends RefCounted

## Deterministic personal-need state for a citizen: hunger, satisfaction,
## fatigue, recovery, buffs, debuffs, and status effects. No nodes, physics,
## rendering, simulation, or wall-clock time.

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")

var hunger := 100.0
var satisfaction := 72.0
var fatigue := 0.0
var continuous_work_hours := 0.0
var satisfaction_tick := 0.0
var recovery_until_workday_id := 0
var buffs: Dictionary = {}
var debuffs: Dictionary = {}
var status_effects: Dictionary = {}


func get_satisfaction_cap() -> float:
	var cap := 100.0
	for penalty in debuffs.values():
		cap -= float(penalty)
	return maxf(10.0, cap)


func receive_meal(served: bool, cooked := true, water_available := true) -> void:
	if not served:
		hunger = maxf(0.0, hunger - 18.0)
		satisfaction = maxf(0.0, satisfaction - 12.0)
		return
	if cooked:
		hunger = minf(100.0, hunger + 35.0)
		if water_available:
			satisfaction = minf(get_satisfaction_cap(), satisfaction + 8.0)
		else:
			satisfaction = minf(get_satisfaction_cap(), satisfaction + 4.0)
		buffs["canteen_meal"] = 8.0
	else:
		# Raw emergency ration: half the nutrition, no satisfaction bonus.
		# Used in the tent era when there is no cook or the cooking fire is out.
		hunger = minf(100.0, hunger + 17.5)


func update_effects(delta: float) -> void:
	for buff_id in buffs.keys():
		var time_left := float(buffs[buff_id]) - delta
		if time_left <= 0.0:
			buffs.erase(buff_id)
		else:
			buffs[buff_id] = time_left


func add_debuff(debuff_id: String, value: float) -> void:
	debuffs[debuff_id] = value


func remove_debuff(debuff_id: String) -> void:
	debuffs.erase(debuff_id)


func set_status_effect(status_id: StringName, label: String, severity := 0.0, duration_hours := -1.0) -> void:
	status_effects[status_id] = CitizenStatusEffectScript.create(status_id, label, severity, duration_hours)


func clear_status_effect(status_id: StringName) -> void:
	status_effects.erase(status_id)


func has_status_effect(status_id: StringName) -> bool:
	return status_effects.has(status_id)


func status_effect_labels() -> Array[String]:
	var labels: Array[String] = []
	for status in status_effects.values():
		if status != null and not str(status.label).is_empty():
			labels.append(str(status.label))
	return labels


func is_dangerously_tired() -> bool:
	return continuous_work_hours > 48.0 or fatigue >= 80.0


func is_recovering(current_workday_id: int) -> bool:
	return recovery_until_workday_id >= current_workday_id
