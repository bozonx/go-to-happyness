class_name ScenarioBanner
extends CanvasLayer

## Host-level presentation of a running scenario (map_editor.md §10.5).
##
## A rule's `message` and the moment a map is won or lost have to be visible in
## every game, including the World Showcase, which has no HUD of its own — a rule
## table that only reported itself to the console would be indistinguishable from
## one that never fired, and that is what makes scenario authoring untestable.
##
## Deliberately minimal: this is the host's fallback, not a game's UI. A game with
## its own message system connects to `MapScenarioRuntime` directly and hides
## this by never adding it.

## How long a rule message stays on screen. Long enough to read a sentence,
## short enough that two rules firing in sequence do not stack up.
const MESSAGE_SECONDS := 6.0

@onready var _message: Label = $Root/Message
@onready var _outcome: Label = $Root/Outcome

var _remaining := 0.0


func bind(runtime: MapScenarioRuntime) -> void:
	if runtime == null:
		return
	runtime.message_emitted.connect(show_message)
	runtime.outcome_reached.connect(show_outcome)


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()
	_remaining = MESSAGE_SECONDS


func show_outcome(outcome: StringName) -> void:
	_outcome.text = "Победа" if outcome == MapScenarioRuntime.OUTCOME_VICTORY else "Поражение"
	_outcome.visible = true


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_message.visible = false
