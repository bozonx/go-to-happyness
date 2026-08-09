class_name EditorStatusMessage
extends RefCounted

## One presentation contract for messages in authoring tools. Domain and
## application code provide plain text; editor UI owns decoration and colour.

enum Severity { INFO, WARNING, ERROR }

const INFO_COLOR := Color(0.9, 0.92, 0.95)
const WARNING_COLOR := Color(1.0, 0.78, 0.2)
const ERROR_COLOR := Color(1.0, 0.3, 0.3)


static func text(message: String, severity: int) -> String:
	match severity:
		Severity.ERROR:
			return "❌ %s" % message
		Severity.WARNING:
			return "⚠️ %s" % message
		_:
			return message


static func color(severity: int) -> Color:
	match severity:
		Severity.ERROR:
			return ERROR_COLOR
		Severity.WARNING:
			return WARNING_COLOR
		_:
			return INFO_COLOR


static func infer(message: String) -> int:
	var lowered := message.to_lower()
	if "ошибок и предупреждений нет" in lowered:
		return Severity.INFO
	for marker: String in ["ошиб", "не удалось", "невозмож", "нельзя", "не может", "не сохран", "не примен", "не хватает", "не выбран", "недоступ", "уже занят", "должен", "пустым", "отказ", "вне карты"]:
		if marker in lowered:
			return Severity.ERROR
	if "предупреж" in lowered or "внимание" in lowered or "замечани" in lowered:
		return Severity.WARNING
	return Severity.INFO
