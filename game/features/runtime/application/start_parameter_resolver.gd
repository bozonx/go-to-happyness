class_name StartParameterResolver
extends RefCounted

## The one implementation of the §2.5 chain (design_docs/engine/map_start.md).
##
## ```
## 1 module default → 2 game definition → 3 map → 4 start option → 5 player
## ```
##
## Every screen that shows a start parameter — the launch menu, the game editor,
## the map editor's «Ограничения» — resolves through this, so "definition 1…24 →
## map 2…8 → option 2 → player 3" has exactly one answer and one explanation.
## Level 6, the scenario, is not here on purpose: after the session exists the
## value is module state, not a parameter.
##
## A `restrict` may only narrow. Intersecting rather than replacing is what makes
## the guarantee in §2.3 real — a map cannot hand the player a population the
## module never agreed to simulate — and an empty intersection is an error rather
## than a silently clamped value, because there is no honest number to pick.

## `declared` — `module_id -> Array[EntityPropertyDef]`, level 1.
## `definition_values` — `start.modules` of the game definition, level 2.
## `map_sections` / `option_sections` — `module_id -> ModuleSettingsSection`.
## `player_values` — `module_id -> {parameter: value}`, level 5.
static func resolve(
	declared: Dictionary,
	definition_values: Dictionary,
	map_sections: Dictionary,
	option_sections: Dictionary,
	player_values: Dictionary,
) -> StartParameterResolution:
	var resolution := StartParameterResolution.new()
	for module_id: Variant in declared:
		var module_key := StringName(module_id)
		var properties: Array[EntityPropertyDef] = declared[module_id]
		var module_values: Dictionary = {}
		var module_entries: Dictionary = {}
		for property: EntityPropertyDef in properties:
			var entry := _resolve_one(
				module_key,
				property,
				_section_of(definition_values, module_key),
				map_sections.get(module_key, null),
				option_sections.get(module_key, null),
				_section_of(player_values, module_key),
				resolution.errors,
			)
			module_values[property.name] = entry.value
			module_entries[property.name] = entry
		# A key nobody declared is carried through untouched: the module that owns
		# it may simply not be installed in this build (`content_packaging.md`).
		_carry_undeclared(module_values, _section_of(definition_values, module_key))
		var map_section: ModuleSettingsSection = map_sections.get(module_key, null)
		if map_section != null:
			_carry_undeclared(module_values, map_section.values)
		var option_section: ModuleSettingsSection = option_sections.get(module_key, null)
		if option_section != null:
			_carry_undeclared(module_values, option_section.values)
		resolution.values[module_key] = module_values
		resolution.provenance[module_key] = module_entries
	# Settings addressed to a module this build never loaded still have to reach
	# the session: dropping them here is how a map quietly loses another pack's
	# configuration on the first save.
	for module_id: Variant in _undeclared_modules(declared, definition_values, map_sections, option_sections, player_values):
		var carried: Dictionary = {}
		_carry_undeclared(carried, _section_of(definition_values, module_id))
		var section: ModuleSettingsSection = map_sections.get(module_id, null)
		if section != null:
			_carry_undeclared(carried, section.values)
		var option: ModuleSettingsSection = option_sections.get(module_id, null)
		if option != null:
			_carry_undeclared(carried, option.values)
		_carry_undeclared(carried, _section_of(player_values, module_id))
		resolution.values[StringName(module_id)] = carried
	return resolution


static func _resolve_one(
	module_id: StringName,
	property: EntityPropertyDef,
	definition_values: Dictionary,
	map_section: ModuleSettingsSection,
	option_section: ModuleSettingsSection,
	player_values: Dictionary,
	errors: Array[String],
) -> StartParameterResolution.Entry:
	var entry := StartParameterResolution.Entry.new()
	entry.parameter = property.name
	entry.label = property.label
	entry.minimum = property.minimum
	entry.maximum = property.maximum
	entry.options = property.options.duplicate()
	entry.offered_to_player = property.visibility == EntityPropertyDef.VISIBILITY_PLAYER

	# Level 3 and 4 narrow before anything is clamped, so a value proposed by the
	# definition lands inside the map's range rather than outside it.
	if map_section != null:
		_narrow(entry, map_section.restriction_for(property.name), StartParameterResolution.LEVEL_MAP, module_id, property, errors)
		if map_section.locks(property.name):
			entry.locked_by = StartParameterResolution.LEVEL_MAP
	if option_section != null:
		_narrow(entry, option_section.restriction_for(property.name), StartParameterResolution.LEVEL_START_OPTION, module_id, property, errors)
		if option_section.locks(property.name):
			entry.locked_by = StartParameterResolution.LEVEL_START_OPTION

	entry.value = _clamped(property, entry, property.default)
	entry.level = StartParameterResolution.LEVEL_MODULE
	entry.proposals[StartParameterResolution.LEVEL_MODULE] = entry.value

	var fixed := property.override_policy == EntityPropertyDef.OVERRIDE_FIXED
	var restrict_only := property.override_policy == EntityPropertyDef.OVERRIDE_RESTRICT_ONLY
	_apply_level(entry, property, definition_values.get(String(property.name), definition_values.get(property.name, null)),
		StartParameterResolution.LEVEL_DEFINITION, not fixed)
	if map_section != null and map_section.has_value(property.name):
		_apply_level(entry, property, map_section.value_of(property.name),
			StartParameterResolution.LEVEL_MAP, not fixed and not restrict_only)
	if option_section != null and option_section.has_value(property.name):
		_apply_level(entry, property, option_section.value_of(property.name),
			StartParameterResolution.LEVEL_START_OPTION, not fixed and not restrict_only)
	var chosen: Variant = player_values.get(String(property.name), player_values.get(property.name, null))
	if chosen != null:
		_apply_level(entry, property, chosen, StartParameterResolution.LEVEL_PLAYER, entry.is_player_choice())

	if property.required and entry.level == StartParameterResolution.LEVEL_MODULE and property.default == null:
		errors.append("%s: параметр %s обязателен и не получил значения" % [module_id, property.name])
	return entry


## Records what a level proposed and, when that level is allowed to speak, makes
## it the answer. A refused proposal is still recorded: "the map asked for 500
## but the module owns this value" is the message an author needs, and dropping
## the proposal would make the field look like it was never authored.
static func _apply_level(
	entry: StartParameterResolution.Entry,
	property: EntityPropertyDef,
	proposed: Variant,
	level: int,
	allowed: bool,
) -> void:
	if proposed == null:
		return
	var clamped: Variant = _clamped(property, entry, proposed)
	entry.proposals[level] = clamped
	if not allowed:
		return
	entry.value = clamped
	entry.level = level


static func _narrow(
	entry: StartParameterResolution.Entry,
	restriction: Dictionary,
	level: int,
	module_id: StringName,
	property: EntityPropertyDef,
	errors: Array[String],
) -> void:
	if restriction.is_empty():
		return
	var narrowed := false
	if restriction.has("min"):
		var proposed_min: Variant = property.coerce_value(restriction["min"])
		entry.minimum = proposed_min if entry.minimum == null else maxf(float(entry.minimum), float(proposed_min))
		if property.type == EntityPropertyDef.TYPE_INT:
			entry.minimum = int(entry.minimum)
		narrowed = true
	if restriction.has("max"):
		var proposed_max: Variant = property.coerce_value(restriction["max"])
		entry.maximum = proposed_max if entry.maximum == null else minf(float(entry.maximum), float(proposed_max))
		if property.type == EntityPropertyDef.TYPE_INT:
			entry.maximum = int(entry.maximum)
		narrowed = true
	if restriction.get("options") is Array:
		var allowed: Array = restriction["options"] as Array
		var intersection: Array = []
		for option: Variant in entry.options:
			for candidate: Variant in allowed:
				if String(candidate) == String(option):
					intersection.append(option)
					break
		# An option list the module never declared cannot be honoured: the module
		# would receive a state it has no branch for.
		entry.options = intersection if not entry.options.is_empty() else []
		narrowed = true
		if entry.options.is_empty() and not allowed.is_empty():
			errors.append("%s: %s — ни один разрешённый вариант не объявлен модулем" % [module_id, property.name])
	if narrowed:
		entry.restricted_by = level
	if entry.minimum != null and entry.maximum != null and float(entry.minimum) > float(entry.maximum):
		errors.append("%s: %s — ограничение карты не пересекается с диапазоном модуля" % [module_id, property.name])


## Coercion plus the *narrowed* range, which is why this is not `property.clamp_value`:
## the property still carries the module's range, and the entry carries the
## intersection every level agreed on.
static func _clamped(property: EntityPropertyDef, entry: StartParameterResolution.Entry, value: Variant) -> Variant:
	var coerced: Variant = property.coerce_value(value)
	if coerced == null:
		return null
	match property.type:
		EntityPropertyDef.TYPE_INT:
			var as_int := int(coerced)
			if entry.minimum != null:
				as_int = maxi(as_int, int(entry.minimum))
			if entry.maximum != null:
				as_int = mini(as_int, int(entry.maximum))
			return as_int
		EntityPropertyDef.TYPE_FLOAT:
			var as_float := float(coerced)
			if entry.minimum != null:
				as_float = maxf(as_float, float(entry.minimum))
			if entry.maximum != null:
				as_float = minf(as_float, float(entry.maximum))
			return as_float
		EntityPropertyDef.TYPE_ENUM:
			if entry.options.is_empty():
				return coerced
			for option: Variant in entry.options:
				if String(option) == String(coerced):
					return coerced
			return property.default
	return coerced


static func _section_of(source: Dictionary, module_id: Variant) -> Dictionary:
	var value: Variant = source.get(module_id, source.get(String(module_id), {}))
	return value as Dictionary if value is Dictionary else {}


static func _carry_undeclared(target: Dictionary, supplied: Dictionary) -> void:
	for key: Variant in supplied:
		if not target.has(StringName(key)):
			target[StringName(key)] = supplied[key]


static func _undeclared_modules(
	declared: Dictionary,
	definition_values: Dictionary,
	map_sections: Dictionary,
	option_sections: Dictionary,
	player_values: Dictionary,
) -> Array[StringName]:
	var seen: Dictionary = {}
	for source: Dictionary in [definition_values, map_sections, option_sections, player_values]:
		for module_id: Variant in source:
			var key := StringName(module_id)
			if not declared.has(key) and not seen.has(key):
				seen[key] = true
	var result: Array[StringName] = []
	for key: Variant in seen:
		result.append(key)
	return result
