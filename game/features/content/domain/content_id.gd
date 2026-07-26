class_name ContentId
extends RefCounted

## Stable runtime addressing while phase 1 still uses the legacy folders.
const SOURCE_BUILTIN := &"builtin"
const SOURCE_PLAYER := &"player"
const USER_PREFIX := "user:"

static func runtime_key(source: StringName, id: StringName) -> StringName:
	return StringName(USER_PREFIX + String(id)) if source == SOURCE_PLAYER else id

static func split_runtime_key(key: StringName) -> Dictionary:
	var text := String(key)
	if text.begins_with(USER_PREFIX):
		return {"source": SOURCE_PLAYER, "id": StringName(text.trim_prefix(USER_PREFIX))}
	return {"source": SOURCE_BUILTIN, "id": key}
