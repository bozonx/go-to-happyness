class_name DemolitionService
extends RefCounted

var runtime: DemolitionRuntime
var sites: Array[DemolitionSite] = []


func configure(next_runtime: DemolitionRuntime) -> void:
	runtime = next_runtime


func mark(building: Node3D, building_type: String) -> bool:
	if not is_instance_valid(building) or has_site(building):
		return false
	sites.append(DemolitionSite.new(building, building_type))
	return true


func has_site(building: Node3D) -> bool:
	for site in sites:
		if site.building == building:
			return true
	return false


func tick(delta: float) -> void:
	for index in range(sites.size() - 1, -1, -1):
		var site := sites[index]
		if not is_instance_valid(site.building):
			sites.remove_at(index)
			continue
		if not runtime.is_ready.call(site):
			continue
		var power: float = runtime.building_power.call(site.building)
		if power <= 0.0:
			continue
		site.progress = minf(1.0, site.progress + delta * power / runtime.duration)
		if site.progress >= 1.0:
			runtime.completed.call(site)
			sites.remove_at(index)
