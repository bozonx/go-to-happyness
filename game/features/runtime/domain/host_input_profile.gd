class_name HostInputProfile
extends RefCounted

## Input profiles are part of a game definition, but their actions remain owned
## by the host. Packs choose a registered profile; they do not bind arbitrary
## engine shortcuts themselves.

const RTS: StringName = &"rts"


static func is_supported(profile_id: StringName) -> bool:
	return profile_id == RTS
