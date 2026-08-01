class_name CoverageNavigationPublisher
extends RefCounted

## Keeps routing's view of built coverage equal to the map's coverage layer
## (map_editor.md §5.2.3).
##
## This is the one place the authored layer meets the runtime owner. The rule it
## implements is the whole reason it exists: **the map seeds the service at load,
## and from then on `RoadNetworkService` is the write-owner of road weights in the
## session.** Before this, `surface.bin` and the save's `roads` list described the
## same cells with no rule about which won.
##
## In the editor there is no settlement and no construction, so the publisher
## follows every committed edit directly — an author who paints a path has to see
## the route prefer it on the next frame, not after a reload.

var layer: CoverageLayer = null
var road_network: RoadNetworkService = null


## Binds the layer to the service and publishes it once. Pass the editing service
## to keep them equal: every committed stroke republishes.
func configure(next_layer: CoverageLayer, next_road_network: RoadNetworkService, service: CoverageService = null) -> void:
	layer = next_layer
	road_network = next_road_network
	publish_all()
	if service != null and not service.edit_committed.is_connected(_on_edit_committed):
		service.edit_committed.connect(_on_edit_committed)


## Replaces the service's coverage with the layer's, wholesale. The service
## already publishes to `NavGrid` in one transaction, so a repaint of the whole
## board still bumps the grid's revisions exactly once.
func publish_all() -> void:
	if layer == null or road_network == null:
		return
	var roads: Dictionary = {}
	for cell: Vector2i in layer.covered_cells():
		var id := CoverageCatalog.id_of_index(layer.index_at(cell))
		if id != CoverageCatalog.NONE_ID:
			roads[cell] = id
	road_network.restore_completed_roads(roads)


func _on_edit_committed(_delta: CoverageDelta) -> void:
	publish_all()
