extends SceneTree

## Shared list regression: category filters narrow the list without taking away
## text search.  Map water bodies are the first consumer; building and future
## editor panels can reuse the exact same interaction.

const ListScene = preload("res://game/features/ui/presentation/editor/editor_searchable_list.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var list := ListScene.instantiate() as EditorSearchableList
	root.add_child(list)
	list.set_entries(
		["Озеро · уровень 2", "Озеро · уровень 7", "Река · уровень 3"],
		"Нет водоёмов", -1, ["Озеро", "Река"])
	await process_frame
	var search := list.get_node("Search") as LineEdit
	var entries := list.get_node("List") as ItemList
	assert(search.visible, "search remains available when category filters are present")
	var lake_filter := list.get_node("Filters").get_child(1) as Button
	lake_filter.emit_signal("pressed")
	search.text = "7"
	search.text_changed.emit(search.text)
	assert(entries.item_count == 1 and entries.get_item_text(0).contains("уровень 7"),
		"filter and search are combined")
	print("[PASS] Editor searchable list combines filters and search")
	quit(0)
