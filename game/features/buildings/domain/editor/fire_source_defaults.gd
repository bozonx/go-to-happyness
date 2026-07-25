class_name FireSourceDefaults
extends RefCounted

## Typed schema for `runtime_defaults` of a `fire_source` fixture
## (design_docs/content/building_furnishing.md §3.2, §7.5).
##
## These values are authored in the blueprint and copied into
## FixtureRuntimeState when a building instance is constructed.
## They are **not** the current runtime state — that lives in
## FireSourceState, owned by FireManagementService.

var lit: bool = true
var fuel: int = 4
var fuel_capacity: int = 8


static func from_dict(data: Dictionary) -> FireSourceDefaults:
	var fsd := FireSourceDefaults.new()
	fsd.lit = bool(data.get("lit", true))
	fsd.fuel = maxi(0, int(data.get("fuel", 4)))
	fsd.fuel_capacity = maxi(1, int(data.get("fuel_capacity", 8)))
	return fsd


func to_dict() -> Dictionary:
	return {
		"lit": lit,
		"fuel": fuel,
		"fuel_capacity": fuel_capacity,
	}


static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	# lit must be a bool.
	var lit_val: Variant = data.get("lit", true)
	if not (lit_val is bool):
		errors.append("runtime_defaults.lit must be a boolean")
	# fuel must be a non-negative integer.
	var fuel_val: Variant = data.get("fuel", 4)
	if not (fuel_val is int or fuel_val is float):
		errors.append("runtime_defaults.fuel must be a number")
	elif int(fuel_val) < 0:
		errors.append("runtime_defaults.fuel must be non-negative")
	# fuel_capacity must be a positive integer.
	var cap_val: Variant = data.get("fuel_capacity", 8)
	if not (cap_val is int or cap_val is float):
		errors.append("runtime_defaults.fuel_capacity must be a number")
	elif int(cap_val) < 1:
		errors.append("runtime_defaults.fuel_capacity must be at least 1")
	# Unknown keys are rejected to keep the schema strict.
	var allowed_keys := ["lit", "fuel", "fuel_capacity"]
	for key in data.keys():
		if not (String(key) in allowed_keys):
			errors.append("runtime_defaults has unknown key: %s" % key)
	return errors
