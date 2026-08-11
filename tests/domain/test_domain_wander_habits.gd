class_name TestDomainWanderHabits
extends RefCounted

## Повадки и служба, которая их исполняет (`map_fill_mode.md` §5).
##
## Проверяется не «красиво ли ходит зверь», а три обещания, на которых держится
## решение сделать бродилку данными: повадка — это данные, разные повадки дают
## разное поведение, и существо не убегает с карты и не застревает навсегда.


static func run_all() -> void:
	_test_presets_actually_differ()
	_test_component_overrides_only_what_it_names()
	_test_unknown_habit_still_loads()
	_test_creature_wanders_and_stays_near_home()
	_test_blocked_creature_turns_instead_of_freezing()
	_test_skittish_creature_runs_from_a_threat()
	_test_still_creature_is_never_registered()
	_test_service_forgets_freed_creatures()
	_test_creature_does_not_walk_up_a_cliff()
	print("    [PASS] Wander Habit Tests")


static func _test_presets_actually_differ() -> void:
	var grazing := WanderHabit.preset(WanderHabit.HABIT_GRAZING)
	var skittish := WanderHabit.preset(WanderHabit.HABIT_SKITTISH)
	var prowling := WanderHabit.preset(WanderHabit.HABIT_PROWLING)
	# Если пресеты совпадут, «разные бродилки» станут словом без содержания.
	assert(skittish.speed > grazing.speed, "пугливое быстрее пасущегося")
	assert(prowling.home_radius > grazing.home_radius, "хищник обходит больший участок")
	assert(prowling.flee_radius <= 0.0 and not prowling.flees(), "хищник никого не боится")
	assert(grazing.flees() and skittish.flees())
	assert(skittish.flee_radius > grazing.flee_radius, "пугливое замечает угрозу раньше")
	assert(WanderHabit.preset(WanderHabit.HABIT_FLOCKING).cohesion > 0.0)


static func _test_component_overrides_only_what_it_names() -> void:
	var preset := WanderHabit.preset(WanderHabit.HABIT_GRAZING)
	var habit := WanderHabit.from_component({"habit": "grazing", "speed": 2.5})
	assert(is_equal_approx(habit.speed, 2.5), "автор вправе переопределить скорость")
	assert(is_equal_approx(habit.home_radius, preset.home_radius),
		"неупомянутое поле обязано остаться пресетным")
	assert(habit.id == WanderHabit.HABIT_GRAZING)

	# Верхняя пауза не может оказаться меньше нижней, как бы её ни задали.
	var clamped := WanderHabit.from_component({"pause_min": 5.0, "pause_max": 1.0})
	assert(clamped.pause_seconds_max >= clamped.pause_seconds_min)


static func _test_unknown_habit_still_loads() -> void:
	# Пак более поздней сборки обязан открыться здесь (§11).
	var habit := WanderHabit.from_component({"habit": "teleporting"})
	assert(habit.id == WanderHabit.HABIT_GRAZING, "незнакомая повадка откатывается к пресету")
	assert(habit.is_mobile())


static func _test_creature_wanders_and_stays_near_home() -> void:
	var service := _service()
	var node := Node3D.new()
	var habit := WanderHabit.preset(WanderHabit.HABIT_PROWLING)
	service.register(node, habit)
	var start := node.position

	var moved := false
	for step in 600:
		service.tick(0.1)
		if node.position.distance_to(start) > 0.05:
			moved = true
	assert(moved, "существо обязано вообще двигаться")
	# Домашний радиус — не забор, а поводок, поэтому допуск щедрый; важно, что
	# зверь не уходит за горизонт.
	assert(node.position.distance_to(start) < habit.home_radius * 2.5,
		"существо ушло от дома на %f" % node.position.distance_to(start))
	assert(is_equal_approx(node.position.y, start.y), "без террейна высота не меняется")
	node.free()


static func _test_blocked_creature_turns_instead_of_freezing() -> void:
	var service := AmbientLifeService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Стена по x > 1: за неё нельзя, и упереться в неё существо обязано не насмерть.
	service.configure(rng, func(_from: Vector3, to: Vector3) -> bool: return to.x <= 1.0)
	var node := Node3D.new()
	service.register(node, WanderHabit.preset(WanderHabit.HABIT_PROWLING))
	for step in 400:
		service.tick(0.1)
		assert(node.position.x <= 1.0, "существо прошло сквозь запрет")
	# Оно не должно было замереть в углу навсегда.
	assert(absf(node.position.z) > 0.05 or absf(node.position.x) > 0.05,
		"упёршееся существо перестало двигаться совсем")
	node.free()


static func _test_skittish_creature_runs_from_a_threat() -> void:
	var threat := Vector3(0.0, 0.0, 0.0)
	var service := AmbientLifeService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	service.configure(
		rng,
		func(_from: Vector3, _to: Vector3) -> bool: return true,
		Callable(),
		func() -> Array[Vector3]: return [threat] as Array[Vector3]
	)
	var node := Node3D.new()
	node.position = Vector3(1.0, 0.0, 0.0)
	var habit := WanderHabit.preset(WanderHabit.HABIT_SKITTISH)
	service.register(node, habit)

	var before := node.position.distance_to(threat)
	for step in 20:
		service.tick(0.1)
	var after := node.position.distance_to(threat)
	assert(after > before, "пугливый зверь обязан убегать от человека, было %f стало %f" % [before, after])
	# Убегает быстрее, чем гуляет: иначе испуг ничего не значит.
	assert((after - before) > habit.speed * 2.0 * 0.9,
		"побег должен быть быстрее обычного шага")
	node.free()


static func _test_still_creature_is_never_registered() -> void:
	var service := _service()
	var node := Node3D.new()
	service.register(node, WanderHabit.preset(WanderHabit.HABIT_STILL))
	assert(service.count() == 0, "неподвижное существо незачем тикать каждый кадр")
	service.register(node, null)
	assert(service.count() == 0, "существо без повадки не бродит")
	node.free()


## Пойманный кролик освобождает ноду. Служба обязана заметить это сама, иначе
## охоте пришлось бы помнить про ещё один список — ровно та связность, ради
## устранения которой служба и заводилась.
static func _test_service_forgets_freed_creatures() -> void:
	var service := _service()
	var node := Node3D.new()
	service.register(node, WanderHabit.preset(WanderHabit.HABIT_GRAZING))
	assert(service.count() == 1)
	node.free()
	service.tick(0.1)
	assert(service.count() == 0, "освобождённое существо должно уйти с учёта")


## Обрыв — это свойство перехода между клетками, и увидеть его можно только
## спросив о шаге. Пока служба спрашивала «занята ли точка», зверь поднимался по
## отвесной стене: высоту ему исправно выставлял террейн, а препятствием стена не
## считалась, потому что на ней ничего не стояло.
static func _test_creature_does_not_walk_up_a_cliff() -> void:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, 32)
	# Стена в четыре ступени по x >= 2 — выше всего, что берёт пешеход.
	for z in range(-16, 16):
		for x in range(2, 16):
			assert(terrain.set_height(Vector2i(x, z), 4))
	var nav := NavGrid.new()
	nav.configure(terrain.cell_size, 32)
	TerrainNavigationPublisher.publish(terrain, nav)
	assert(not nav.is_step_passable(Vector2i(1, 0), Vector2i(2, 0)),
		"фикстура обязана быть непроходимой, иначе тест ничего не проверяет")

	var service := AmbientLifeService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	service.configure(
		rng,
		func(from: Vector3, to: Vector3) -> bool:
			var from_cell := nav.cell_from_position(from)
			var to_cell := nav.cell_from_position(to)
			return from_cell == to_cell or nav.is_step_passable(from_cell, to_cell),
		func(x: float, z: float, _y: float) -> float:
			return terrain.height_at(Vector3(x, 0.0, z))
	)
	var node := Node3D.new()
	node.position = Vector3(0.5, 0.0, 0.5)
	# Хищник обходит самый большой участок — если стену вообще можно перейти, он
	# дойдёт до неё раньше всех.
	service.register(node, WanderHabit.preset(WanderHabit.HABIT_PROWLING))
	for step in 600:
		service.tick(0.1)
		assert(node.position.x < 2.0,
			"существо забралось на стену: x = %f, y = %f" % [node.position.x, node.position.y])
	node.free()


static func _service() -> AmbientLifeService:
	var service := AmbientLifeService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	service.configure(rng, func(_from: Vector3, _to: Vector3) -> bool: return true)
	return service
