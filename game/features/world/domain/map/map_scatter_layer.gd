class_name MapScatterLayer
extends RefCounted

## Безымянное массовое наполнение карты: лес, трава, осыпь
## (`map_fill_mode.md` §8.2, §8.3).
##
## Лес на доске 256² — это десятки тысяч объектов. В `entities[]` запись стоит
## под 150 байт JSON: тридцать тысяч деревьев — четыре с половиной мегабайта
## текста и секунды парсинга при каждом открытии карты. Рельеф по этой же причине
## давно лежит в `terrain.bin`, вода — в `water.bin`. Здесь — `objects.bin`,
## шестнадцать байт на объект.
##
## **Правило разделения одно и оно проверяемое:** как только объекту нужны имя,
## авторское свойство или ссылка, он переезжает в `entities[]`. Редактор делает
## этот атомарный перенос командой promotion (`P`) для выбранной записи.
##
## **Удаление не сжимает таблицу.** Идентичность записи — это пара «слой, индекс»
## (§8.3), и она стабильна ровно до тех пор, пока индексы не поехали. Убранный
## объект помечается пустым, а уплотнение — отдельная явная операция, которая
## поднимает ревизию слоя. Сейв, ссылающийся на срубленное дерево по индексу,
## иначе после любой правки карты указывал бы на соседнее.

## Флаги записи. Бит «пусто» — тот самый надгробный камень из §8.3.
const FLAG_EMPTY := 1 << 0

## Границы масштаба, которые кодируется одним байтом. Шире, чем позволяет любая
## политика ассета (`allowed_scales`), — байт здесь не ограничивает автора.
const SCALE_MIN := 0.25
const SCALE_MAX := 4.0

## Смещение внутри клетки кодируется байтом со знаком в долях клетки. Полклетки
## в каждую сторону — ровно тот предел, который §9.3.1 назначает `offset`.
const OFFSET_RANGE := 0.5


class Record:
	extends RefCounted
	## Индекс архетипа в таблице слоя, а не его имя: имя стоит байт за буквой.
	var archetype_index := 0
	var cell := Vector2i.ZERO
	## Доли клетки в пределах ±`OFFSET_RANGE`.
	var offset := Vector2.ZERO
	var yaw_degrees := 0.0
	var scale := 1.0
	var state_index := 0
	var variant := 0
	var flags := 0

	func is_empty() -> bool:
		return (flags & FLAG_EMPTY) != 0


## Архетипы, на которые ссылаются записи. Порядок значим: он и есть кодировка.
var archetypes: Array[StringName] = []
var records: Array[Record] = []
## Поднимается уплотнением. Сейв сверяет её и отказывается накладывать свою
## дельту на слой, у которого индексы разъехались.
var revision := 0
## Values declared by map.json while loading. They are kept until objects.bin is
## decoded so a stale binary from another revision cannot be accepted silently.
var expected_count := -1
var expected_revision := -1


func is_empty() -> bool:
	return records.is_empty()


## Живых записей, без надгробий. Именно это число видит автор.
func live_count() -> int:
	var total := 0
	for record: Record in records:
		if not record.is_empty():
			total += 1
	return total


## Индекс архетипа в таблице слоя, добавляя его при необходимости.
func archetype_index_of(archetype_id: StringName) -> int:
	var found := archetypes.find(archetype_id)
	if found >= 0:
		return found
	archetypes.append(archetype_id)
	return archetypes.size() - 1


func archetype_of(record: Record) -> StringName:
	if record.archetype_index < 0 or record.archetype_index >= archetypes.size():
		return &""
	return archetypes[record.archetype_index]


func add(record: Record) -> int:
	records.append(record)
	return records.size() - 1


## Помечает запись пустой. Возвращает `false`, если её уже нет: удаление дважды
## — не ошибка вызывающего, а обычное следствие того, что кисть ходит по одному
## месту несколько раз.
func remove_at(index: int) -> bool:
	if index < 0 or index >= records.size() or records[index].is_empty():
		return false
	records[index].flags |= FLAG_EMPTY
	return true


## Выбрасывает надгробия и поднимает ревизию. Это и есть «упаковать карту» из
## §8.3 — явная операция автора, а не побочный эффект удаления.
func compact() -> int:
	var removed := 0
	var kept: Array[Record] = []
	for record: Record in records:
		if record.is_empty():
			removed += 1
		else:
			kept.append(record)
	if removed == 0:
		return 0
	records = kept
	revision += 1
	_drop_unused_archetypes()
	return removed


## Записи, попадающие в прямоугольник клеток. Линейный проход намеренно: слой
## перебирается целиком при постройке чанков и при валидации, а держать второй
## индекс «клетка → запись» значило бы держать второго владельца расположения.
func records_in(area: Rect2i) -> Array[int]:
	var found: Array[int] = []
	for index in records.size():
		var record := records[index]
		if not record.is_empty() and area.has_point(record.cell):
			found.append(index)
	return found


func first_at(cell: Vector2i) -> int:
	for index in records.size():
		var record := records[index]
		if not record.is_empty() and record.cell == cell:
			return index
	return -1


func clear() -> void:
	archetypes.clear()
	records.clear()
	revision = 0
	expected_count = -1
	expected_revision = -1


## Заголовок для `map.json` (§8.1): таблица архетипов, число записей и ревизия.
## Сами записи живут в `objects.bin` — тем же способом, что рельеф и вода.
func to_header() -> Dictionary:
	if is_empty():
		return {}
	var names: Array = []
	for archetype_id: StringName in archetypes:
		names.append(String(archetype_id))
	return {"archetypes": names, "count": records.size(), "revision": revision}


func read_header(source: Dictionary) -> void:
	archetypes.clear()
	var raw: Variant = source.get("archetypes", null)
	if raw is Array:
		for entry: Variant in raw as Array:
			archetypes.append(StringName(entry))
	revision = int(source.get("revision", 0))
	expected_count = int(source.get("count", 0))
	expected_revision = revision


## Архетипы, на которые слой действительно ссылается. Идёт в `required_content`
## карты: карта, уехавшая без пака, который её засадил, обязана сказать об этом
## сама, а не показать поле розовых заглушек.
func referenced_archetypes() -> Array[StringName]:
	var used: Array[StringName] = []
	for record: Record in records:
		if record.is_empty():
			continue
		var archetype_id := archetype_of(record)
		if archetype_id != &"" and archetype_id not in used:
			used.append(archetype_id)
	return used


## Уплотнение таблицы архетипов после уплотнения записей. Делается только здесь:
## переиндексация вне `compact` сдвинула бы индексы у живых записей, то есть
## сломала бы ровно ту идентичность, ради которой удаление не сжимает таблицу.
func _drop_unused_archetypes() -> void:
	var used: Array[StringName] = referenced_archetypes()
	if used.size() == archetypes.size():
		return
	var remap: Dictionary = {}
	var next: Array[StringName] = []
	for archetype_id: StringName in archetypes:
		if archetype_id in used:
			remap[archetypes.find(archetype_id)] = next.size()
			next.append(archetype_id)
	for record: Record in records:
		record.archetype_index = int(remap.get(record.archetype_index, 0))
	archetypes = next
