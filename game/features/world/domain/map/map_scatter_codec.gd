class_name MapScatterCodec
extends RefCounted

## `objects.bin`: массовое наполнение как записи фиксированной длины
## (`map_fill_mode.md` §8.2).
##
## Шестнадцать байт на объект против полутора сотен в JSON. Формат заголовка тот
## же, что у `terrain.bin` и `water.bin`, — магия, версия, ширина записи, — чтобы
## повреждённый файл отказывался читаться одинаково во всех трёх слоях.
##
## В отличие от них слой адресуется НЕ клетками: два дерева стоят в одной клетке
## со своими смещениями, а девять десятых доски пусты. Поэтому здесь таблица
## записей, а не поле, и порядок записей — это их идентичность (§8.3): удаление
## оставляет надгробие, а не сдвигает соседей.
##
## Таблица архетипов в файл не пишется. Её место — заголовок в `map.json`
## (`scatter_layers[]`), где она читаема глазами и попадает в `required_content`;
## файл несёт только индексы.

const MAGIC := "GTHO"
const VERSION := 1
const HEADER_BYTES := 16
const BYTES_PER_RECORD := 16

## Клетки центрированы на начале координат, поэтому координата знаковая. i16
## покрывает доску до 65 536 клеток — на четыре порядка больше любой карты.
const MIN_CELL := -32768
const MAX_CELL := 32767


static func encode(layer: MapScatterLayer) -> PackedByteArray:
	var buffer := PackedByteArray()
	if layer == null or layer.is_empty():
		return buffer
	buffer.resize(HEADER_BYTES + layer.records.size() * BYTES_PER_RECORD)
	_write_header(buffer, layer.records.size(), layer.revision)

	var offset := HEADER_BYTES
	for record: MapScatterLayer.Record in layer.records:
		# Вне диапазона — отказ, а не обрезка. Обрезанная координата поставила бы
		# дерево в другое место, и ни один читатель об этом не узнал бы.
		if record.cell.x < MIN_CELL or record.cell.x > MAX_CELL \
				or record.cell.y < MIN_CELL or record.cell.y > MAX_CELL:
			push_error("[map] клетка %s вне диапазона слоя наполнения" % record.cell)
			return PackedByteArray()
		if record.archetype_index < 0 or record.archetype_index > 0xFFFF:
			push_error("[map] индекс архетипа %d вне диапазона" % record.archetype_index)
			return PackedByteArray()
		buffer.encode_u16(offset, record.archetype_index)
		buffer.encode_s16(offset + 2, record.cell.x)
		buffer.encode_s16(offset + 4, record.cell.y)
		buffer[offset + 6] = _encode_offset(record.offset.x)
		buffer[offset + 7] = _encode_offset(record.offset.y)
		buffer[offset + 8] = _encode_yaw(record.yaw_degrees)
		buffer[offset + 9] = _encode_scale(record.scale)
		buffer[offset + 10] = clampi(record.state_index, 0, 255)
		buffer[offset + 11] = clampi(record.variant, 0, 255)
		buffer[offset + 12] = clampi(record.flags, 0, 255)
		buffer[offset + 13] = 0
		buffer.encode_u16(offset + 14, 0) # reserved
		offset += BYTES_PER_RECORD
	return buffer


## Наполняет слой. Таблица архетипов обязана быть прочитана ДО этого вызова, из
## заголовка `map.json`: запись без архетипа — это запись, которую нечем
## нарисовать, и молча превращать её в первый попавшийся архетип нельзя.
static func decode_into(buffer: PackedByteArray, layer: MapScatterLayer) -> bool:
	if layer == null or not is_valid(buffer):
		return false
	var count := record_count_of(buffer)
	var records: Array[MapScatterLayer.Record] = []
	var offset := HEADER_BYTES
	for _index in count:
		var record := MapScatterLayer.Record.new()
		record.archetype_index = buffer.decode_u16(offset)
		if record.archetype_index >= layer.archetypes.size():
			return false
		record.cell = Vector2i(buffer.decode_s16(offset + 2), buffer.decode_s16(offset + 4))
		record.offset = Vector2(_decode_offset(buffer[offset + 6]), _decode_offset(buffer[offset + 7]))
		record.yaw_degrees = _decode_yaw(buffer[offset + 8])
		record.scale = _decode_scale(buffer[offset + 9])
		record.state_index = buffer[offset + 10]
		record.variant = buffer[offset + 11]
		record.flags = buffer[offset + 12]
		records.append(record)
		offset += BYTES_PER_RECORD
	layer.records = records
	layer.revision = revision_of(buffer)
	return true


static func is_valid(buffer: PackedByteArray) -> bool:
	if buffer.size() < HEADER_BYTES:
		return false
	for index in MAGIC.length():
		if buffer[index] != MAGIC.unicode_at(index):
			return false
	if buffer.decode_u16(4) != VERSION:
		return false
	if buffer.decode_u16(6) != BYTES_PER_RECORD:
		return false
	return buffer.size() == HEADER_BYTES + record_count_of(buffer) * BYTES_PER_RECORD


static func record_count_of(buffer: PackedByteArray) -> int:
	if buffer.size() < HEADER_BYTES:
		return 0
	return buffer.decode_u32(8)


static func revision_of(buffer: PackedByteArray) -> int:
	if buffer.size() < HEADER_BYTES:
		return 0
	return buffer.decode_u32(12)


static func _write_header(buffer: PackedByteArray, count: int, revision: int) -> void:
	for index in MAGIC.length():
		buffer[index] = MAGIC.unicode_at(index)
	buffer.encode_u16(4, VERSION)
	buffer.encode_u16(6, BYTES_PER_RECORD)
	buffer.encode_u32(8, count)
	buffer.encode_u32(12, revision)


## Смещение — байт со знаком в долях клетки. Шаг выходит около 1/256 клетки, то
## есть меньше сантиметра при двухметровой клетке: тоньше, чем шаг авторской
## подстройки (§9.1.1), и потому незаметно.
static func _encode_offset(value: float) -> int:
	var normalised := clampf(value / MapScatterLayer.OFFSET_RANGE, -1.0, 1.0)
	return int(roundf(normalised * 127.0)) & 0xFF


static func _decode_offset(raw: int) -> float:
	var signed := raw if raw < 128 else raw - 256
	return float(signed) / 127.0 * MapScatterLayer.OFFSET_RANGE


## Поворот байтом: шаг 1.4°. Для безымянного дерева это точнее, чем различает
## глаз; именованному объекту, которому нужен ровный угол, место в `entities[]`.
static func _encode_yaw(degrees: float) -> int:
	return int(roundf(fposmod(degrees, 360.0) / 360.0 * 256.0)) % 256


static func _decode_yaw(raw: int) -> float:
	return float(raw) / 256.0 * 360.0


static func _encode_scale(value: float) -> int:
	var span := MapScatterLayer.SCALE_MAX - MapScatterLayer.SCALE_MIN
	var normalised := clampf((value - MapScatterLayer.SCALE_MIN) / span, 0.0, 1.0)
	return int(roundf(normalised * 255.0))


static func _decode_scale(raw: int) -> float:
	var span := MapScatterLayer.SCALE_MAX - MapScatterLayer.SCALE_MIN
	return MapScatterLayer.SCALE_MIN + float(raw) / 255.0 * span
