class_name CampfireStoryMenu
extends Panel

signal story_selected(story_id: String)
signal close_requested

var _story_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -220.0
	offset_top = -140.0
	offset_right = 220.0
	offset_bottom = 140.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false

	var title := Label.new()
	title.text = "Campfire Story"
	title.position = Vector2(20, 16)
	title.size = Vector2(400, 28)
	title.add_theme_font_size_override("font_size", 17)
	add_child(title)

	var desc := Label.new()
	desc.text = "Choose tonight's theme (only after 20:00 in the Tent Era)."
	desc.position = Vector2(20, 50)
	desc.size = Vector2(400, 40)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(desc)

	var stories := [
		{"id": "optimistic", "label": "Optimistic stories", "tooltip": "Wellbeing recovers faster tonight, but everyone wakes an hour later."},
		{"id": "teaching", "label": "Teaching tales", "tooltip": "One random resident learns a little of a physical skill overnight."},
		{"id": "plan", "label": "Plan for tomorrow", "tooltip": "Work speed +15%% for gathering tasks tomorrow; night calorie cost rises."},
	]
	var y := 100
	for story in stories:
		var btn := Button.new()
		btn.text = story.label
		btn.tooltip_text = story.tooltip
		btn.position = Vector2(20, y)
		btn.size = Vector2(400, 30)
		btn.pressed.connect(story_selected.emit.bind(story.id))
		add_child(btn)
		_story_buttons.append(btn)
		y += 38

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(20, y + 4)
	close.size = Vector2(400, 28)
	close.pressed.connect(close_requested.emit)
	add_child(close)
