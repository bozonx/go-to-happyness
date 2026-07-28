class_name ZoneEventBus
extends RefCounted

## One bus for every zone event (active_zones.md §14).
##
## A deliberate mirror of `SimulationEventDispatcher`: a `RefCounted` callback
## table, owned by `SettlementGame`, configured once in the bootstrapper, driven
## from outside (the presence tracker, the registry) rather than from its own
## loop. The engine publishes only what it itself computes — presence — and the
## bus holds no knowledge of who listens or what an event means in play.
##
## Consumers do not exist yet (rules are a future phase). The bus is wired now so
## the tracker has somewhere to publish the moment it sees a citizen cross a
## region border, and a future rules layer subscribes by adding a callable here
## rather than inventing a second channel.

var area_entered_fn: Callable
var area_exited_fn: Callable
var slot_reserved_fn: Callable
var slot_released_fn: Callable
var owner_changed_fn: Callable
var zone_flag_changed_fn: Callable


func configure(callbacks: Dictionary) -> void:
	area_entered_fn = callbacks.get("area_entered", Callable())
	area_exited_fn = callbacks.get("area_exited", Callable())
	slot_reserved_fn = callbacks.get("slot_reserved", Callable())
	slot_released_fn = callbacks.get("slot_released", Callable())
	owner_changed_fn = callbacks.get("owner_changed", Callable())
	zone_flag_changed_fn = callbacks.get("zone_flag_changed", Callable())


func dispatch(event: ZoneEvent) -> void:
	match event.kind:
		ZoneEvent.Kind.AREA_ENTERED:
			if area_entered_fn.is_valid():
				area_entered_fn.call(event)
		ZoneEvent.Kind.AREA_EXITED:
			if area_exited_fn.is_valid():
				area_exited_fn.call(event)
		ZoneEvent.Kind.SLOT_RESERVED:
			if slot_reserved_fn.is_valid():
				slot_reserved_fn.call(event)
		ZoneEvent.Kind.SLOT_RELEASED:
			if slot_released_fn.is_valid():
				slot_released_fn.call(event)
		ZoneEvent.Kind.OWNER_CHANGED:
			if owner_changed_fn.is_valid():
				owner_changed_fn.call(event)
		ZoneEvent.Kind.ZONE_FLAG_CHANGED:
			if zone_flag_changed_fn.is_valid():
				zone_flag_changed_fn.call(event)
