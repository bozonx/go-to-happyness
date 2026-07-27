class_name ContentId
extends RefCounted

## Stable runtime addressing. `builtin` and `player` are accepted only when
## reading pre-pack saves and resolve to their pack-era equivalents.
const SOURCE_CORE := &"core"
const SOURCE_LOCAL := &"local"
const SOURCE_INSTALLED := &"installed"
const SOURCE_BUILTIN := &"builtin" # legacy alias
const SOURCE_PLAYER := &"player" # legacy alias
const CORE_PREFIX := "core:"
const USER_PREFIX := "user:"
const PACK_PREFIX := "pack:"

## The one alphabet an authored id may use (content_packaging.md §3.3). Both
## formats obey it because both turn an id into a file or folder name, and into a
## reference stored in save files and `.gdpack` archives.
##
## There is deliberately no transliteration: a table would turn `Пекарня` into
## `pekarnya`, which looks like a slug without being one, and that string would
## then reach a filename and a save reference where only a migration could fix it.
## Stripping is honest — the author sees immediately what survived.


## Whether `value` may be stored as an id. Empty is invalid: a file needs a name.
static func is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for i in value.length():
		if not _is_id_char(value[i]):
			return false
	return true


## Character-level reduction of free input to the alphabet: spaces become `_`, case
## is folded, everything else is dropped.
##
## This is the **live** form, for cleaning a field as the author types, and it
## deliberately keeps separators wherever they land. Trimming them here would make
## the field impossible to type in: half-way through `my_bakery` the text is
## `my_`, and eating that underscore would swallow every one the author tries.
##
## The result may be empty — that is a valid answer meaning "nothing usable was
## typed", and callers must report it rather than substitute a placeholder name.
static func sanitize_id(value: String) -> String:
	var lowered := value.strip_edges().to_lower()
	var safe := ""
	for i in lowered.length():
		var character := lowered[i]
		if _is_id_char(character):
			safe += character
		elif character == " ":
			safe += "_"
	return safe


## The **committed** form: what an id becomes when it is finally used as a file or
## folder name. Separators are trimmed from both ends because there they are
## artefacts of what was stripped rather than anything the author meant —
## `Проба-Map 7` sanitizes to `-map_7`, and a folder starting with `-` reads as a
## command-line flag to every tool that later touches it.
static func normalize_id(value: String) -> String:
	var safe := sanitize_id(value)
	var start := 0
	var end := safe.length()
	while start < end and _is_separator(safe[start]):
		start += 1
	while end > start and _is_separator(safe[end - 1]):
		end -= 1
	return safe.substr(start, end - start)


static func _is_separator(character: String) -> bool:
	return character == "_" or character == "-"


static func _is_id_char(character: String) -> bool:
	return (character >= "a" and character <= "z") \
		or (character >= "0" and character <= "9") \
		or character == "_" or character == "-"

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
			# Keep the source in the same canonical form `runtime_key()` accepts.
			# Without the prefix this was not a round trip: splitting and joining an
			# installed reference changed `pack:author.id/foo` to `author.id:foo`.
			return {"source": StringName(PACK_PREFIX + body.left(separator)), "id": StringName(body.substr(separator + 1))}
	var colon := text.find(":")
	if colon > 0:
		return {"source": StringName(text.left(colon)), "id": StringName(text.substr(colon + 1))}
	return {"source": StringName(), "id": StringName()}
