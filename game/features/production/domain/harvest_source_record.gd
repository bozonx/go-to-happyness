class_name HarvestSourceRecord
extends RefCounted

## Runtime state of one depleting natural source: a grass tuft, a bush.
##
## The record is deliberately resource-agnostic. What comes out of the source is
## decided by the collection it lives in, not by a field here — a bush is not a
## grass tuft with `resource = "branches"`, it is a different stand of objects
## that happens to deplete by the same rule. Keeping the rule in one class is what
## stops "count down, free the node at zero" from being written twice.

var node: Node3D = null
var remaining: int = 0
var initial: int = 0


func _init(
	next_node: Node3D = null,
	next_remaining: int = 0,
	next_initial: int = 0,
) -> void:
	node = next_node
	remaining = next_remaining
	initial = next_initial


func is_spent() -> bool:
	return remaining <= 0


## Takes one unit and frees the visual when the source runs out. Returns how much
## was actually taken, which is 0 for an exhausted source.
func take_one() -> int:
	if remaining <= 0:
		return 0
	remaining = maxi(0, remaining - 1)
	if remaining == 0 and is_instance_valid(node):
		node.queue_free()
	return 1
