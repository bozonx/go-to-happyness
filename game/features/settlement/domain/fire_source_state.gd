class_name FireSourceState
extends RefCounted

var fuel := 0
var reserved_fuel := 0
var lit := false


static func from_values(next_fuel: int, next_reserved_fuel: int, next_lit: bool) -> RefCounted:
	var state: RefCounted = load("res://game/features/settlement/domain/fire_source_state.gd").new()
	state.fuel = maxi(0, next_fuel)
	state.reserved_fuel = maxi(0, next_reserved_fuel)
	state.lit = next_lit
	return state


func total_committed_fuel() -> int:
	return fuel + reserved_fuel


func needs_supply(target_fuel: int) -> bool:
	return total_committed_fuel() < target_fuel


func reserve(amount: int) -> void:
	reserved_fuel += maxi(0, amount)


func add_delivered(amount: int) -> void:
	var delivered := maxi(0, amount)
	fuel += delivered
	reserved_fuel = maxi(0, reserved_fuel - delivered)
	lit = fuel > 0


func consume(amount: int) -> void:
	fuel = maxi(0, fuel - maxi(0, amount))
	lit = fuel > 0
