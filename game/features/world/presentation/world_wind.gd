class_name WorldWind
extends RefCounted

## The single place where the world's wind reaches anything that draws
## (design_docs/engine/world_environment.md §9).
##
## Wind is one global world parameter, and before this it had two half-owners:
## `GridTerrainWorld.set_wind` existed and **nobody ever called it**, so the
## terrain grass stood still, while the fill-mode vegetation had no sway at all.
## Two silent consumers of one parameter is how a world ends up with flags blowing
## one way and grass another.
##
## Foliage materials read the wind as global shader uniforms rather than being
## walked and poked one by one: every bush duplicates its material per instance
## (see `DecorObjectController._set_albedo`), so "set it on each material" would
## mean traversing every plant on the map every frame.

const GLOBAL_DIRECTION := &"world_wind_direction"
const GLOBAL_STRENGTH := &"world_wind_strength"

## Weather wind is a broad 0..1-ish figure; foliage needs a little movement even
## in dead calm, or a still day reads as a frozen screenshot.
const MINIMUM_STIRRING := 0.12

## Что было опубликовано в последний раз. Хранится здесь, а не спрашивается у
## `RenderingServer`: `global_shader_parameter_get` под dummy-рендером (то есть в
## каждом headless-прогоне) отдаёт null, и «спросить у сервера» означало бы, что
## ветер нельзя проверить ни одним тестом.
static var _direction := Vector2.RIGHT
static var _strength := MINIMUM_STIRRING


## Publishes the snapshot's wind to every visual consumer. `terrain` may be null —
## the weather lab and the map editor have foliage but no board.
static func apply(snapshot: EnvironmentSnapshot, terrain: GridTerrainWorld = null) -> void:
	if snapshot == null:
		return
	var direction := snapshot.wind_vector
	if direction.length_squared() <= 0.000001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var strength := maxf(clampf(snapshot.wind_strength, 0.0, 1.0), MINIMUM_STIRRING)
	set_wind(direction, strength, terrain)


## Direct form, for labs and tests that drive the wind by hand rather than from a
## snapshot.
static func set_wind(
	direction: Vector2,
	strength: float,
	terrain: GridTerrainWorld = null
) -> void:
	var axis := direction.normalized() if direction.length_squared() > 0.000001 else Vector2.RIGHT
	var amount := clampf(strength, 0.0, 1.0)
	_direction = axis
	_strength = amount
	RenderingServer.global_shader_parameter_set(GLOBAL_DIRECTION, axis)
	RenderingServer.global_shader_parameter_set(GLOBAL_STRENGTH, amount)
	if terrain != null and is_instance_valid(terrain):
		terrain.set_wind(axis, amount)


## What the shaders are currently being told, for tests and for the labs' readouts.
static func current() -> Dictionary:
	return {"direction": _direction, "strength": _strength}


## Whether the globals the foliage shader declares exist at all. A missing
## declaration does not fail loudly — the shader simply refuses to compile, and
## the plants turn up untextured in the game rather than red in a test.
static func globals_declared() -> bool:
	var names := RenderingServer.global_shader_parameter_get_list()
	return GLOBAL_DIRECTION in names and GLOBAL_STRENGTH in names
