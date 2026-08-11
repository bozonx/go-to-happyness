class_name BiomeFillCatalog
extends RefCounted

## «Что растёт в каком биоме» — таблица паков, а не код движка
## (`procedural_map_generation.md` §11.4, слой 4).
##
## Связи биома с растительностью раньше не существовало нигде: `BiomeCatalog`
## знает только палитру грунта, а генератор заканчивался поверхностью. Это и есть
## основное содержание задачи «расставить ассеты по биомам» — таблица, а не код.
##
## Поэтому она и не в `BiomeCatalog`. Биом — вычисляемая классификация колонки
## (климат плюс форма земли), она принадлежит движку; список растений —
## содержимое мира, оно принадлежит паку. Сложив их в один файл, мы получили бы
## третий вшитый реестр рядом с `WorldAssetCatalog`, и пак не смог бы засадить
## свою тайгу своими деревьями, не трогая GDScript.
##
## Раскладка файлов повторяет архетипы: `<pack>/biomes/<biome>.gdbiomefill.json`.
## Несколько паков вправе дополнять один биом — правила складываются, а не
## затирают друг друга: пак с бабочками добавляет бабочек в луг, а не заменяет
## собой луг.

const PACK_ROOTS: Array[String] = [
	"res://game/content", "user://content/projects", "user://content/installed",
]
const BIOME_DIR := "biomes"
const FILE_SUFFIX := ".gdbiomefill.json"

static var _rules: Dictionary = {}
static var _loaded := false
## Как и у архетипов: сломанный пак виден в редакторе, а не роняет половину
## таблицы молча.
static var load_errors: Array[String] = []


static func reload() -> void:
	_rules.clear()
	load_errors.clear()
	_loaded = false
	_ensure_loaded()


## Правила биома в порядке объявления. Пустой массив — нормальный ответ: полярная
## пустыня пуста не по ошибке.
static func rules_for(biome_id: StringName) -> Array[BiomeFillRule]:
	_ensure_loaded()
	var found: Array[BiomeFillRule] = []
	for rule: BiomeFillRule in _rules.get(biome_id, [] as Array[BiomeFillRule]):
		found.append(rule)
	return found


static func biomes() -> Array[StringName]:
	_ensure_loaded()
	var ids: Array[StringName] = []
	for key: StringName in _rules:
		ids.append(key)
	ids.sort()
	return ids


## Архетипы, на которые ссылается вся таблица. `MapDocumentService` собирает из
## этого `required_content` сгенерированной карты — иначе карта уехала бы к
## другому игроку без пака, который её населил.
static func referenced_archetypes() -> Array[StringName]:
	_ensure_loaded()
	var found: Array[StringName] = []
	for biome_id: StringName in _rules:
		for rule: BiomeFillRule in _rules[biome_id]:
			if rule.archetype_id not in found:
				found.append(rule.archetype_id)
	found.sort()
	return found


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for root: String in PACK_ROOTS:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for pack_dir: String in DirAccess.get_directories_at(root):
			_load_pack(root.path_join(pack_dir))


static func _load_pack(pack_root: String) -> void:
	var root := pack_root.path_join(BIOME_DIR)
	if not DirAccess.dir_exists_absolute(root):
		return
	var file_names := DirAccess.get_files_at(root)
	# Отсортировано, чтобы порядок правил не зависел от файловой системы: разброс
	# детерминирован по seed, и он обязан быть детерминирован и по порядку.
	file_names.sort()
	for file_name: String in file_names:
		if not file_name.ends_with(FILE_SUFFIX):
			continue
		_load_file(root.path_join(file_name))


static func _load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		load_errors.append("Некорректная таблица биома: %s" % path)
		return
	var source := parsed as Dictionary
	var biome_id := StringName(source.get("biome", path.get_file().replace(FILE_SUFFIX, "")))
	if BiomeCatalog.index_of(biome_id) < 0:
		load_errors.append("Неизвестный биом «%s»: %s" % [biome_id, path])
		return
	var raw_rules: Variant = source.get("rules", null)
	if not (raw_rules is Array):
		load_errors.append("В таблице биома нет списка «rules»: %s" % path)
		return
	var bucket: Array[BiomeFillRule] = _rules.get(biome_id, [] as Array[BiomeFillRule])
	for raw: Variant in raw_rules as Array:
		if not (raw is Dictionary):
			continue
		var rule := BiomeFillRule.from_dict(raw as Dictionary)
		if not rule.is_valid():
			load_errors.append("Правило без архетипа или с нулевой плотностью: %s" % path)
			continue
		bucket.append(rule)
	_rules[biome_id] = bucket
