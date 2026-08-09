class_name GameRuntime
extends Node3D

## Generic session root. Modules attach their own session presentation below this
## node; it deliberately owns no settlement scene, UI or gameplay state.

const ScenarioBannerScene = preload("res://game/features/runtime/presentation/scenario_banner.tscn")

var active_session: GameSessionConfig = null
var active_modules: Dictionary = {}
var session_content: Node = null
## Created by core.world before any gameplay module starts. It owns the map
## session and the single WorldSetup projection for the active scene host.
var world_session: WorldSession = null
var host_input := HostInputController.new()


func _ready() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	var session: GameSessionConfig = launch_manager.get("active_session") as GameSessionConfig if launch_manager != null else null
	if session == null:
		push_error("[launch] GameRuntime requires an active game session")
		return
	if not SessionBootstrapper.new().run(self, session):
		return
	host_input.configure(session.definition.input_profile)
	_restore_pending_save()
	# The scenario starts after modules and any pending save: a `session_started`
	# rule must see the world the player is about to see, not the one before a
	# save was restored over it. The banner is bound before the start so that
	# rule's message is not lost.
	if world_session != null:
		var banner := ScenarioBannerScene.instantiate() as ScenarioBanner
		add_child(banner)
		banner.bind(world_session.scenario_runtime)
		world_session.scenario_runtime.start()


## Session time for the scenario's `elapsed` triggers. The host drives it rather
## than a gameplay clock because elapsed time is the one schedule every game has:
## a settlement day and a shooter round are module vocabulary, and a module that
## has them publishes its own trigger through `MapScenarioRuntime.publish`.
func _process(delta: float) -> void:
	if world_session != null:
		world_session.scenario_runtime.process(delta)


func attach_session_content(node: Node) -> void:
	if node == null:
		return
	if session_content != null:
		push_error("[launch] session content is already attached")
		return
	session_content = node
	add_child(node)


func register_module(module: GameModule) -> void:
	if module != null:
		active_modules[module.module_id()] = module


## Disposes a partially composed session after a module refuses to start.
func abort_session() -> void:
	active_modules.clear()
	active_session = null
	if session_content != null:
		session_content.queue_free()
		session_content = null


## Stops module-owned resources in reverse dependency order. This is public
## lifecycle API for the host, not an incidental side effect of freeing a node.
func stop_session() -> void:
	var module_ids: Array = active_modules.keys()
	module_ids.reverse()
	for module_id: StringName in module_ids:
		var module: GameModule = active_modules[module_id]
		module.stop(self)
	active_modules.clear()
	active_session = null


func _exit_tree() -> void:
	stop_session()


func _restore_pending_save() -> void:
	var launch_manager := get_node_or_null("/root/GameLaunchManager")
	if launch_manager == null:
		return
	var path := String(launch_manager.get("pending_save_path"))
	if path.is_empty():
		return
	if SessionSaveCoordinator.load_pending(self, path):
		launch_manager.set("pending_save_path", "")


func _unhandled_input(event: InputEvent) -> void:
	# Esc may replace this scene inside the host handler. Keep the root viewport
	# before that happens; asking this Node3D for it after change_scene_to_file()
	# has detached us produces `!is_inside_tree()` and can leave a grey frame.
	var active_viewport := get_viewport()
	if host_input.handle_unhandled_input(event, self):
		active_viewport.set_input_as_handled()
