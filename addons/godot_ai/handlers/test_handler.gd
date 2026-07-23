@tool
extends RefCounted

## Discovers and runs McpTestSuite scripts from res://tests/.
## Exposes run_tests and get_test_results as MCP commands.

var _runner: McpTestRunner
var _undo_redo: EditorUndoRedoManager
var _log_buffer: McpLogBuffer


func _init(undo_redo: EditorUndoRedoManager, log_buffer: McpLogBuffer) -> void:
	_runner = McpTestRunner.new()
	_undo_redo = undo_redo
	_log_buffer = log_buffer


func run_tests(params: Dictionary) -> Dictionary:
	var suite_filter: String = params.get("suite", "")
	var test_filter: String = params.get("test_name", "")
	var exclude_test_filter: String = params.get("exclude_test_name", "")
	var verbose: bool = params.get("verbose", false)

	var discovery := _discover_suites()
	var suites: Array = discovery.suites
	if suites.is_empty():
		var msg := "No test suites found in res://tests/"
		if not discovery.errors.is_empty():
			msg += " (%d script(s) failed to load: %s)" % [
				discovery.errors.size(),
				", ".join(discovery.errors),
			]
		var no_suites := {"error": msg, "total": 0, "load_errors": discovery.errors}
		## Keep the edited_scene annotation on the no-suites error payload too,
		## so the response contract is consistent across every return path.
		_annotate_edited_scene(no_suites)
		return {"data": no_suites}

	var ctx := {
		"undo_redo": _undo_redo,
		"log_buffer": _log_buffer,
	}

	var results := _runner.run_suites(suites, suite_filter, test_filter, ctx, verbose, exclude_test_filter)
	if not discovery.errors.is_empty():
		results["load_errors"] = discovery.errors
	_annotate_edited_scene(results)
	return {"data": results}


## Many suites assume the project's main scene is the edited scene (they read
## /Main/... nodes directly). Running with another scene open produces a flood
## of phantom failures that look like real regressions. Surface the edited
## scene and a warning when it differs from run/main_scene so the failures are
## attributable at a glance instead of costing a debugging round (#635).
func _annotate_edited_scene(results: Dictionary) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	var edited := scene_root.scene_file_path if scene_root else ""
	results["edited_scene"] = edited
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene.is_empty() or edited == main_scene:
		return
	if int(results.get("failed", 0)) <= 0:
		return
	results["scene_warning"] = (
		"Edited scene is '%s' but the project main scene is '%s'. Many suites "
		% [edited if not edited.is_empty() else "<none>", main_scene]
		+ "assume the main scene is open and will report phantom failures "
		+ "otherwise. If these failures are unexpected, scene_open('%s') and re-run." % main_scene
	)


func get_test_results(params: Dictionary) -> Dictionary:
	var verbose: bool = params.get("verbose", false)
	return {"data": _runner.get_results(verbose)}


class McpScriptWrapperSuite extends McpTestSuite:
	var _name: String = ""
	var _script: Script = null

	func _init(p_name: String, p_script: Script) -> void:
		_name = p_name
		_script = p_script

	func suite_name() -> String:
		return _name

	func test_execute() -> void:
		assert_true(_script != null, "Script must not be null")
		if _script.has_script_method("run_all"):
			_script.call("run_all")
		elif _script.can_instantiate():
			var inst = _script.new()
			if inst != null and not (inst is RefCounted):
				if inst is Node:
					inst.free()
				elif inst is SceneTree:
					# Tree script executed _init
					pass
				else:
					inst.free()


func _discover_suites() -> Dictionary:
	## Returns {"suites": Array, "errors": Array[String]}.
	## Resilient: a broken script doesn't kill discovery of the rest.
	var suites := []
	var errors: Array[String] = []
	var test_files: Array[String] = []
	_collect_test_files("res://tests", test_files)

	if test_files.is_empty():
		return {"suites": suites, "errors": ["No test files found in res://tests"]}

	for path in test_files:
		var rel_path := path.trim_prefix("res://tests/")
		if rel_path.ends_with("test_ai_helpers.gd") or rel_path.ends_with("run_all.gd"):
			continue
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null:
			errors.append("%s (load failed — check for parse errors or duplicate methods)" % rel_path)
			continue

		var suite_name := rel_path.get_basename()
		if script.can_instantiate():
			var instance = script.new()
			if instance is McpTestSuite:
				suites.append(instance)
			else:
				if instance != null and not (instance is RefCounted):
					if instance is Node:
						instance.free()
					elif instance is SceneTree:
						pass
					else:
						instance.free()
				suites.append(McpScriptWrapperSuite.new(suite_name, script))
		elif script.has_script_method("run_all"):
			suites.append(McpScriptWrapperSuite.new(suite_name, script))
		else:
			errors.append("%s (cannot instantiate — abstract or broken)" % rel_path)

	## Sort by suite name for deterministic order.
	suites.sort_custom(func(a, b) -> bool:
		return a.suite_name() < b.suite_name()
	)
	return {"suites": suites, "errors": errors}


func _collect_test_files(dir_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_test_files(full_path, out_paths)
		elif file_name.begins_with("test_") and file_name.ends_with(".gd"):
			out_paths.append(full_path)
		file_name = dir.get_next()
