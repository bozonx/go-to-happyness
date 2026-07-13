class_name ShadowCitizenActuator
extends CitizenActuator

## Read-only actuator for tests and future shadow observations. It prevents an
## unmigrated mechanic from issuing commands through the native runtime.


func is_valid() -> bool:
	return citizen_id != 0
