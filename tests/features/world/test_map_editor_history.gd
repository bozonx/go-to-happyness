class_name TestMapEditorHistory
extends RefCounted

## The editor's shared undo stack (map_editor.md §3.3).
##
## Tests the stack itself, not the commands: a dummy command that counts its
## apply/revert calls is enough to prove the stack orders, discards redo
## branches, caps depth, and emits `changed` at the right times.

const MAX_DEPTH := MapEditorHistory.MAX_DEPTH


static func run_all() -> void:
	_test_push_and_undo()
	_test_push_discards_redo_branch()
	_test_can_undo_and_can_redo()
	_test_undo_label_on_empty()
	_test_clear_empties_both_stacks()
	_test_depth_cap_evicts_oldest()
	_test_undo_failure_emits_changed_and_keeps_command()
	_test_redo_failure_emits_changed_and_keeps_command()
	_test_push_null_is_ignored()
	_test_service_command_replays_its_exact_delta()
	_test_composite_runs_parts_in_order_and_reverses_them()
	_test_composite_rolls_back_a_failed_part()
	print("    [PASS] Map Editor History Tests")


# --- Dummy command ------------------------------------------------------------

## A command that counts calls and can be made to fail on demand.
class _CountingCommand extends MapEditorCommand:
	var undo_count := 0
	var redo_count := 0
	var fail_undo := false
	var fail_redo := false

	func _init(command_label: String = "test") -> void:
		label = command_label

	func apply_on_push() -> bool:
		return false

	func redo() -> bool:
		redo_count += 1
		return not fail_redo

	func undo() -> bool:
		undo_count += 1
		return not fail_undo


# --- Tests --------------------------------------------------------------------

static func _test_push_and_undo() -> void:
	var history := MapEditorHistory.new()
	var a := _CountingCommand.new("a")
	var b := _CountingCommand.new("b")

	assert(history.push(a))
	assert(history.push(b))
	assert(history.undo_depth() == 2)
	assert(history.can_undo())

	# Undo b, then a.
	assert(history.undo())
	assert(history.redo_depth() == 1)
	assert(b.undo_count == 1)
	assert(history.undo())
	assert(history.redo_depth() == 2)
	assert(a.undo_count == 1)

	# Redo a, then b.
	assert(history.redo())
	assert(a.redo_count == 1)
	assert(history.redo())
	assert(b.redo_count == 1)
	assert(history.redo_depth() == 0)


static func _test_push_discards_redo_branch() -> void:
	var history := MapEditorHistory.new()
	var a := _CountingCommand.new("a")
	var b := _CountingCommand.new("b")
	var c := _CountingCommand.new("c")

	history.push(a)
	history.push(b)
	history.undo()
	assert(history.can_redo())

	# A new push after an undo discards the redo branch.
	history.push(c)
	assert(not history.can_redo())
	assert(history.undo_depth() == 2)
	# c is on top.
	assert(history.undo_label() == "c")


static func _test_can_undo_and_can_redo() -> void:
	var history := MapEditorHistory.new()
	assert(not history.can_undo())
	assert(not history.can_redo())

	history.push(_CountingCommand.new())
	assert(history.can_undo())
	assert(not history.can_redo())

	history.undo()
	assert(not history.can_undo())
	assert(history.can_redo())


static func _test_undo_label_on_empty() -> void:
	var history := MapEditorHistory.new()
	assert(history.undo_label() == "")

	history.push(_CountingCommand.new("stroke"))
	assert(history.undo_label() == "stroke")


static func _test_clear_empties_both_stacks() -> void:
	var history := MapEditorHistory.new()
	history.push(_CountingCommand.new("a"))
	history.push(_CountingCommand.new("b"))
	history.undo()

	history.clear()
	assert(history.undo_depth() == 0)
	assert(history.redo_depth() == 0)
	assert(not history.can_undo())
	assert(not history.can_redo())


static func _test_depth_cap_evicts_oldest() -> void:
	var history := MapEditorHistory.new()
	# Push more than the cap.
	for i in range(MAX_DEPTH + 10):
		history.push(_CountingCommand.new("cmd_%d" % i))
	assert(history.undo_depth() == MAX_DEPTH)
	# The oldest should have been evicted; the newest should be on top.
	assert(history.undo_label() == "cmd_%d" % (MAX_DEPTH + 9))


static func _test_undo_failure_emits_changed_and_keeps_command() -> void:
	var history := MapEditorHistory.new()
	var cmd := _CountingCommand.new("failing")
	cmd.fail_undo = true

	var changed_count := [0]
	history.changed.connect(func() -> void: changed_count[0] += 1)

	history.push(cmd)
	assert(history.undo_depth() == 1)

	# Undo fails: the command stays on the stack, changed is emitted.
	var before: int = changed_count[0]
	assert(not history.undo())
	assert(changed_count[0] == before + 1)
	assert(history.undo_depth() == 1)
	assert(history.can_undo())


static func _test_redo_failure_emits_changed_and_keeps_command() -> void:
	var history := MapEditorHistory.new()
	var cmd := _CountingCommand.new("failing_redo")
	cmd.fail_redo = true

	var changed_count := [0]
	history.changed.connect(func() -> void: changed_count[0] += 1)

	history.push(cmd)
	history.undo()
	assert(history.can_redo())

	# Redo fails: the command stays on the redo stack, changed is emitted.
	var before: int = changed_count[0]
	assert(not history.redo())
	assert(changed_count[0] == before + 1)
	assert(history.can_redo())


static func _test_push_null_is_ignored() -> void:
	var history := MapEditorHistory.new()
	assert(not history.push(null))
	assert(history.undo_depth() == 0)


## Map commands must name a concrete service delta.  Delegating to bare
## `service.undo()` makes a stale global-history entry undo an unrelated edit.
static func _test_service_command_replays_its_exact_delta() -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, 8)
	var service := TerrainService.new()
	service.configure(grid)
	var first_cell := Vector2i(0, 0)
	var second_cell := Vector2i(1, 0)
	assert(service.apply_operation(TerrainEditOperation.offset([first_cell] as Array[Vector2i], 1)))
	var first := service.last_delta()
	assert(service.apply_operation(TerrainEditOperation.offset([second_cell] as Array[Vector2i], 1)))
	var second := service.last_delta()

	var history := MapEditorHistory.new()
	assert(history.push(TerrainServiceCommand.of(service, first, "first")))
	assert(history.push(TerrainServiceCommand.of(service, second, "second")))
	assert(history.undo())
	assert(grid.height_of(second_cell) == 0)
	assert(grid.height_of(first_cell) == 1)
	assert(history.undo())
	assert(grid.height_of(first_cell) == 0)
	assert(history.redo())
	assert(grid.height_of(first_cell) == 1)


# --- Composite ------------------------------------------------------------------

## One author action that produced edits in two layers — digging to the coast on a
## map with an ocean border (`map_editor.md` §6.1) — is one entry on the stack.
## Redo replays the parts in order and undo reverses them, because the later part
## was computed against the state the earlier one produced.
static func _test_composite_runs_parts_in_order_and_reverses_them() -> void:
	var order: Array[String] = []
	var first := _RecordingCommand.new("terrain", order)
	var second := _RecordingCommand.new("water", order)
	var parts: Array[MapEditorCommand] = [first, second]
	var composite := MapEditorCompositeCommand.of(parts, "рельеф + океан")
	assert(composite.part_count() == 2)
	assert(not composite.apply_on_push(), "the services already committed both parts")

	var history := MapEditorHistory.new()
	assert(history.push(composite))
	assert(history.undo_label() == "рельеф + океан")

	assert(history.undo())
	assert(order == ["undo:water", "undo:terrain"])
	order.clear()
	assert(history.redo())
	assert(order == ["redo:terrain", "redo:water"])


## A half-undone composite is a state no author asked for, so a refusing part puts
## the ones already reversed back.
static func _test_composite_rolls_back_a_failed_part() -> void:
	var order: Array[String] = []
	var first := _RecordingCommand.new("terrain", order)
	first.fail_undo = true
	var second := _RecordingCommand.new("water", order)
	var parts: Array[MapEditorCommand] = [first, second]
	var composite := MapEditorCompositeCommand.of(parts, "рельеф + океан")

	assert(not composite.undo(), "the composite reports the refusal")
	assert(order == ["undo:water", "undo:terrain", "redo:water"], "the part that did undo is re-applied")


class _RecordingCommand extends MapEditorCommand:
	var fail_undo := false
	var _name := ""
	var _order: Array[String]

	func _init(command_name: String, order: Array[String]) -> void:
		_name = command_name
		_order = order
		label = command_name

	func apply_on_push() -> bool:
		return false

	func redo() -> bool:
		_order.append("redo:%s" % _name)
		return true

	func undo() -> bool:
		_order.append("undo:%s" % _name)
		return not fail_undo
