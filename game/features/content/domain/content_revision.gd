class_name ContentRevision
extends RefCounted

## Save stamp shared by every authored content file — blueprints, maps, prefabs
## (design_docs/engine/content_packaging.md §7).
##
## A revision answers one question: "is this the same file I loaded?". It is a
## stamp written on save, not a hash of the content: hashing a quarter-megabyte
## map package on every save would answer that no faster, and two formats that
## answer the same question must answer it the same way.


## Short, sortable, and unique enough to tell two saves apart.
static func new_stamp() -> String:
	return "%x%04x" % [Time.get_unix_time_from_system(), randi() % 0x10000]
