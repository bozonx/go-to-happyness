class_name SettlementAIWorldFacade
extends AIWorldFacade

## Minimal scene adapter used while the new system runs in shadow mode. It reads
## public identity/time data only; task-specific facts will be added with their
## owning mechanics instead of mirroring SettlementGame's private API.

var simulation: Node


func _init(next_simulation: Node = null) -> void:
	simulation = next_simulation


func capture(sequence: int) -> WorldSnapshot:
	if not is_instance_valid(simulation):
		return WorldSnapshot.new(sequence)
	var citizens_by_id: Dictionary = {}
	for actor: Citizen in simulation.citizens:
		if not is_instance_valid(actor) or actor.ai_id == 0:
			continue
		var citizen_id := actor.ai_id
		citizens_by_id[citizen_id] = CitizenSnapshot.new(
			citizen_id,
			actor.global_position,
			actor.is_player_controlled,
			not actor.is_player_controlled,
			AIFactSet.new({&"hero": actor.is_hero})
		)
	var settlement_facts := AIFactSet.new({
		&"population": citizens_by_id.size(),
		&"era": simulation.settlement.era,
	})
	return WorldSnapshot.new(
		sequence,
		simulation.runtime_seconds,
		simulation.game_minutes,
		settlement_facts,
		citizens_by_id
	)
