class_name ActorTags
extends RefCounted

## The tag set an acting entity carries, for the zone access model
## (design_docs/engine/active_zones.md §12).
##
## A permission check always gets the *full* tag set, never one "main" tag: a
## cook is at once a `visitor`, `staff` and `owner` of their rented kitchen, and
## which doors open is the union. The five engine-known audiences are derived
## here from employment state; pack tags (faction, species) are additive and do
## not exist yet — this issuer is the one place they will be appended when they
## arrive, so nothing downstream decides tags on its own.
##
## `visitor` is always present: everyone is a visitor by default, and a denial
## on `visitor` closes a cell to the public. `vehicle` is never returned for a
## citizen — a vehicle is a different acting entity, not a role a person holds.


static func of(citizen: Citizen) -> Array[StringName]:
	var tags: Array[StringName] = [ZoneAccess.AUDIENCE_VISITOR]
	if citizen == null:
		return tags
	# Staff: anyone with permanent employment. A denial on `staff` closes a cell
	# to the workforce while leaving it open to the public it serves. The Citizen
	# proxy exposes the enum value directly, so compare against the constant.
	if citizen.employment_state == CitizenEmploymentState.EmploymentState.EMPLOYED:
		tags.append(ZoneAccess.AUDIENCE_STAFF)
	# Builder: the construction role, whether permanent or a daily order. A
	# `deny builder` overlay is how a map marks "do not build here".
	if citizen.permanent_role == "construction" or citizen.daily_order_role == "construction":
		tags.append(ZoneAccess.AUDIENCE_BUILDER)
	# The `owner` audience is relational — it matches the zone's current owner
	# rather than a fixed tag — so it is NOT part of the static set. The access
	# check appends it at query time against the zone being asked about.
	return tags
