class_name HeroPocketService
extends RefCounted

## Manages the hero's personal pocket inventory, space checks, item addition/removal,
## formatting, and ground dropping.

const POCKET_CAPACITY := 8
const S = preload("res://game/features/ui/domain/game_strings.gd")

var simulation: Node
var pocket: Dictionary = {} # resource_type -> count, total limited by POCKET_CAPACITY


func configure(p_simulation: Node) -> void:
	simulation = p_simulation


func pocket_total() -> int:
	var total := 0
	for amount in pocket.values():
		total += int(amount)
	return total


func pocket_space_for(_resource_type: String) -> int:
	return POCKET_CAPACITY - pocket_total()


func pocket_has_room() -> bool:
	return pocket_total() < POCKET_CAPACITY


func pocket_amount(resource_type: String) -> int:
	return int(pocket.get(resource_type, 0))


func add_to_pocket(resource_type: String, amount: int) -> int:
	if amount <= 0 or resource_type.is_empty():
		return 0
	var added := mini(amount, pocket_space_for(resource_type))
	if added > 0:
		pocket[resource_type] = pocket_amount(resource_type) + added
	return added


func remove_from_pocket(resource_type: String, amount: int) -> int:
	if amount <= 0 or resource_type.is_empty() or not pocket.has(resource_type):
		return 0
	var current := pocket_amount(resource_type)
	var removed := mini(amount, current)
	if removed <= 0:
		return 0
	if current <= removed:
		pocket.erase(resource_type)
	else:
		pocket[resource_type] = current - removed
	return removed


func pocket_resources() -> Array:
	return pocket.keys().duplicate()


func primary_pocket_resource() -> String:
	for resource_type in pocket.keys():
		if int(pocket.get(resource_type, 0)) > 0:
			return str(resource_type)
	return ""


func pocket_summary() -> String:
	if pocket.is_empty():
		return ""
	var parts: Array[String] = []
	for resource_type in pocket:
		parts.append("%s x%d" % [str(resource_type).capitalize(), int(pocket[resource_type])])
	return " | ".join(parts)


func format_pocket_hint() -> String:
	return S.POCKET_FORMAT % [pocket_total(), POCKET_CAPACITY, (" | " + pocket_summary()) if not pocket.is_empty() else ""]


func drop_pocket_on_ground() -> void:
	if simulation.player_citizen == null or pocket.is_empty():
		return
	simulation._create_resource_pile(simulation.player_citizen.global_position, pocket.duplicate())
	pocket.clear()
	simulation._update_interface(S.POCKET_DROPPED)
	simulation._refresh_interaction_hint()
