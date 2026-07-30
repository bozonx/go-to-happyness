class_name ContentPackIO
extends RefCounted

## File adapter for the portable `.gdpack` archive.  The archive contains the
## same folder layout as an installed pack, so importing never has to translate
## building or map formats.
const ContentPackScript = preload("res://game/features/content/domain/content_pack.gd")

const INSTALLED_ROOT := "user://content/installed"
const PACK_JSON := "pack.json"

var last_error := ""


## Archives an already assembled pack folder. `root` must contain pack.json;
## local authoring UI can stage selected files into such a folder before it
## calls this adapter.
func export_pack(root: String, target_path: String) -> bool:
	last_error = ""
	var pack := _read_pack(root)
	if pack == null:
		return false
	var writer := ZIPPacker.new()
	if writer.open(target_path) != OK:
		last_error = "не удалось создать .gdpack: %s" % target_path
		return false
	for path in _files_recursively(root):
		var relative := path.trim_prefix(root.path_join(""))
		if writer.start_file(relative) != OK:
			last_error = "не удалось добавить в .gdpack: %s" % relative
			writer.close()
			return false
		writer.write_file(FileAccess.get_file_as_bytes(path))
		writer.close_file()
	writer.close()
	return true


## Installs into `user://content/installed/<author>.<id>`.  Extraction first
## happens in a sibling staging directory, then swaps into place atomically.
func import_pack(archive_path: String) -> String:
	last_error = ""
	var reader := ZIPReader.new()
	if reader.open(archive_path) != OK:
		last_error = "не удалось открыть .gdpack: %s" % archive_path
		return ""
	var pack_json := reader.read_file(PACK_JSON)
	var parsed: Variant = JSON.parse_string(pack_json.get_string_from_utf8())
	var pack := ContentPackScript.new()
	if not (parsed is Dictionary) or not pack.read_from_dict(parsed, "", &"installed"):
		reader.close()
		last_error = "в .gdpack нет корректного pack.json"
		return ""
	var folder := _safe_folder_name(pack.author_id, pack.id)
	var final_path := INSTALLED_ROOT.path_join(folder)
	var staging_path := final_path + ".tmp"
	_remove_directory(staging_path)
	if DirAccess.make_dir_recursive_absolute(staging_path) != OK:
		reader.close()
		last_error = "не удалось создать папку установки"
		return ""
	for entry: String in reader.get_files():
		# ZIP readers expose implicit folder entries too; they carry no payload.
		if entry.ends_with("/"):
			if not _safe_archive_path(entry.trim_suffix("/")):
				reader.close()
				_remove_directory(staging_path)
				last_error = "небезопасный путь в .gdpack: %s" % entry
				return ""
			if DirAccess.make_dir_recursive_absolute(staging_path.path_join(entry)) != OK:
				reader.close()
				_remove_directory(staging_path)
				last_error = "не удалось создать путь пакета: %s" % entry
				return ""
			continue
		if not _safe_archive_path(entry):
			reader.close()
			_remove_directory(staging_path)
			last_error = "небезопасный путь в .gdpack: %s" % entry
			return ""
		var output_path := staging_path.path_join(entry)
		if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir()) != OK:
			reader.close()
			_remove_directory(staging_path)
			last_error = "не удалось создать путь пакета: %s" % entry
			return ""
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			reader.close()
			_remove_directory(staging_path)
			last_error = "не удалось распаковать: %s" % entry
			return ""
		file.store_buffer(reader.read_file(entry))
		file.close()
	reader.close()
	var backup_path := final_path + ".old"
	_remove_directory(backup_path)
	if DirAccess.dir_exists_absolute(final_path) and DirAccess.rename_absolute(final_path, backup_path) != OK:
		_remove_directory(staging_path)
		last_error = "не удалось обновить установленный пак"
		return ""
	if DirAccess.rename_absolute(staging_path, final_path) != OK:
		if DirAccess.dir_exists_absolute(backup_path):
			DirAccess.rename_absolute(backup_path, final_path)
		last_error = "не удалось завершить установку пака"
		return ""
	_remove_directory(backup_path)
	return final_path


func _read_pack(root: String) -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(PACK_JSON)))
	var pack := ContentPackScript.new()
	if not (parsed is Dictionary) or not pack.read_from_dict(parsed, root):
		last_error = "нет корректного pack.json: %s" % root
		return null
	return pack


static func _files_recursively(root: String) -> Array[String]:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		return files
	for file_name in DirAccess.get_files_at(root):
		files.append(root.path_join(file_name))
	for directory in DirAccess.get_directories_at(root):
		files.append_array(_files_recursively(root.path_join(directory)))
	files.sort()
	return files


static func _safe_archive_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.begins_with("\\"):
		return false
	for part in path.replace("\\", "/").split("/", false):
		if part == "." or part == ".." or part.is_empty():
			return false
	return true


static func _safe_folder_name(author_id: StringName, id: StringName) -> String:
	var value := (String(author_id) + "." + String(id)).to_lower()
	var safe := ""
	for character in value:
		if character.to_lower() >= "a" and character.to_lower() <= "z" or character >= "0" and character <= "9" or character == "." or character == "_" or character == "-":
			safe += character
	return safe if not safe.is_empty() else "installed_pack"


static func _remove_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory in DirAccess.get_directories_at(path):
		_remove_directory(path.path_join(directory))
	DirAccess.remove_absolute(path)
