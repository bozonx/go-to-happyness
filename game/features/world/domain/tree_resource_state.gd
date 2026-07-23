class_name TreeResourceState
extends RefCounted

## Mutable, presentation-free state for one tree at a stable board cell.

var initial_wood: int
var remaining_wood: int
var initial_branches: int
var remaining_branches: int
var hand_branches: int = 0
var felled: bool = false
var branch_exhausted: bool = false


func _init(wood: int = 0, branches: int = 0) -> void:
	initial_wood = wood
	remaining_wood = wood
	initial_branches = branches
	remaining_branches = branches
