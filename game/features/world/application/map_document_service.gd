class_name MapDocumentService
extends RefCounted

## Reads and writes `.gdmap` packages (design_docs/engine/map_editor.md §4).
##
## A map is a folder, not a file: the terrain layer is 320 KB of binary at
## 256×256 and would become megabytes as text. The folder holds `map.json`, the
## binary layers and a preview image.
##
## Two sources, exactly as blueprints have them. A built-in map is addressed by
## its bare id; a player one carries the `user:` namespace, so a downloaded map
## called `green_valley` cannot quietly replace the shipped one of that name.
##
## Saving is atomic: the package is written to a sibling temporary folder and only
## then swapped in. A crash mid-save leaves the previous map intact rather than a
## folder with a new `map.json` and last week's terrain.

const ContentRevisionScript = preload("res://game/features/content/domain/content_revision.gd")
const ContentIndexScript = preload("res://game/features/content/application/content_index.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")

const SOURCE_BUILTIN := &"core"
const SOURCE_PLAYER := &"local"

const BUILTIN_ROOT := "res://game/content/core/maps"
const PLAYER_ROOT := "user://content/local/maps"

const PACKAGE_SUFFIX := ".gdmap"
const MAP_JSON := "map.json"
const TERRAIN_BIN := "terrain.bin"
const WATER_BIN := "water.bin"
const PREVIEW_PNG := "preview.png"
## Reserved names of the layers phase 3 adds. Listed so a save that does not write
## them still knows not to treat them as strays when cleaning up.
const KNOWN_FILES: Array[String] = [MAP_JSON, TERRAIN_BIN, WATER_BIN, "surface.bin", PREVIEW_PNG]

const USER_NAMESPACE := "user:"

var last_error := ""
var _content_index: ContentIndex


# --- Addressing ---------------------------------------------------------------

## The key a save file and a launch config store. Built-in maps keep their bare
## id so shipped content is addressed the same way it always was.
static func runtime_key(source: StringName, id: StringName) -> StringName:
	return ContentIdScript.runtime_key(source, id)


## Splits a runtime key back into source and id.
static func split_key(key: StringName) -> Dictionary:
	return ContentIdScript.split_runtime_key(key)


static func root_of(source: StringName) -> String:
	return PLAYER_ROOT if source == SOURCE_PLAYER else BUILTIN_ROOT


static func package_path(source: StringName, id: StringName) -> String:
	return "%s/%s%s" % [root_of(source), id, PACKAGE_SUFFIX]


# --- Listing ------------------------------------------------------------------

## Every map the player can pick, built-in first. Each entry carries enough to
## draw a menu row without opening the terrain layer: source, id, runtime key,
## name, board size and whether a preview exists.
func list_maps() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_ensure_content_index()
	for indexed_entry in _content_index.map_entries():
		var parsed: Dictionary = indexed_entry.metadata
		var meta := MapMeta.from_dict(parsed)
		found.append({"source": indexed_entry.source, "id": indexed_entry.id,
			"key": indexed_entry.runtime_key, "name": meta.name if not meta.name.is_empty() else String(indexed_entry.id),
			"kind": meta.kind, "board_cells": meta.board_cells, "revision": meta.revision,
			"author": meta.author, "path": indexed_entry.path,
			"has_preview": FileAccess.file_exists(indexed_entry.path.path_join(PREVIEW_PNG))})
	return found


func _ensure_content_index() -> void:
	# Rebuild each query: player authors can save content without notifying this
	# service, and phase 1 deliberately has no persistent cache yet.
	_content_index = ContentIndexScript.new()
	_content_index.rebuild()


## Header only — `map.json` without the binary layers. This is what a map list
## needs, and reading terrain for it would make the menu wait on every map.
func read_header(source: StringName, id: StringName) -> Dictionary:
	_ensure_content_index()
	var entry := _content_index.get_entry(runtime_key(source, id))
	var path := entry.path if entry != null else package_path(source, id)
	var parsed := _read_json(path.path_join(MAP_JSON))
	if parsed.is_empty():
		return {}
	var meta := MapMeta.from_dict(parsed)
	return {
		"source": source,
		"id": id,
		"key": runtime_key(source, id),
		"name": meta.name if not meta.name.is_empty() else String(id),
		"kind": meta.kind,
		"board_cells": meta.board_cells,
		"revision": meta.revision,
		"author": meta.author,
		"path": path,
		"has_preview": FileAccess.file_exists(path.path_join(PREVIEW_PNG)),
	}


func _ids_in(root: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return ids
	for entry: String in directory.get_directories():
		if entry.ends_with(PACKAGE_SUFFIX):
			ids.append(StringName(entry.trim_suffix(PACKAGE_SUFFIX)))
	ids.sort()
	return ids


# --- Loading ------------------------------------------------------------------

func load_map(key: StringName) -> MapDocument:
	_ensure_content_index()
	var entry = _content_index.get_entry(key)
	if entry == null or entry.content_type != &"map":
		last_error = "карта не найдена: %s" % key
		return null
	return load_package(entry.path)


## Opens a package folder. Returns null and sets `last_error` on a map that is not
## there or whose header is unreadable; a missing or mismatched terrain layer is
## NOT fatal — the board simply stays flat, which is what an untouched layer means.
func load_package(path: String) -> MapDocument:
	last_error = ""
	var parsed := _read_json(path.path_join(MAP_JSON))
	if parsed.is_empty():
		last_error = "map.json не читается: %s" % path
		return null

	var version := int(parsed.get("format_version", MapMeta.FORMAT_VERSION))
	if version > MapMeta.FORMAT_VERSION:
		last_error = "карта создана более новой версией формата (%d)" % version
		return null
	parsed = _migrate(parsed, version)

	var document := MapDocument.from_json(parsed)
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
	if FileAccess.file_exists(water_path):
		var water_buffer := FileAccess.get_file_as_bytes(water_path)
		if not MapWaterCodec.decode_into(water_buffer, document.water):
			push_warning("[map] water.bin не подходит к доске %d: %s" % [
				document.meta.board_cells, water_path,
			])
	document.dirty = false
	return document


## Files of past versions are brought forward here; writing always emits the
## current version. Nothing to do yet — version 1 is the first.
static func _migrate(parsed: Dictionary, _from_version: int) -> Dictionary:
	return parsed


# --- Saving -------------------------------------------------------------------

## Writes to the package folder this source and id address. Built-in maps are only
## writable from a development build; `res://` is read-only once exported.
func save_map(document: MapDocument, source: StringName = SOURCE_PLAYER, preview: Image = null) -> String:
	last_error = ""
	if document == null or String(document.meta.id).is_empty():
		last_error = "у карты нет id"
		return ""
	return save_map_to(document, package_path(source, document.meta.id), preview)


## Writes the package atomically and returns the path, or "" on failure. The
## document's revision is refreshed first, so what lands on disk and what the
## editor holds agree about which revision they are.
func save_map_to(document: MapDocument, final_path: String, preview: Image = null) -> String:
	last_error = ""
	if document == null:
		last_error = "нечего сохранять"
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
