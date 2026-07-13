class_name ShadowCitizenActuator
extends CitizenActuator

## Phase-one actuator. It makes the connected AI runtime explicitly read-only;
## no accidental command can compete with the legacy scheduler before migration.


func is_valid() -> bool:
	return citizen_id != 0
