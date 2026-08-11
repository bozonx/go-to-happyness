class_name TestDomainMapScatter
extends RefCounted

## Бинарный слой массового наполнения (`map_fill_mode.md` §8.2, §8.3).
##
## Проверяются три обещания, ради которых слой вообще заведён: он дёшев, его
## идентичность стабильна, и он не превращается в тыкву при повреждении файла.

const BOARD := 64


static func run_all() -> void:
	_test_records_round_trip_byte_for_byte()
	_test_deleting_does_not_move_the_neighbours()
	_test_compaction_is_explicit_and_bumps_the_revision()
	_test_a_damaged_or_foreign_file_is_refused()
	_test_declared_header_must_match_the_binary()
	_test_the_layer_is_cheaper_than_named_records()
	print("    [PASS] Map Scatter Layer Tests")


static func _record(index: int, cell: Vector2i, yaw := 0.0, scale := 1.0) -> MapScatterLayer.Record:
	var record := MapScatterLayer.Record.new()
	record.archetype_index = index
	record.cell = cell
	record.yaw_degrees = yaw
	record.scale = scale
	return record


static func _forest() -> MapScatterLayer:
	var layer := MapScatterLayer.new()
	var tree := layer.archetype_index_of(&"core:tree")
	var bush := layer.archetype_index_of(&"core:bush")
	# Отрицательные клетки обязательны: доска центрирована на начале координат.
	layer.add(_record(tree, Vector2i(-30, -30), 42.0, 1.4))
	layer.add(_record(bush, Vector2i(-1, 5), 305.0, 0.8))
	layer.add(_record(tree, Vector2i(12, -7), 180.0, 1.0))
	return layer


static func _test_records_round_trip_byte_for_byte() -> void:
	var layer := _forest()
	layer.records[0].offset = Vector2(0.25, -0.5)
	layer.records[0].state_index = 2
	layer.records[0].variant = 5
	var buffer := MapScatterCodec.encode(layer)
	assert(not buffer.is_empty())

	var restored := MapScatterLayer.new()
	restored.read_header(layer.to_header())
	assert(MapScatterCodec.decode_into(buffer, restored), "слой должен читаться")
	assert(restored.records.size() == layer.records.size())
	assert(restored.archetypes == layer.archetypes, "таблица архетипов едет в map.json")
	for index in layer.records.size():
		var before := layer.records[index]
		var after := restored.records[index]
		assert(after.archetype_index == before.archetype_index)
		assert(after.cell == before.cell, "клетка обязана пережить кодирование точно")
		assert(after.state_index == before.state_index and after.variant == before.variant)
		# Поворот, масштаб и смещение квантуются намеренно — проверяется, что
		# ошибка квантования меньше того, что различает глаз.
		assert(absf(after.yaw_degrees - before.yaw_degrees) <= 1.5,
			"поворот уехал на %f" % absf(after.yaw_degrees - before.yaw_degrees))
		assert(absf(after.scale - before.scale) <= 0.02)
		assert(after.offset.distance_to(before.offset) <= 0.01)

	# Пустой слой не пишет файла вовсе — как рельеф и вода.
	assert(MapScatterCodec.encode(MapScatterLayer.new()).is_empty())


## Идентичность записи — это пара «слой, индекс» (§8.3). Сейв ссылается на
## срубленное дерево по индексу, и сдвиг соседей после удаления означал бы, что
## после правки карты он показывает на другое дерево.
static func _test_deleting_does_not_move_the_neighbours() -> void:
	var layer := _forest()
	var last_cell := layer.records[2].cell
	assert(layer.remove_at(1), "удаление живой записи")
	assert(not layer.remove_at(1), "удалить дважды — не ошибка, но и не действие")
	assert(layer.records.size() == 3, "таблица не сжимается при удалении")
	assert(layer.live_count() == 2)
	assert(layer.records[2].cell == last_cell, "индекс соседа не должен поехать")
	assert(layer.records[1].is_empty())

	# Надгробие переживает запись на диск: иначе после сохранения индексы
	# разъехались бы ровно там, где им запрещено.
	var buffer := MapScatterCodec.encode(layer)
	var restored := MapScatterLayer.new()
	restored.read_header(layer.to_header())
	assert(MapScatterCodec.decode_into(buffer, restored))
	assert(restored.records[1].is_empty() and restored.live_count() == 2)


static func _test_compaction_is_explicit_and_bumps_the_revision() -> void:
	var layer := _forest()
	var revision_before := layer.revision
	assert(layer.remove_at(1))
	assert(layer.compact() == 1, "уплотнение выбрасывает ровно надгробия")
	assert(layer.records.size() == 2 and layer.live_count() == 2)
	assert(layer.revision == revision_before + 1,
		"сдвиг индексов обязан поднять ревизию, иначе старый сейв наложится молча")
	# Куст был единственной записью своего архетипа: после уплотнения таблица
	# архетипов тоже не хранит того, на что никто не ссылается.
	assert(layer.archetypes.size() == 1 and layer.archetypes[0] == &"core:tree",
		"таблица архетипов уплотняется вместе с записями: %s" % [layer.archetypes])
	for record: MapScatterLayer.Record in layer.records:
		assert(layer.archetype_of(record) == &"core:tree")

	# Уплотнять нечего — значит ревизия не двигается: она означает «индексы
	# поехали», а не «кто-то вызвал compact».
	assert(layer.compact() == 0 and layer.revision == revision_before + 1)


static func _test_a_damaged_or_foreign_file_is_refused() -> void:
	var layer := _forest()
	var buffer := MapScatterCodec.encode(layer)

	var truncated := buffer.slice(0, buffer.size() - 3)
	var target := MapScatterLayer.new()
	target.read_header(layer.to_header())
	assert(not MapScatterCodec.decode_into(truncated, target), "обрезанный файл — отказ")

	var foreign := PackedByteArray()
	foreign.resize(buffer.size())
	for index in buffer.size():
		foreign[index] = buffer[index]
	foreign[0] = "X".unicode_at(0)
	assert(not MapScatterCodec.decode_into(foreign, target), "чужая магия — отказ")

	# Запись, ссылающаяся на архетип вне таблицы, отвергает файл целиком:
	# половина леса хуже, чем его отсутствие, потому что «половина» не видна.
	var short_table := MapScatterLayer.new()
	short_table.archetype_index_of(&"core:tree")
	assert(not MapScatterCodec.decode_into(buffer, short_table))


static func _test_declared_header_must_match_the_binary() -> void:
	var layer := _forest()
	var buffer := MapScatterCodec.encode(layer)
	var wrong_count := MapScatterLayer.new()
	var header := layer.to_header()
	header["count"] = layer.records.size() + 1
	wrong_count.read_header(header)
	assert(not MapScatterCodec.decode_into(buffer, wrong_count, true),
		"map.json и objects.bin с разным count нельзя склеивать")
	var wrong_revision := MapScatterLayer.new()
	header = layer.to_header()
	header["revision"] = layer.revision + 1
	wrong_revision.read_header(header)
	assert(not MapScatterCodec.decode_into(buffer, wrong_revision, true),
		"бинарник другой ревизии нельзя принять как текущий слой")


## Ради этого слой и существует: тридцать тысяч деревьев в JSON — мегабайты и
## секунды разбора при каждом открытии карты.
static func _test_the_layer_is_cheaper_than_named_records() -> void:
	var layer := MapScatterLayer.new()
	var tree := layer.archetype_index_of(&"core:tree")
	var count := 30000
	for index in count:
		layer.add(_record(tree, Vector2i(index % BOARD - BOARD / 2, index / BOARD - BOARD / 2)))
	var buffer := MapScatterCodec.encode(layer)
	assert(buffer.size() == MapScatterCodec.HEADER_BYTES + count * MapScatterCodec.BYTES_PER_RECORD)
	assert(buffer.size() < 512 * 1024, "полмегабайта на тридцать тысяч деревьев: %d" % buffer.size())

	# То же в JSON — для сравнения, которое и было причиной завести файл.
	var record := MapEntityRecord.new()
	record.id = &"tree_00000"
	record.archetype_id = &"core:tree"
	record.position = Vector3(10.5, 0.0, -12.5)
	var json_bytes := JSON.stringify(record.to_dict()).length() * count
	assert(json_bytes > buffer.size() * 4,
		"если JSON не дороже вчетверо, бинарный слой не нужен: %d против %d" % [json_bytes, buffer.size()])
