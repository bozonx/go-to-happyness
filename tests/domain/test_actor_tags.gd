class_name TestActorTags
extends RefCounted

## Domain tests for the citizen tag issuer (active_zones.md §12): that every
## citizen is a `visitor`, that employment adds `staff`, that the construction
## role adds `builder`, and that `owner`/`vehicle` are never part of the static
## set (owner is relational, vehicle is a different entity).


static func run_all() -> void:
	_test_unemployed_citizen_is_visitor_only()
	_test_employed_citizen_is_staff()
	_test_construction_role_adds_builder()
	_test_owner_and_vehicle_never_in_static_set()
	_test_null_citizen_is_visitor_only()
	print("    [PASS] Actor Tags Tests")


## An unregistered citizen carries only the default `visitor` audience.
static func _test_unemployed_citizen_is_visitor_only() -> void:
	var citizen := Citizen.new()
	citizen.employment_state = CitizenEmploymentState.EmploymentState.UNREGISTERED
	var tags := ActorTags.of(citizen)
	assert(tags == [ZoneAccess.AUDIENCE_VISITOR], "unemployed: visitor only: %s" % str(tags))


## A permanently employed citizen is `staff` as well as `visitor`.
static func _test_employed_citizen_is_staff() -> void:
	var citizen := Citizen.new()
	citizen.employment_state = CitizenEmploymentState.EmploymentState.EMPLOYED
	# A non-construction permanent role so `builder` does not sneak in.
	citizen.permanent_role = "cook"
	var tags := ActorTags.of(citizen)
	assert(ZoneAccess.AUDIENCE_VISITOR in tags)
	assert(ZoneAccess.AUDIENCE_STAFF in tags)
	assert(ZoneAccess.AUDIENCE_BUILDER not in tags, "cook is not a builder")


## A citizen with the construction role (permanent or daily order) is a builder.
static func _test_construction_role_adds_builder() -> void:
	var employed := Citizen.new()
	employed.employment_state = CitizenEmploymentState.EmploymentState.EMPLOYED
	employed.permanent_role = "construction"
	var tags := ActorTags.of(employed)
	assert(ZoneAccess.AUDIENCE_BUILDER in tags, "permanent construction = builder")
	# A daily construction order also counts, even from an otherwise unassigned citizen.
	var daily := Citizen.new()
	daily.employment_state = CitizenEmploymentState.EmploymentState.NO_PERMANENT_WORK
	daily.daily_order_role = "construction"
	var daily_tags := ActorTags.of(daily)
	assert(ZoneAccess.AUDIENCE_BUILDER in daily_tags, "daily construction order = builder")


## The static set never contains `owner` (relational, appended at query time) or
## `vehicle` (a different acting entity, not a role a person holds).
static func _test_owner_and_vehicle_never_in_static_set() -> void:
	var citizen := Citizen.new()
	citizen.employment_state = CitizenEmploymentState.EmploymentState.EMPLOYED
	citizen.permanent_role = "construction"
	var tags := ActorTags.of(citizen)
	assert(ZoneAccess.AUDIENCE_OWNER not in tags, "owner is relational, never static")
	assert(ZoneAccess.AUDIENCE_VEHICLE not in tags, "a citizen is never a vehicle")


## A null reference degrades gracefully to visitor-only rather than crashing —
## the tag issuer is called from the per-tick presence loop.
static func _test_null_citizen_is_visitor_only() -> void:
	var tags := ActorTags.of(null)
	assert(tags == [ZoneAccess.AUDIENCE_VISITOR], "null: visitor only: %s" % str(tags))
