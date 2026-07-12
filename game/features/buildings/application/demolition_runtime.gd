class_name DemolitionRuntime
extends RefCounted

## Narrow integration boundary for demolition progress. Settlement-specific
## relocation, refunds and visual cleanup remain explicit callbacks.

var duration := 3.0
var building_power: Callable
var is_ready: Callable
var completed: Callable
