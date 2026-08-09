class_name EditorConfirmation
extends RefCounted

## Shared transient confirmation for authoring tools. It owns modal
## presentation and result collection; each editor supplies its own text.

static func ask(
	host: Node,
	message: String,
	title := "Подтверждение",
	ok_text := "Продолжить",
	cancel_text := "Отмена",
	size := Vector2i(420, 140),
) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = cancel_text
	# GDScript lambdas capture locals by value, so mutable result state must live
	# in a container shared with the signal callback.
	var confirmed := [false]
	dialog.confirmed.connect(func() -> void: confirmed[0] = true)
	host.add_child(dialog)
	dialog.popup_centered(size)
	while dialog.visible:
		await host.get_tree().process_frame
	dialog.queue_free()
	return confirmed[0]
