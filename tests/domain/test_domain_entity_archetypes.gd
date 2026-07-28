class_name TestDomainEntityArchetypes
extends RefCounted

## Archetypes, their property schema and their state dictionary
## (design_docs/engine/map_fill_mode.md §4, §6, §7).
##
## Three claims carry the format and are asserted here rather than assumed.
##
## First: **a placed record stores only the author's differences.** A full snapshot
## would mean that editing a default in the pack never reaches the thirty thousand
## trees already on the map — and that is not a bug anyone finds, it is a bug
## everyone works around.
##
## Second: **the runtime owns state transitions.** The default start is "follow the
## season", so a forest planted in summer is not still green in January.
##
## Third: **nothing here knows a component by name.** The archetype carries them as
## opaque data, which is the test that a new genre module gets an editor for free.


static func run_all() -> void:
	_test_archetype_round_trips_through_json()
	_test_unknown_enums_fall_back_instead_of_failing()
	_test_components_stay_opaque_data()
	print("    [PASS] Entity Archetype Format Tests")
	_test_only_authored_differences_are_stored()
	_test_property_schema_validity_and_visibility()
	print("    [PASS] Entity Property Schema Tests")
	_test_states_default_to_following_the_season()
	_test_state_transitions_resolve_declared_states_only()
	print("    [PASS] Entity State Tests")
	_test_core_pack_archetypes_load()
	print("    [PASS] Entity Archetype Catalog Tests")


# --- Format -------------------------------------------------------------------

static func _test_archetype_round_trips_through_json() -> void:
	var archetype := _spruce()
	var restored := EntityArchetype.from_json(archetype.to_json())
	assert(restored != null)
	assert(restored.id == &"spruce")
	assert(restored.name == "Ель")
	assert(restored.asset_id == &"spruce_tall")
	assert(restored.content_class == EntityArchetype.CLASS_OBJECT)
	assert(restored.activity == EntityArchetype.ACTIVITY_DISTANCE)
	assert(restored.tags == archetype.tags)
	assert(restored.property_schema.size() == archetype.property_schema.size())
	assert(restored.states.state_ids() == archetype.states.state_ids())
	# Component data is opaque, so it survives as JSON gave it: a number comes back
	# as a float. Nothing here is allowed to "fix" that, because fixing it would
	# mean this class understanding what a component's fields mean.
	assert(restored.component_names() == archetype.component_names())
	assert(float(restored.component_data(&"harvestable")["wood"]) == 8.0)
	# What has to hold instead is idempotency: a file written by the editor and read
	# back must produce the same file, or every save would churn the pack in git.
	assert(EntityArchetype.from_json(restored.to_json()).to_dict() == restored.to_dict())
	# A property declared `int` still comes back as an int, though JSON has no ints.
	var yield_default: Variant = restored.default_properties()[&"wood_yield"]
	assert(typeof(yield_default) == TYPE_INT and yield_default == 8)

	# An archetype without an id is not an archetype: nothing could reference it.
	assert(EntityArchetype.from_json('{"name": "Безымянный"}') == null)
	assert(EntityArchetype.from_json("not json at all") == null)


static func _test_unknown_enums_fall_back_instead_of_failing() -> void:
	var restored := EntityArchetype.from_dict({
		"id": "mystery",
		"content_class": "hologram",
		"activity": "whenever",
		"properties": [
			{"name": "ok", "type": "int", "section": "gameplay"},
			{"name": "bad_type", "type": "quaternion", "section": "gameplay"},
			{"name": "bad_section", "type": "int", "section": "nowhere"},
			{"type": "int", "section": "gameplay"},
			{"name": "ok", "type": "float", "section": "gameplay"},
		],
	})
	assert(restored.content_class == EntityArchetype.CLASS_OBJECT)
	assert(restored.activity == EntityArchetype.ACTIVITY_DISTANCE)
	# A field the inspector cannot draw is dropped, not half-rendered; and a
	# duplicate name would make the second control write over the first.
	assert(restored.property_schema.size() == 1)
	assert(restored.property_schema[0].name == &"ok")
	assert(restored.property_schema[0].type == EntityPropertyDef.TYPE_INT)


static func _test_components_stay_opaque_data() -> void:
	var archetype := _spruce()
	assert(archetype.has_component(&"harvestable"))
	assert(not archetype.has_component(&"teleporter"))
	assert(int(archetype.component_data(&"harvestable")["wood"]) == 8)
	assert(archetype.component_data(&"teleporter").is_empty())
	var expected_names: Array[StringName] = [&"growth", &"harvestable"]
	assert(archetype.component_names() == expected_names)


# --- Property schema ----------------------------------------------------------

static func _test_only_authored_differences_are_stored() -> void:
	var archetype := _spruce()
	assert(archetype.default_properties() == {&"wood_yield": 8, &"renewable": true})

	# A value equal to the default is not a difference, so it is not written.
	assert(archetype.authored_differences({&"wood_yield": 8}).is_empty())
	assert(archetype.authored_differences({&"wood_yield": 12}) == {&"wood_yield": 12})
	# A property the schema does not declare has nowhere to be applied and is
	# dropped rather than stored as a value nothing will ever read.
	assert(archetype.authored_differences({&"invented": 1}).is_empty())
	# Out-of-range input is clamped where it is stored, not where it is read.
	assert(archetype.authored_differences({&"wood_yield": 500}) == {&"wood_yield": 50})

	var resolved := archetype.resolved_properties({&"wood_yield": 12})
	assert(resolved == {&"wood_yield": 12, &"renewable": true})
	# Raising the pack default must reach records that never overrode it.
	archetype.get_property(&"wood_yield").default = 10
	assert(archetype.resolved_properties({})[&"wood_yield"] == 10)


static func _test_property_schema_validity_and_visibility() -> void:
	var conditional := EntityPropertyDef.from_dict({
		"name": "regrow_days", "label": "Отрастает за", "type": "int",
		"section": "gameplay", "visible_if": {"prop": "renewable", "eq": true},
	})
	assert(conditional.is_valid())
	assert(conditional.is_visible_for({&"renewable": true}))
	assert(not conditional.is_visible_for({&"renewable": false}))
	# The controlling property missing means the field stays hidden: it depends on
	# something the author has not decided yet.
	assert(not conditional.is_visible_for({}))

	var route := EntityPropertyDef.from_dict({
		"name": "patrol_route", "label": "Маршрут", "type": "route_ref",
		"section": "behavior", "pick_on_map": true,
	})
	assert(route.is_reference())
	assert(route.pick_on_map)
	assert(route.to_dict()["pick_on_map"] == true)
	assert(not EntityPropertyDef.from_dict({"name": "x", "type": "int"}).is_reference())

	var nested := EntityPropertyDef.from_dict({
		"name": "schedule", "type": "list", "section": "behavior",
		"entries": [
			{"name": "at", "type": "int", "section": "behavior"},
			{"name": "broken", "type": "wormhole", "section": "behavior"},
		],
	})
	assert(nested.entries.size() == 1)
	assert(nested.entries[0].name == &"at")


# --- States -------------------------------------------------------------------

static func _test_states_default_to_following_the_season() -> void:
	var seasonal := _spruce().states
	assert(seasonal.default_state == EntityStateSet.FOLLOW_SEASON)
	assert(seasonal.has_state(&"summer"))
	assert(not seasonal.has_state(&"molten"))
	assert(seasonal.allows_initial_state(EntityStateSet.FOLLOW_SEASON))
	assert(seasonal.allows_initial_state(&"stump"))
	assert(not seasonal.allows_initial_state(&"molten"))
	assert(seasonal.get_state(&"stump").has_flag(EntityStateDef.FLAG_HARVESTED))
	assert(seasonal.get_state(&"stump").visual_kind == EntityStateDef.VISUAL_SCENE)
	assert(seasonal.get_state(&"summer").visual_kind == EntityStateDef.VISUAL_VARIANT)

	# A default naming a state the archetype does not declare would pin every
	# placed object to nothing; following the season keeps the map alive.
	var broken := EntityStateSet.from_dict({
		"default": "molten",
		"list": [{"id": "summer", "name": "Лето"}],
	})
	assert(broken.default_state == EntityStateSet.FOLLOW_SEASON)
	# An archetype with no states still follows the season.
	var none := EntityStateSet.from_dict({})
	assert(none.is_empty())
	assert(none.allows_initial_state(EntityStateSet.FOLLOW_SEASON))


static func _test_state_transitions_resolve_declared_states_only() -> void:
	var states := _spruce().states
	assert(states.state_for(&"season", &"winter") == &"snowy")
	assert(states.state_for(&"season", &"summer") == &"summer")
	# An axis or a value with no mapping resolves to nothing rather than to the
	# first state in the list.
	assert(states.state_for(&"season", &"eclipse") == &"")
	assert(states.state_for(&"mood", &"winter") == &"")

	var dangling := EntityStateSet.from_dict({
		"list": [{"id": "summer", "name": "Лето"}],
		"transitions": {"season": {"winter": "snowy"}},
	})
	assert(dangling.state_for(&"season", &"winter") == &"")


# --- Catalog ------------------------------------------------------------------

static func _test_core_pack_archetypes_load() -> void:
	EntityArchetypeCatalog.reload()
	assert(EntityArchetypeCatalog.load_errors.is_empty())
	assert(EntityArchetypeCatalog.has_archetype(&"core:campfire"))
	# Ids are namespaced by pack, so two packs may ship the same local name.
	assert(not EntityArchetypeCatalog.has_archetype(&"campfire"))
	assert(EntityArchetypeCatalog.pack_of(&"core:campfire") == &"core")

	var campfire := EntityArchetypeCatalog.get_archetype(&"core:campfire")
	assert(campfire.states.default_state == &"lit")
	assert(campfire.states.has_state(&"embers"))
	assert(campfire.get_property(&"relight_minutes") != null)
	assert(not campfire.get_property(&"relight_minutes").is_visible_for({&"relights": false}))
	# Every core archetype resolves to a real asset in the shared library.
	for archetype: EntityArchetype in EntityArchetypeCatalog.all():
		assert(EntityArchetypeCatalog.asset_of(archetype.id) != null)

	assert(not EntityArchetypeCatalog.of_class(EntityArchetype.CLASS_OBJECT).is_empty())
	assert(not EntityArchetypeCatalog.of_class(EntityArchetype.CLASS_DECOR).is_empty())
	assert(EntityArchetypeCatalog.of_class(EntityArchetype.CLASS_ACTOR).is_empty())
	assert(not EntityArchetypeCatalog.of_tag(&"fire").is_empty())
	# An unknown archetype is not an error, it is simply absent (§11).
	assert(EntityArchetypeCatalog.get_archetype(&"core:nothing") == null)
	assert(EntityArchetypeCatalog.asset_of(&"core:nothing") == null)


# --- Fixture ------------------------------------------------------------------

## The worked example of §6.1 and §7.1: a seasonal, fellable tree. It is used by
## most assertions above because it is the case the format was designed around.
static func _spruce() -> EntityArchetype:
	var archetype := EntityArchetype.create(&"spruce", "Ель", &"spruce_tall")
	archetype.category = &"vegetation"
	archetype.tags = [&"tree", &"wood"]
	archetype.components = {
		"harvestable": {"wood": 8, "tool": "axe"},
		"growth": {"stages": 3},
	}
	archetype.property_schema = [
		EntityPropertyDef.from_dict({
			"name": "wood_yield", "label": "Древесины", "type": "int",
			"min": 1, "max": 50, "default": 8, "section": "gameplay", "unit": "ед.",
		}),
		EntityPropertyDef.from_dict({
			"name": "renewable", "label": "Отрастает", "type": "bool",
			"default": true, "section": "gameplay",
		}),
	]
	archetype.states = EntityStateSet.from_dict({
		"default": "seasonal",
		"list": [
			{"id": "summer", "name": "Лето", "visual": {"variant": "foliage_green"}},
			{"id": "autumn", "name": "Осень", "visual": {"variant": "foliage_gold"}},
			{"id": "snowy", "name": "Заснеженное", "visual": {"variant": "foliage_snow"}},
			{
				"id": "stump", "name": "Пень", "visual": {"scene": "tree_stump.tscn"},
				"flags": ["harvested", "no_collision"],
			},
		],
		"transitions": {
			"season": {
				"spring": "summer", "summer": "summer",
				"autumn": "autumn", "winter": "snowy",
			},
		},
	})
	return archetype
