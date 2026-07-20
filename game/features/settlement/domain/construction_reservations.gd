class_name ConstructionReservations
extends RefCounted

## Tracks resources reserved for active construction sites.
## Maps a stable site id to a Dictionary of resource_type -> reserved amount.
## These resources are still in a warehouse/backpack, but they cannot be spent
## elsewhere until delivered or the site is cancelled.

var _reservations: Dictionary = {}


func clear() -> void:
	_reservations.clear()


func is_empty() -> bool:
	return _reservations.is_empty()


func reserved_total(resource_type: String) -> int:
	var total := 0
	for site_id in _reservations:
		var site_reservations: Dictionary = _reservations[site_id]
		total += int(site_reservations.get(resource_type, 0))
	return total


func reserved_for_site(site_id: int, resource_type: String) -> int:
	var site: Dictionary = _reservations.get(site_id, {})
	return int(site.get(resource_type, 0))


## Reserves up to `available` units of `resource_type` for the given site.
## Returns how many units were actually reserved.
func reserve(site_id: int, resource_type: String, available: int) -> int:
	if available <= 0:
		return 0
	var site: Dictionary = _reservations.get(site_id, {})
	site[resource_type] = int(site.get(resource_type, 0)) + available
	_reservations[site_id] = site
	return available


func release(site_id: int, resource_type: String, amount: int) -> void:
	var site: Dictionary = _reservations.get(site_id, {})
	var current := int(site.get(resource_type, 0))
	var to_release := mini(amount, current)
	if to_release <= 0:
		return
	current -= to_release
	if current <= 0:
		site.erase(resource_type)
	else:
		site[resource_type] = current
	if site.is_empty():
		_reservations.erase(site_id)
	else:
		_reservations[site_id] = site


func release_site(site_id: int) -> void:
	_reservations.erase(site_id)
