class_name WanderHabit
extends RefCounted

## How a creature moves when nothing in particular is happening to it
## (design_docs/engine/map_fill_mode.md §5).
##
## A habit is data, not a class per animal. The rabbit's roaming used to be ten
## lines inside `AmbientSpawner`, and the honest reading of "add a deer and a
## wolf" was three more copies of those ten lines, drifting apart the first time
## anyone touched one. Here a new creature is an archetype component:
##
##   "components": { "wander": { "habit": "grazing", "speed": 0.5 } }
##
## What the habit does **not** decide is anything a gameplay system owns. A wolf
## that hunts, a deer that can be tracked, a bird that carries a message — those
## are components of their own. This is only "how it drifts about", and keeping it
## that small is what lets it stay pure data.

const HABIT_STILL := &"still"
const HABIT_GRAZING := &"grazing"
const HABIT_SKITTISH := &"skittish"
const HABIT_PROWLING := &"prowling"
const HABIT_FLOCKING := &"flocking"

const HABITS: Array[StringName] = [
	HABIT_STILL, HABIT_GRAZING, HABIT_SKITTISH, HABIT_PROWLING, HABIT_FLOCKING,
]

## Метры в секунду в спокойном шаге.
var speed := 0.7
## Вероятность в секунду сменить направление просто так.
var turn_chance := 0.7
## Вероятность в секунду остановиться и постоять (пощипать траву, оглядеться).
var pause_chance := 0.35
var pause_seconds_min := 0.8
var pause_seconds_max := 2.6
## Как далеко существо отходит от места, где появилось. Ноль — без привязки.
var home_radius := 6.0
## На каком расстоянии замечает угрозу и с каким множителем скорости убегает.
var flee_radius := 0.0
var flee_speed_scale := 1.0
## Насколько тянется к сородичам: 0 — сам по себе, 1 — держится стаи.
var cohesion := 0.0
## Разворачивать ли модель по направлению движения. Кролик — да, рой мошкары —
## нет: у него нет «переда».
var face_travel := true
var id: StringName = HABIT_GRAZING


## Пресеты — это не «настройки по умолчанию», а сами повадки: пугливое животное
## отличается от пасущегося именно этими числами, и менять их в архетипе нужно
## как исключение, а не как норму.
static func preset(habit: StringName) -> WanderHabit:
	var result := WanderHabit.new()
	result.id = habit if habit in HABITS else HABIT_GRAZING
	match result.id:
		HABIT_STILL:
			result.speed = 0.0
			result.turn_chance = 0.0
			result.pause_chance = 0.0
			result.home_radius = 0.0
			result.face_travel = false
		HABIT_GRAZING:
			# Пасётся: медленно, часто замирает, далеко не уходит.
			result.speed = 0.45
			result.turn_chance = 0.5
			result.pause_chance = 0.6
			result.pause_seconds_min = 1.4
			result.pause_seconds_max = 4.0
			result.home_radius = 7.0
			result.flee_radius = 5.0
			result.flee_speed_scale = 3.2
		HABIT_SKITTISH:
			# Перебежками: короткие рывки, длинные замирания, паникует рано.
			result.speed = 0.9
			result.turn_chance = 1.1
			result.pause_chance = 0.9
			result.pause_seconds_min = 0.5
			result.pause_seconds_max = 2.0
			result.home_radius = 5.0
			result.flee_radius = 6.5
			result.flee_speed_scale = 3.6
		HABIT_PROWLING:
			# Обходит участок: ровно, редко останавливается, никого не боится.
			result.speed = 1.1
			result.turn_chance = 0.25
			result.pause_chance = 0.1
			result.pause_seconds_min = 0.6
			result.pause_seconds_max = 1.6
			result.home_radius = 14.0
			result.flee_radius = 0.0
		HABIT_FLOCKING:
			# Держится своих: сам по себе почти не сворачивает, тянется к соседям.
			result.speed = 0.8
			result.turn_chance = 0.35
			result.pause_chance = 0.2
			result.home_radius = 9.0
			result.flee_radius = 7.0
			result.flee_speed_scale = 2.4
			result.cohesion = 0.7
	return result


## Компонент архетипа: повадка плюс только те числа, которые автор действительно
## решил переопределить. Неизвестная повадка — не ошибка (§11): пак, собранный
## более поздней сборкой, должен открыться и здесь.
static func from_component(data: Dictionary) -> WanderHabit:
	var habit := StringName(data.get("habit", HABIT_GRAZING))
	var result := preset(habit)
	result.speed = maxf(0.0, float(data.get("speed", result.speed)))
	result.turn_chance = maxf(0.0, float(data.get("turn_chance", result.turn_chance)))
	result.pause_chance = maxf(0.0, float(data.get("pause_chance", result.pause_chance)))
	result.pause_seconds_min = maxf(0.0, float(data.get("pause_min", result.pause_seconds_min)))
	result.pause_seconds_max = maxf(result.pause_seconds_min, float(data.get("pause_max", result.pause_seconds_max)))
	result.home_radius = maxf(0.0, float(data.get("radius", result.home_radius)))
	result.flee_radius = maxf(0.0, float(data.get("flee_radius", result.flee_radius)))
	result.flee_speed_scale = maxf(1.0, float(data.get("flee_speed", result.flee_speed_scale)))
	result.cohesion = clampf(float(data.get("cohesion", result.cohesion)), 0.0, 1.0)
	result.face_travel = bool(data.get("face_travel", result.face_travel))
	return result


func flees() -> bool:
	return flee_radius > 0.0 and flee_speed_scale > 1.0


func is_mobile() -> bool:
	return speed > 0.0
