class_name TestDomainHarvestSources
extends RefCounted

## Depleting natural sources: grass tufts and bushes.
##
## The rule under test is that both stands deplete by exactly one mechanism.
## Bushes were added after grass, and the failure mode this guards against is the
## obvious one — a second copy of "count down, free the node, drop the entry" that
## slowly stops matching the first.

const HarvestSourceRecordScript = preload("res://game/features/production/domain/harvest_source_record.gd")


static func run_all() -> void:
	_test_record_depletes_once_and_stays_empty()
	_test_branches_come_from_bushes_when_no_tree_stands_there()
	_test_bush_state_survives_a_save()
	print("    [PASS] Harvest Source Tests")


static func _test_record_depletes_once_and_stays_empty() -> void:
	var record := HarvestSourceRecordScript.new(null, 2, 2)
	assert(not record.is_spent())
	assert(record.take_one() == 1)
	assert(record.remaining == 1)
	assert(record.take_one() == 1)
	assert(record.is_spent())
	# An exhausted source yields nothing rather than going negative; the caller
	# uses the returned amount to decide whether the citizen actually got paid.
	assert(record.take_one() == 0)
	assert(record.remaining == 0)


## A citizen sent for branches must be paid whether it walked to a tree or to a
## bush; that is why there is one `consume_branches` and not two call sites in
## `CitizenActor`.
static func _test_branches_come_from_bushes_when_no_tree_stands_there() -> void:
	var service := ForagingService.new()
	var bushes: Dictionary = {}
	var cell := Vector2i(3, 4)
	bushes[cell] = HarvestSourceRecordScript.new(null, 2, 2)
	service.setup(
		null, null, [] as Array[Vector3], {}, {}, {}, {}, [] as Array[Vector3], {},
		Callable(), func(position: Vector3) -> Vector2i:
			return Vector2i(int(floor(position.x)), int(floor(position.z))),
		Callable(), bushes
	)

	var at_bush := Vector3(3.5, 0.0, 4.5)
	assert(service.consume_branches(at_bush) == 1, "куст обязан отдать ветку")
	assert((bushes[cell] as HarvestSourceRecord).remaining == 1)
	assert(service.consume_branches(at_bush) == 1)
	# Emptied out, the bush leaves the collection instead of lingering at zero and
	# attracting citizens to a source with nothing in it.
	assert(not bushes.has(cell), "пустой куст должен исчезнуть из набора")
	assert(service.consume_branches(at_bush) == 0)

	# Nothing anywhere near is not an error, it is simply nothing.
	assert(service.consume_branches(Vector3(80.0, 0.0, 80.0)) == 0)


static func _test_bush_state_survives_a_save() -> void:
	var bushes: Dictionary = {Vector2i(2, 7): HarvestSourceRecordScript.new(null, 1, 4)}
	var grass: Dictionary = {Vector2i(0, 0): HarvestSourceRecordScript.new(null, 3, 3)}
	var state := WorldResourceState.new()
	state.capture(grass, {}, {}, bushes)
	var saved := state.to_save_dict()
	assert(saved.has("bush_sources"))

	var restored := WorldResourceState.new()
	restored.load_from_save_dict(saved)
	assert(restored.bush_sources.size() == 1)
	var entry: Dictionary = restored.bush_sources[0]
	assert(int(entry["remaining"]) == 1)
	assert(int(entry["initial"]) == 4)
	assert(restored.grass_sources.size() == 1, "трава и кусты не должны смешиваться")

	# A save written before bushes existed simply had none — it must still load.
	var legacy := WorldResourceState.new()
	legacy.load_from_save_dict({"grass_sources": [], "forage_cells": [], "rabbits": []})
	assert(legacy.bush_sources.is_empty())
