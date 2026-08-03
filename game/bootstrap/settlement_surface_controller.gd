class_name SettlementSurfaceController
extends RefCounted

## Surface state during play (design_docs/engine/terrain_materials.md §6.1, §6.4).
##
## Two services existed, were tested, and were wired to nothing: ground never wore
## down where citizens walked, and burned ground never grew back. This is the
## place they are driven from.
##
## **Wear reads the trail field's crossings, it does not count its own.** §6.1 is
## explicit that the visible worn path and the cheaply-routed path must be one
## counter — two would drift, and the player would see a bare track that routing
## thinks is meadow. `TrailFieldService` observes the crossing once and announces
## it; both consumers draw their own conclusion from the same event.
##
## Everything it writes goes through `TerrainService`, so a wear level and a
## regrown meadow are ordinary transactions: navigation hears about the new weight
## and the surface texel is updated, without either of them being told separately.

## How much burned ground recovers per simulated day. §6.4 wants this to come from
## the season curve's `growth_rate(day)`; seasons are a weather-side feature and
## are not built yet, so the rate is a constant here and the call site is already
## shaped to take the curve when it arrives.
const REGROWTH_RATE := 0.04

var wear := SurfaceWearService.new()
var regrowth := ScorchedRegrowthService.new()

var _trail_field: TrailFieldService = null


func configure(terrain_service: TerrainService, trail_field: TrailFieldService) -> void:
	wear.configure(terrain_service)
	regrowth.configure(terrain_service)
	if _trail_field != null and _trail_field.cell_entered.is_connected(_on_cell_entered):
		_trail_field.cell_entered.disconnect(_on_cell_entered)
	_trail_field = trail_field
	if _trail_field != null and not _trail_field.cell_entered.is_connected(_on_cell_entered):
		_trail_field.cell_entered.connect(_on_cell_entered)


## One simulation tick. `begin_tick` is what makes the throttle of §6.1 work: a
## cell gains at most one crossing per tick however many citizens are standing on
## it, so a crowd cannot flatten a meadow in a single frame.
func tick(day: int) -> void:
	wear.begin_tick()
	wear.flush(day)


## Once per simulated day, after the tick that ended it.
func advance_day(day: int) -> void:
	wear.recover(day)
	regrowth.regrow_day(day, REGROWTH_RATE)


func _on_cell_entered(cell: Vector2i) -> void:
	wear.record_crossing(cell)
