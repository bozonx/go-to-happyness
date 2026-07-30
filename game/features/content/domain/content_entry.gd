class_name ContentEntry
extends RefCounted

## One immutable-ish index row. `metadata` retains format-specific header data
## without making the cross-feature index own either format's full model.
var source: StringName
var id: StringName
var runtime_key: StringName
var content_type: StringName
var kind: StringName
var role: StringName
var style: StringName
var variant: StringName
var path: String
var name: String
var metadata: Dictionary

func _init(p_source: StringName = &"", p_id: StringName = &"", p_type: StringName = &"", p_path: String = "") -> void:
	source = p_source
	id = p_id
	content_type = p_type
	path = p_path

func to_dict() -> Dictionary:
	return {"source": source, "id": id, "key": runtime_key, "content_type": content_type,
		"kind": kind, "role": role, "style": style, "variant": variant, "path": path,
		"name": name, "metadata": metadata.duplicate(true)}
