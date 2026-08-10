class_name AmbientLifeService
extends RefCounted

## Moves every creature that only wanders (design_docs/engine/map_fill_mode.md §5).
##
## One ticker for all of them, on purpose. The rabbit used to roam inside
## `AmbientSpawner.update_wild_food`, and every further animal would have meant
## another loop next to it with its own slightly different idea of what "blocked"
## and "too far from home" mean.
##
## What lives here is *idle* movement. The moment a creature acquires a goal — a
## wolf that hunts, a horse that is ridden — that goal belongs to the module that
## owns the goal, and it takes the creature off this list. Growing this class into
## an AI would give the project a second actor brain beside `CitizenActor`.

## Как далеко существо видит землю под собой. Высота берётся у террейна, а не
## интегрируется: рельеф — один владелец высоты (`grid_terrain_system.md`).
const GROUND_SNAP := 0.02


class Creature:
	extends RefCounted
	var node: Node3D = null
	var habit: WanderHabit = null
	var home := Vector3.ZERO
	var heading := Vector3.FORWARD
	var pause_left := 0.0
	## Общий ключ стаи: держатся вместе те, у кого он совпадает.
	var flock: StringName = &""


var _creatures: Array[Creature] = []
var _rng: RandomNumberGenerator = null
## Внешний мир, каким его видит служба. Ровно четыре вопроса — этого достаточно,
## и это граница, за которую службе знать не нужно.
var is_blocked: Callable
var terrain_height_at: Callable
var threat_positions: Callable
var _flock_centres: Dictionary = {}


func configure(
	rng: RandomNumberGenerator,
	blocked_query: Callable,
	height_query: Callable = Callable(),
	threats_query: Callable = Callable()
) -> void:
	_rng = rng
	is_blocked = blocked_query
	terrain_height_at = height_query
	threat_positions = threats_query


## Ставит существо на учёт. `home` — там, где оно появилось: домашний радиус
## считается от места рождения, а не от текущей позиции, иначе животное
## «уходит» бесконечно, каждый раз считая новое место домом.
func register(node: Node3D, habit: WanderHabit, flock: StringName = &"") -> void:
	if node == null or habit == null or not habit.is_mobile():
		return
	var creature := Creature.new()
	creature.node = node
	creature.habit = habit
	creature.home = _position_of(node)
	creature.heading = _random_heading()
	creature.flock = flock
	_creatures.append(creature)


func forget(node: Node3D) -> void:
	for index in range(_creatures.size() - 1, -1, -1):
		if _creatures[index].node == node:
			_creatures.remove_at(index)


func clear() -> void:
	_creatures.clear()
	_flock_centres.clear()


func count() -> int:
	return _creatures.size()


## Направление, в котором существо идёт сейчас. Единственный владелец: раньше
## оно лежало в `RabbitSourceRecord`, и «кто его двигает» было двумя ответами.
func heading_of(node: Node3D) -> Vector3:
	for creature in _creatures:
		if creature.node == node:
			return creature.heading
	return Vector3.ZERO


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_drop_dead_creatures()
	_update_flock_centres()
	for creature in _creatures:
		_step(creature, delta)


func _drop_dead_creatures() -> void:
	# Пойманный кролик освобождает ноду; служба узнаёт об этом сама, чтобы охоте
	# не приходилось помнить про ещё один список.
	for index in range(_creatures.size() - 1, -1, -1):
		if not is_instance_valid(_creatures[index].node):
			_creatures.remove_at(index)


func _update_flock_centres() -> void:
	_flock_centres.clear()
	var sums: Dictionary = {}
	var counts: Dictionary = {}
	for creature in _creatures:
		if creature.flock == &"" or creature.habit.cohesion <= 0.0:
			continue
		sums[creature.flock] = (sums.get(creature.flock, Vector3.ZERO) as Vector3) + _position_of(creature.node)
		counts[creature.flock] = int(counts.get(creature.flock, 0)) + 1
	for key: StringName in sums:
		_flock_centres[key] = (sums[key] as Vector3) / float(counts[key])


func _step(creature: Creature, delta: float) -> void:
	var habit := creature.habit
	var position := _position_of(creature.node)
	var speed := habit.speed

	var threat := _nearest_threat(position, habit)
	if threat != Vector3.INF:
		# Убегает строго от угрозы и в этот момент не думает ни о доме, ни о
		# стае: животное, вежливо возвращающееся в домашний радиус под носом у
		# охотника, выглядит сломанным.
		creature.heading = _flat_normalized(position - threat)
		creature.pause_left = 0.0
		speed *= habit.flee_speed_scale
	else:
		if creature.pause_left > 0.0:
			creature.pause_left -= delta
			return
		if _rng.randf() < habit.pause_chance * delta:
			creature.pause_left = _rng.randf_range(habit.pause_seconds_min, habit.pause_seconds_max)
			return
		if _rng.randf() < habit.turn_chance * delta:
			creature.heading = _random_heading()
		creature.heading = _steer_home(creature)
		creature.heading = _steer_to_flock(creature)

	var next := position + creature.heading * speed * delta
	if is_blocked.is_valid() and bool(is_blocked.call(next)):
		# Развернуться, а не встать: существо, упёршееся в дерево и замершее
		# навсегда, читается как повисшее.
		creature.heading = -creature.heading
		return
	if terrain_height_at.is_valid():
		var height: float = float(terrain_height_at.call(next.x, next.z, next.y))
		if not is_nan(height):
			next.y = height + GROUND_SNAP
	_move_to(creature.node, next)
	if habit.face_travel:
		creature.node.rotation.y = atan2(creature.heading.x, creature.heading.z)


## Ближайшая угроза в радиусе испуга, или `Vector3.INF`, если бояться некого.
func _nearest_threat(position: Vector3, habit: WanderHabit) -> Vector3:
	if not habit.flees() or not threat_positions.is_valid():
		return Vector3.INF
	var best := Vector3.INF
	var best_distance := habit.flee_radius
	for threat: Vector3 in (threat_positions.call() as Array):
		var distance := Vector2(position.x - threat.x, position.z - threat.z).length()
		if distance < best_distance:
			best_distance = distance
			best = threat
	return best


## Мягкий поводок к месту рождения: за границей радиуса направление
## подмешивается к домашнему, а не переставляется в него — иначе животные на
## краю участка маршируют строем к центру.
func _steer_home(creature: Creature) -> Vector3:
	if creature.habit.home_radius <= 0.0:
		return creature.heading
	var offset := _position_of(creature.node) - creature.home
	offset.y = 0.0
	var distance := offset.length()
	if distance <= creature.habit.home_radius:
		return creature.heading
	var pull := clampf((distance - creature.habit.home_radius) / maxf(creature.habit.home_radius, 0.001), 0.0, 1.0)
	return _flat_normalized(creature.heading.lerp(-offset.normalized(), pull))


func _steer_to_flock(creature: Creature) -> Vector3:
	if creature.habit.cohesion <= 0.0 or not _flock_centres.has(creature.flock):
		return creature.heading
	var centre: Vector3 = _flock_centres[creature.flock]
	var offset := centre - _position_of(creature.node)
	offset.y = 0.0
	if offset.length() < 1.0:
		return creature.heading
	return _flat_normalized(creature.heading.lerp(offset.normalized(), creature.habit.cohesion * 0.5))


## Существо не обязано жить в дереве сцен, чтобы им можно было двигать. Требовать
## этого значило бы, что службу нельзя проверить без полной сцены, — а именно
## отсутствие такой проверки и позволило прошлой бродилке жить непокрытой.
static func _position_of(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position


static func _move_to(node: Node3D, position: Vector3) -> void:
	if node.is_inside_tree():
		node.global_position = position
	else:
		node.position = position


func _random_heading() -> Vector3:
	var angle := _rng.randf_range(0.0, TAU) if _rng != null else randf_range(0.0, TAU)
	return Vector3(cos(angle), 0.0, sin(angle))


static func _flat_normalized(vector: Vector3) -> Vector3:
	var flat := Vector3(vector.x, 0.0, vector.z)
	return flat.normalized() if flat.length_squared() > 0.000001 else Vector3.FORWARD
