class_name MapDocumentService
extends RefCounted

## Reads and writes `.gdmap` packages (design_docs/engine/map_editor.md §4).
##
## A map is a folder, not a file: the terrain layer is 320 KB of binary at
## 256×256 and would become megabytes as text. The folder holds `map.json`, the
## binary layers and a preview image.
##
## Maps are addressed through their manifest-backed content source.
##
## Saving is atomic: the package is written to a sibling temporary folder and only
## then swapped in. A crash mid-save leaves the previous map intact rather than a
## folder with a new `map.json` and last week's terrain.

const ContentRevisionScript = preload("res://game/features/content/domain/content_revision.gd")
const ContentIndexScript = preload("res://game/features/content/application/content_index.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")

const SOURCE_BUILTIN := &"core"
const BUILTIN_ROOT := "res://game/content/core/maps"

const PACKAGE_SUFFIX := ".gdmap"
const MAP_JSON := "map.json"
const TERRAIN_BIN := "terrain.bin"
const WATER_BIN := "water.bin"
const SURFACE_BIN := "surface.bin"
const PREVIEW_PNG := "preview.png"
## Безымянное массовое наполнение (`map_fill_mode.md` §8.2). Как и остальные
## бинарные слои, файла нет вовсе, если слой пуст.
const OBJECTS_BIN := "objects.bin"
## Every file a package may contain, so a save that omits an untouched layer still
## knows not to treat the rest as strays when cleaning up.
const KNOWN_FILES: Array[String] = [
	MAP_JSON, TERRAIN_BIN, WATER_BIN, SURFACE_BIN, OBJECTS_BIN, PREVIEW_PNG,
]

var last_error := ""
## Populated by every listing: duplicate ids and unreadable packages, so the editor
## can show them instead of letting one of two files quietly disappear.
var last_errors: Array[String] = []
## Dev mode authors the shipped pack, exactly as the building editor does
## (content_packaging.md §9). Without it the built-in maps are reachable only from
## `tools/make_builtin_maps.gd`, which means the game's own terrain, water and
## surface are unavailable to the editor that exists to author them.
var dev_mode := false
var project_root := ""
var project_source: StringName = &""
var _content_index: ContentIndex


func _init(p_dev_mode: bool = false, p_project_root := "", p_project_source: StringName = &"") -> void:
	# Gated in the service, not in the UI: `res://` is a read-only `.pck` once
	# exported, and a save that silently does nothing is the worst outcome here.
	dev_mode = p_dev_mode and OS.has_feature("editor")
	project_root = p_project_root
	project_source = p_project_source


# --- Addressing ---------------------------------------------------------------

## The key a save file and a launch config store. ContentId keeps the source
## explicit (`core:` for shipped maps, `pack:<author>.<pack>/` for projects).
static func runtime_key(source: StringName, id: StringName) -> StringName:
	return ContentIdScript.runtime_key(source, id)


## Splits a runtime key back into source and id.
static func split_key(key: StringName) -> Dictionary:
	return ContentIdScript.split_runtime_key(key)


static func root_of(source: StringName) -> String:
	return BUILTIN_ROOT if source == SOURCE_BUILTIN else ""


static func package_path(source: StringName, id: StringName) -> String:
	var root := root_of(source)
	return "%s/%s%s" % [root, id, PACKAGE_SUFFIX] if not root.is_empty() else ""


## The source this mode writes under, and the folder it writes into.
func target_source() -> StringName:
	if not project_source.is_empty():
		return project_source
	return SOURCE_BUILTIN if dev_mode else &""


func base_dir() -> String:
	if not project_root.is_empty():
		return project_root.path_join("maps")
	return BUILTIN_ROOT if dev_mode else ""


## Whether this mode may write `path`. A player who opened a shipped map gets
## `false`, which detaches the document (content_packaging.md §6.4) instead of
## failing the save after the author has already done the work.
func can_write(path: String) -> bool:
	if path.is_empty():
		return false
	return not base_dir().is_empty() and path.begins_with(base_dir() + "/")


# --- Listing ------------------------------------------------------------------

## Every map the player can pick, built-in first. Each entry carries enough to
## draw a menu row without opening the terrain layer: source, id, runtime key,
## name, board size and whether a preview exists.
func list_maps() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_ensure_content_index()
	last_errors = _content_index.errors.duplicate()
	for indexed_entry in _content_index.map_entries():
		var parsed: Dictionary = indexed_entry.metadata
		var meta := MapMeta.from_dict(parsed)
		found.append({"source": indexed_entry.source, "id": indexed_entry.id,
			"key": indexed_entry.runtime_key, "name": meta.name if not meta.name.is_empty() else String(indexed_entry.id),
			"kind": meta.kind, "map_kind": meta.map_kind, "players": meta.players,
			"board_cells": meta.board_cells, "revision": meta.revision,
			"game_definition": meta.start.game_definition,
			"author": meta.author, "path": indexed_entry.path,
			"writable": can_write(indexed_entry.path),
			"has_preview": FileAccess.file_exists(indexed_entry.path.path_join(PREVIEW_PNG))})
	return found


func _ensure_content_index() -> void:
	# One host-owned index, refreshed by whoever writes content. This service used
	# to reparse every pack per query, which cost a full disk walk per map listed.
	_content_index = ContentIndexScript.shared()


## Header only — `map.json` without the binary layers. This is what a map list
## needs, and reading terrain for it would make the menu wait on every map.
func read_header(source: StringName, id: StringName) -> Dictionary:
	_ensure_content_index()
	var entry := _content_index.get_entry(runtime_key(source, id))
	var path := entry.path if entry != null else package_path(source, id)
	var parsed := _read_json(path.path_join(MAP_JSON))
	if parsed.is_empty():
		return {}
	# Through the same migration the loader runs: the launch screen must offer the
	# entrances of a v7 map too, and those are the ones the migration invents.
	var upgraded := MapFormatMigration.upgrade(parsed)
	if upgraded.is_empty():
		return {}
	var meta := MapMeta.from_dict(upgraded)
	return {
		"source": source,
		"id": id,
		"key": runtime_key(source, id),
		"name": meta.name if not meta.name.is_empty() else String(id),
		"kind": meta.kind,
		"board_cells": meta.board_cells,
		"revision": meta.revision,
		"game_definition": meta.start.game_definition,
		# The launch screen needs the era policy before it has a session, and the
		# header is the only place it can get it without decoding the terrain.
		"progression": meta.start.progression,
		# Entrances and their overrides decide both the start carousel and the
		# parameter chain (`map_start.md` §3, §2.5), and both are needed before a
		# session exists — so the whole start record travels with the header.
		"start": meta.start,
		"author": meta.author,
		"path": path,
		"has_preview": FileAccess.file_exists(path.path_join(PREVIEW_PNG)),
	}


# --- Loading ------------------------------------------------------------------

## Package folder a runtime key resolves to, or "" when nothing claims it. The
## editor needs this to remember where an opened map came from.
func map_path(key: StringName) -> String:
	_ensure_content_index()
	var entry = _content_index.get_entry(key)
	return entry.path if entry != null else ""


func load_map(key: StringName) -> MapDocument:
	_ensure_content_index()
	var entry = _content_index.get_entry(key)
	if entry == null or entry.content_type != &"map":
		last_error = "карта не найдена: %s" % key
		return null
	return load_package(entry.path)


## Opens a package folder. Returns null and sets `last_error` on a map that is not
## there or whose header is unreadable. A declared scatter layer is also fatal
## when its binary is missing/corrupt: opening it as an empty forest and saving
## would destroy content while pretending the operation succeeded.
func load_package(path: String) -> MapDocument:
	last_error = ""
	var parsed := _read_json(path.path_join(MAP_JSON))
	if parsed.is_empty():
		last_error = "map.json не читается: %s" % path
		return null

	var version := int(parsed.get("format_version", 0))
	# An older map is upgraded here, before any typed reader sees it, so the whole
	# format-history problem lives in one file instead of in every consumer.
	var upgraded := MapFormatMigration.upgrade(parsed)
	if upgraded.is_empty():
		last_error = "неподдерживаемая версия карты (%d, требуется %d)" % [version, MapMeta.FORMAT_VERSION]
		return null

	var document := MapDocument.from_json(upgraded)
	var terrain_path := path.path_join(TERRAIN_BIN)
	if FileAccess.file_exists(terrain_path):
		var buffer := FileAccess.get_file_as_bytes(terrain_path)
		if not MapTerrainCodec.decode_into(buffer, document.terrain):
			# Loud but not fatal: the author keeps their markers, rules and
			# placements and can see at once that the ground is wrong.
			push_warning("[map] terrain.bin не подходит к доске %d: %s" % [
				document.meta.board_cells, terrain_path,
			])
	# Water is read after the registry came out of `map.json`: a cell reference to
	# a body nobody registered is refused by the layer and would decode as dry.
	var water_path := path.path_join(WATER_BIN)
	var water_repaired := false
	if FileAccess.file_exists(water_path):
		var water_buffer := FileAccess.get_file_as_bytes(water_path)
		if not MapWaterCodec.decode_into(water_buffer, document.water):
			document.water.clear_bodies()
			water_repaired = true
			push_warning("[map] water.bin не подходит к доске %d: %s" % [
				document.meta.board_cells, water_path,
			])
	var damaged_water := document.water.remove_damaged_bodies(document.terrain)
	if not damaged_water.is_empty():
		water_repaired = true
		push_warning("[map] удалены повреждённые водоёмы: %s" % damaged_water)
	# Coverage is independent of both layers above: it neither moves ground nor
	# references a registry, so it decodes last and a mismatch costs only the paths.
	var surface_path := path.path_join(SURFACE_BIN)
	if FileAccess.file_exists(surface_path):
		var surface_buffer := FileAccess.get_file_as_bytes(surface_path)
		if not MapCoverageCodec.decode_into(surface_buffer, document.coverage):
			push_warning("[map] surface.bin не подходит к доске %d: %s" % [
				document.meta.board_cells, surface_path,
			])
	# Массовое наполнение читается последним и ни на что не влияет: его таблица
	# архетипов уже прочитана из `map.json`, поэтому запись, ссылающаяся на
	# архетип вне таблицы, отвергает весь файл целиком — половина леса хуже, чем
	# его отсутствие, потому что «половина» не видна.
	var objects_path := path.path_join(OBJECTS_BIN)
	var scatter_declared := document.scatter.expected_count > 0
	if FileAccess.file_exists(objects_path):
		var objects_buffer := FileAccess.get_file_as_bytes(objects_path)
		if not MapScatterCodec.decode_into(objects_buffer, document.scatter, true):
			last_error = "objects.bin повреждён или не соответствует map.json: %s" % objects_path
			return null
	elif scatter_declared:
		last_error = "map.json объявляет %d записей, но objects.bin отсутствует: %s" % [
			document.scatter.expected_count, objects_path]
		return null
	document.dirty = water_repaired
	return document


# --- Saving -------------------------------------------------------------------

## Writes to the package folder this source and id address. An empty `source` means
## "whatever this mode writes" — the normal case for the editor, and the reason a
## player-mode save never lands in the shipped pack.
##
## `preview` is the reserved hook for map thumbnails (`map_editor.md` §3.2.1): the
## parameter is plumbed through to the package, but nothing renders one yet.
func save_map(document: MapDocument, source: StringName = &"", preview: Image = null) -> String:
	last_error = ""
	if document == null or String(document.meta.id).is_empty():
		last_error = "у карты нет id"
		return ""
	if not ContentIdScript.is_valid_id(String(document.meta.id)):
		last_error = "ID карты может содержать только латинские строчные буквы, цифры, «_» и «-»"
		return ""
	var effective := source if not String(source).is_empty() else target_source()
	var target := base_dir().path_join("%s%s" % [document.meta.id, PACKAGE_SUFFIX]) \
		if effective == target_source() else package_path(effective, document.meta.id)
	return save_map_to(document, target, preview)


## Writes the package atomically and returns the path, or "" on failure. The
## document's revision is refreshed first, so what lands on disk and what the
## editor holds agree about which revision they are.
##
## This is the raw writer: it honours `final_path` without asking whether the mode
## owns it, because `tools/make_builtin_maps.gd` and tests write shipped packages
## directly. Interactive callers ask `can_write()` first and detach the document
## when the answer is no (content_packaging.md §6.4).
func save_map_to(document: MapDocument, final_path: String, preview: Image = null) -> String:
	last_error = ""
	if document == null:
		last_error = "нечего сохранять"
		return ""
	var removed_water := document.water.remove_damaged_bodies(document.terrain)
	if not removed_water.is_empty():
		document.mark_dirty()
		push_warning("[map] перед сохранением удалены повреждённые водоёмы: %s" % removed_water)
	var zone_errors := document.zones.validate(document.board_cells())
	if not zone_errors.is_empty():
		last_error = "карта содержит ошибки зон: %s" % "; ".join(zone_errors)
		return ""
	# Cross-cutting checks that need the published grids: a spawn in a hole or
	# under impassable water, a hero-mode map without a hero_start (§8.1, §11).
	# The editor may save before a navigation field exists, so null nav_grid is
	# allowed — those checks skip, the rest still run off terrain and water.
	var map_errors := MapValidator.validate(document, document.terrain, document.water, null)
	if not map_errors.is_empty():
		last_error = "карта содержит ошибки: %s" % "; ".join(map_errors)
		return ""

	var staging_path := final_path + ".tmp"
	_populate_required_content(document)
	document.meta.revision = ContentRevisionScript.new_stamp()

	if DirAccess.dir_exists_absolute(staging_path):
		_remove_directory(staging_path)
	if DirAccess.make_dir_recursive_absolute(staging_path) != OK:
		last_error = "не удалось создать %s" % staging_path
		return ""

	if not _write_text(staging_path.path_join(MAP_JSON), JSON.stringify(document.to_json(), "\t")):
		_remove_directory(staging_path)
		return ""

	# An untouched layer is not written at all (§4): the map means "flat board of
	# the default material", and that is exactly what the loader rebuilds.
	var terrain_bytes := MapTerrainCodec.encode(document.terrain)
	if not terrain_bytes.is_empty():
		if not _write_bytes(staging_path.path_join(TERRAIN_BIN), terrain_bytes):
			_remove_directory(staging_path)
			return ""

	# A map with no water carries no water layer, the same rule the ground follows.
	var water_bytes := MapWaterCodec.encode(document.water)
	if not water_bytes.is_empty():
		if not _write_bytes(staging_path.path_join(WATER_BIN), water_bytes):
			_remove_directory(staging_path)
			return ""

	# ...and a map with no paths carries no coverage layer.
	var surface_bytes := MapCoverageCodec.encode(document.coverage)
	if not surface_bytes.is_empty():
		if not _write_bytes(staging_path.path_join(SURFACE_BIN), surface_bytes):
			_remove_directory(staging_path)
			return ""

	# ...и карта без леса не несёт слоя наполнения.
	var object_bytes := MapScatterCodec.encode(document.scatter)
	if not document.scatter.is_empty() and object_bytes.is_empty():
		last_error = "не удалось закодировать objects.bin"
		_remove_directory(staging_path)
		return ""
	if not object_bytes.is_empty():
		if not _write_bytes(staging_path.path_join(OBJECTS_BIN), object_bytes):
			_remove_directory(staging_path)
			return ""

	if preview != null:
		preview.save_png(staging_path.path_join(PREVIEW_PNG))

	# The swap. The old package only disappears once the new one is complete on
	# disk, and it comes back if the rename fails.
	var backup_path := final_path + ".old"
	if DirAccess.dir_exists_absolute(final_path):
		_remove_directory(backup_path)
		if DirAccess.rename_absolute(final_path, backup_path) != OK:
			last_error = "не удалось освободить %s" % final_path
			_remove_directory(staging_path)
			return ""
	if DirAccess.rename_absolute(staging_path, final_path) != OK:
		last_error = "не удалось переименовать %s" % staging_path
		if DirAccess.dir_exists_absolute(backup_path):
			DirAccess.rename_absolute(backup_path, final_path)
		return ""
	_remove_directory(backup_path)
	document.dirty = false
	ContentIndexScript.invalidate()
	return final_path


# --- Filesystem ---------------------------------------------------------------

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## A map must carry authored blueprint references it embeds. Walk raw sections
## so future placement formats participate without coupling this service to them.
static func _populate_required_content(document: MapDocument) -> void:
	var found: Dictionary = {}
	_collect_content_references(document.sections, found)
	# `placements[]` used to be walked as a raw section; it has a typed owner now,
	# and the dependency it creates is the whole reason a record stores a reference
	# instead of a copy (`building_placement.md` §12).
	for placement: MapPlacementRecord in document.placements.placements:
		_collect_content_references(placement.to_dict(), found)
	for entity: MapEntityRecord in document.entities.entities:
		if entity.archetype_id == &"":
			continue
		var archetype_ref := {"kind": "archetype", "id": String(entity.archetype_id)}
		found[JSON.stringify(archetype_ref)] = archetype_ref
		var asset := EntityArchetypeCatalog.asset_of(entity.archetype_id)
		if asset != null:
			var asset_ref := {"kind": "asset", "id": String(asset.id)}
			found[JSON.stringify(asset_ref)] = asset_ref
	# Массовое наполнение — такая же зависимость: тридцать тысяч безымянных
	# деревьев ссылаются на архетип ровно так же, как одно именованное, просто
	# через таблицу слоя.
	for archetype_id: StringName in document.scatter.referenced_archetypes():
		var scattered_ref := {"kind": "archetype", "id": String(archetype_id)}
		found[JSON.stringify(scattered_ref)] = scattered_ref
		var scattered_asset := EntityArchetypeCatalog.asset_of(archetype_id)
		if scattered_asset != null:
			var scattered_asset_ref := {"kind": "asset", "id": String(scattered_asset.id)}
			found[JSON.stringify(scattered_asset_ref)] = scattered_asset_ref
	# Coverage laid on the map is a dependency like any other: the layer stores an
	# index, and an index means nothing without the entry it points at. Shipped
	# surfaces are listed too — a reference to `core:` costs one line and makes the
	# list say what the map actually uses instead of only what it borrows.
	var used_coverage: Dictionary = {}
	for cell: Vector2i in document.coverage.covered_cells():
		used_coverage[document.coverage.index_at(cell)] = true
	for index: int in used_coverage:
		var coverage_id := CoverageCatalog.id_of_index(index)
		if coverage_id == CoverageCatalog.NONE_ID:
			continue
		var coverage_ref := {"kind": "coverage", "id": String(coverage_id)}
		found[JSON.stringify(coverage_ref)] = coverage_ref
	var refs: Array[Dictionary] = []
	for key in found:
		refs.append(found[key])
	refs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	document.meta.required_content = refs


static func _collect_content_references(value: Variant, found: Dictionary) -> void:
	if value is Array:
		for child in value:
			_collect_content_references(child, found)
	elif value is Dictionary:
		var data := value as Dictionary
		var reference: Variant = data.get("blueprint_ref", null)
		if reference is Dictionary:
			var ref := (reference as Dictionary).duplicate(true)
			if not String(ref.get("id", "")).is_empty():
				found[JSON.stringify(ref)] = ref
		for child in data.values():
			_collect_content_references(child, found)


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "не удалось записать %s" % path
		return false
	file.store_string(text)
	file.close()
	return true


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "не удалось записать %s" % path
		return false
	file.store_buffer(bytes)
	file.close()
	return true


static func _remove_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for sub: String in directory.get_directories():
		_remove_directory(path.path_join(sub))
	DirAccess.remove_absolute(path)
