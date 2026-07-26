class_name ContentId
extends RefCounted

## Stable runtime addressing.  `builtin` and `player` are accepted only when
## reading pre-pack saves and resolve to their pack-era equivalents.
const SOURCE_CORE := &"core"
const SOURCE_LOCAL := &"local"
const SOURCE_INSTALLED := &"installed"
const SOURCE_BUILTIN := &"builtin" # legacy alias
const SOURCE_PLAYER := &"player" # legacy alias
const CORE_PREFIX := "core:"
const USER_PREFIX := "user:"
const PACK_PREFIX := "pack:"

static func runtime_key(source: StringName, id: StringName) -> StringName:
	if source == SOURCE_LOCAL or source == SOURCE_PLAYER:
		return StringName(USER_PREFIX + String(id))
	if source == SOURCE_CORE or source == SOURCE_BUILTIN:
		return StringName(CORE_PREFIX + String(id))
	if String(source).begins_with(PACK_PREFIX):
		return StringName(String(source) + "/" + String(id))
	# Shipped packs are addressed by their own pack id (`style_roman:tent`).
	if source != SOURCE_INSTALLED:
		return StringName(String(source) + ":" + String(id))
	return StringName(PACK_PREFIX + String(source) + "/" + String(id))

static func split_runtime_key(key: StringName) -> Dictionary:
	var text := String(key)
	if text.begins_with(USER_PREFIX):
		return {"source": SOURCE_LOCAL, "id": StringName(text.trim_prefix(USER_PREFIX))}
	if text.begins_with(CORE_PREFIX):
		return {"source": SOURCE_CORE, "id": StringName(text.trim_prefix(CORE_PREFIX))}
	if text.begins_with(PACK_PREFIX):
		var body := text.trim_prefix(PACK_PREFIX)
		var separator := body.find("/")
		if separator > 0:
			return {"source": StringName(body.left(separator)), "id": StringName(body.substr(separator + 1))}
	var colon := text.find(":")
	if colon > 0:
		return {"source": StringName(text.left(colon)), "id": StringName(text.substr(colon + 1))}
	# Bare built-in ids were written by phase 1 saves.
	return {"source": SOURCE_CORE, "id": key}
