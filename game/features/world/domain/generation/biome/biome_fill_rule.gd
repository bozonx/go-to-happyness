class_name BiomeFillRule
extends RefCounted

## Одна строка таблицы «что растёт в этом биоме»
## (`procedural_map_generation.md` §11.4, слой 4).
##
## Правило говорит ровно две вещи: ЧТО ставить и СКОЛЬКО. Где именно объект
## может стоять — уклон, поверхность, вода — здесь не повторяется ни одним
## полем: на это отвечает `placement` архетипа через `EntityPlacementProbe`.
## Спецификация требует этого дословно — «настоящая `placement`-политика
## архетипа, без облегчённой копии правил», — и причина простая: копия начнёт
## расходиться с оригиналом, и лес генератора перестанет совпадать с лесом,
## который автор ставит той же кистью.
##
## Климатическое окно — исключение, и оно не про «где можно», а про «где
## уместно». Биом — крупная категория: в умеренном лесу есть и сухой склон, и
## сырая низина, и папоротник принадлежит второй, хотя политика размещения
## разрешает ему обе.

## Сколько объектов приходится на клетку доски в среднем. Не вероятность и не
## штука: разброс расставляет кандидатов по площади, а не по клеткам, поэтому
## значение больше единицы осмысленно (трава гуще одной на клетку).
var density := 0.0
var archetype_id: StringName = &""
## Минимальный интервал между объектами ОДНОГО правила, в метрах. Ноль — взять
## у ассета (`placement.scatter.min_spacing_m`).
var min_spacing_m := 0.0
## Окно климата, в котором правило вообще применяется. По умолчанию — весь
## диапазон, то есть «везде в этом биоме».
var temperature_range := Vector2(-100.0, 100.0)
var moisture_range := Vector2(0.0, 1.0)
## Ставить только у воды: расстояние до мокрой клетки в клетках. Ноль — правилу
## всё равно. Камыш без этого растёт посреди луга, потому что политика
## размещения разрешает ему сушу.
var near_water_cells := 0


func accepts_climate(temperature: float, moisture: float) -> bool:
	return (
		temperature >= temperature_range.x and temperature <= temperature_range.y
		and moisture >= moisture_range.x and moisture <= moisture_range.y
	)


func to_dict() -> Dictionary:
	var result: Dictionary = {"archetype": String(archetype_id), "density": density}
	if min_spacing_m > 0.0:
		result["min_spacing_m"] = min_spacing_m
	if temperature_range != Vector2(-100.0, 100.0):
		result["temperature"] = [temperature_range.x, temperature_range.y]
	if moisture_range != Vector2(0.0, 1.0):
		result["moisture"] = [moisture_range.x, moisture_range.y]
	if near_water_cells > 0:
		result["near_water_cells"] = near_water_cells
	return result


## Неизвестные поля игнорируются, а не роняют пак: таблица, написанная более
## поздней сборкой, обязана открыться и здесь (`map_fill_mode.md` §11).
static func from_dict(source: Dictionary) -> BiomeFillRule:
	var rule := BiomeFillRule.new()
	rule.archetype_id = StringName(source.get("archetype", ""))
	rule.density = maxf(0.0, float(source.get("density", 0.0)))
	rule.min_spacing_m = maxf(0.0, float(source.get("min_spacing_m", 0.0)))
	rule.temperature_range = _range_of(source.get("temperature", null), rule.temperature_range)
	rule.moisture_range = _range_of(source.get("moisture", null), rule.moisture_range)
	rule.near_water_cells = maxi(0, int(source.get("near_water_cells", 0)))
	return rule


static func _range_of(raw: Variant, fallback: Vector2) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		var low := float((raw as Array)[0])
		var high := float((raw as Array)[1])
		return Vector2(minf(low, high), maxf(low, high))
	return fallback


func is_valid() -> bool:
	return archetype_id != &"" and density > 0.0
