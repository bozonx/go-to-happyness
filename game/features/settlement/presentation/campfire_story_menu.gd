class_name CampfireStoryMenu
extends Panel

signal story_selected(story_id: String)
signal close_requested

var _story_buttons: Array[Button] = []


func _ready() -> void:
	$StoryList/Optimistic.pressed.connect(func(): story_selected.emit("optimistic"))
	$StoryList/Teaching.pressed.connect(func(): story_selected.emit("teaching"))
	$StoryList/Plan.pressed.connect(func(): story_selected.emit("plan"))
	
	$CloseButton.pressed.connect(func(): close_requested.emit())
	
	_story_buttons = [
		$StoryList/Optimistic,
		$StoryList/Teaching,
		$StoryList/Plan
	]
