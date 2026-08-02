class_name MapLocalizedText
extends RefCounted

## Reads the `{"ru": …, "en": …}` dictionaries an authored map carries
## (design_docs/engine/map_start.md §3.1).
##
## A map is an authored file with no string table of its own, and standing one up
## for two captions is not worth it; a pack that *does* have a table puts one
## entry in the dictionary with a key. One rule, one way to write it.
##
## A missing language falls back to the first one declared rather than to an
## empty string: a player who cannot read the caption is better served by a
## caption in the wrong language than by a nameless button.

static func read(source: Dictionary, fallback := "") -> String:
	if source.is_empty():
		return fallback
	var locale := TranslationServer.get_tool_locale().substr(0, 2)
	if source.has(locale):
		return String(source[locale])
	for key: Variant in source:
		return String(source[key])
	return fallback


## Free text to the one-language form an editor writes.
static func of(text: String, locale := "ru") -> Dictionary:
	return {} if text.strip_edges().is_empty() else {locale: text.strip_edges()}
