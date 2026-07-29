extends SceneTree

## Phase A leftover: an authored game installed as a data pack must run through the
## same generic path as the built-in games. This fixture proves the full loop —
## install → index → resolve → validate → launch — without a custom GDScript module
## and without touching `SettlementGame`.

const GAME_RUNTIME_SCENE := preload("res://game/bootstrap/game_runtime.tscn")

const FIXTURE_ROOT := "res://tests/fixtures/test_user_pack"
const INSTALLED_ROOT := "user://content/installed"
## `<author>.<pack>` is the installed-pack folder contract (`content_packaging.md`
## §6.1); `ContentId.runtime_key` turns it into `pack:gth.test_user_pack/<game>`.
const INSTALLED_FOLDER := "gth.test_user_pack"
const GAME_KEY := &"pack:gth.test_user_pack/sky_island_tour"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_install_fixture()

	var index := ContentIndex.new()
	index.rebuild()
	var entry := index.get_entry(GAME_KEY)
	assert(entry != null, "an installed user-pack game must be indexed by its runtime key")
	assert(entry.content_type == &"game")
	assert(entry.path.ends_with("sky_island_tour.gdgame.json"))

	var definition := GameModuleRegistry.resolve_definition(GAME_KEY)
	assert(definition != null, "resolve_definition must load the authored .gdgame.json")
	assert(definition.runtime_key == GAME_KEY)
	assert(definition.module_ids == [&"core.world", &"gth.world_showcase"])
	# An authored game that only composes built-in modules must validate clean — the
	# whole point of data-driven game composition.
	var errors := GameModuleRegistry.validate_definition(definition)
	assert(errors.is_empty(), "validation must pass: %s" % ", ".join(errors))

	var map := MapDocumentService.new().load_map(definition.default_map)
	assert(map != null, "authored game reuses a built-in map")

	var launch_manager := root.get_node_or_null("GameLaunchManager")
	assert(launch_manager != null, "GameLaunchManager autoload is required")
	launch_manager.set("active_session", GameSessionConfig.create(definition, definition.default_map, map))
	var runtime := GAME_RUNTIME_SCENE.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame

	# The authored game is `gth.world_showcase`, not settlement: one runtime, many games,
	# and the user pack never needed its own executable or module script.
	assert(runtime.active_session != null)
	assert(runtime.active_modules.has(&"core.world"))
	assert(runtime.active_modules.has(&"gth.world_showcase"))
	assert(not runtime.active_modules.has(&"gth.settlement"))
	assert(runtime.world_session != null)
	var showcase := runtime.session_content as WorldShowcase
	assert(showcase != null, "the user-pack game must not instantiate SettlementGame")
	assert(showcase.world_setup != null)

	runtime.queue_free()
	await process_frame
	_uninstall_fixture()
	# After cleanup the installed game is gone, so the content index no longer lists it.
	# `get_entry` is the lookup primitive; `resolve_definition` would log a spurious error.
	var rebuilt := ContentIndex.new()
	rebuilt.rebuild()
	assert(rebuilt.get_entry(GAME_KEY) == null, "uninstall must remove the game from the index")
	print("--- test_user_pack_game.gd PASSED ---")
	quit(0)


## Copies the fixture pack into the installed-content root the same way a pack
## installer would, so the host content index discovers it on its next rebuild.
func _install_fixture() -> void:
	var target := INSTALLED_ROOT.path_join(INSTALLED_FOLDER)
	_remove_directory(target)
	assert(DirAccess.make_dir_recursive_absolute(target) == OK)
	_copy_tree(FIXTURE_ROOT, target)


func _uninstall_fixture() -> void:
	_remove_directory(INSTALLED_ROOT.path_join(INSTALLED_FOLDER))


func _copy_tree(from: String, to: String) -> void:
	for file_name in DirAccess.get_files_at(from):
		assert(DirAccess.copy_absolute(from.path_join(file_name), to.path_join(file_name)) == OK)
	for directory in DirAccess.get_directories_at(from):
		var sub := to.path_join(directory)
		assert(DirAccess.make_dir_recursive_absolute(sub) == OK)
		_copy_tree(from.path_join(directory), sub)


func _remove_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for directory in DirAccess.get_directories_at(path):
		_remove_directory(path.path_join(directory))
	DirAccess.remove_absolute(path)
