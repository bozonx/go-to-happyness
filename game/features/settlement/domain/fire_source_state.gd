class_name FireSourceState
extends RefCounted

enum Phase { BURNING, DYING, EMBERS, OUT }

const LOW_FUEL_THRESHOLD := 2
const EMBER_DURATION_MINUTES := 2 * 60

var fuel := 0
var reserved_fuel := 0
var lit := false
var embers_until_minute := -1


static func from_values(next_fuel: int, next_reserved_fuel: int, next_lit: bool, next_embers_until_minute: int = -1) -> RefCounted:
	var state: RefCounted = load("res://game/features/settlement/domain/fire_source_state.gd").new()
	state.fuel = maxi(0, next_fuel)
	state.reserved_fuel = maxi(0, next_reserved_fuel)
	state.lit = next_lit
	state.embers_until_minute = next_embers_until_minute
	return state


func total_committed_fuel() -> int:
	return fuel + reserved_fuel


func needs_supply(target_fuel: int) -> bool:
	return total_committed_fuel() < target_fuel


func reserve(amount: int) -> void:
	reserved_fuel += maxi(0, amount)


func add_delivered(amount: int, current_minute: int) -> void:
	var delivered := maxi(0, amount)
	var was_embers := phase_at(current_minute) == Phase.EMBERS
	fuel += delivered
	reserved_fuel = maxi(0, reserved_fuel - delivered)
	if was_embers:
		lit = fuel > 0
		embers_until_minute = -1


func consume(amount: int, current_minute: int) -> void:
	fuel = maxi(0, fuel - maxi(0, amount))
	if fuel > 0:
		lit = true
		return
	lit = false
	embers_until_minute = current_minute + EMBER_DURATION_MINUTES


func phase_at(current_minute: int) -> Phase:
	if lit and fuel > LOW_FUEL_THRESHOLD:
		return Phase.BURNING
	if lit and fuel > 0:
		return Phase.DYING
	if embers_until_minute > current_minute:
		return Phase.EMBERS
	return Phase.OUT


func is_burning_at(current_minute: int) -> bool:
	var phase := phase_at(current_minute)
	return phase == Phase.BURNING or phase == Phase.DYING
