class_name CitizenRoleProfile
extends RefCounted

const PROFILES := {
	"builder": {"label": "Builder", "role": "construction", "color": Color("d8a647")},
	"forestry": {"label": "Forester", "role": "forestry", "color": Color("3f9b61")},
	"farming": {"label": "Farmer", "role": "farming", "color": Color("5c8fc9")},
	"excavation": {"label": "Digger", "role": "excavation", "color": Color("a6744b")},
	"courier": {"label": "Courier", "role": "courier", "color": Color("a85d91")},
	"cook": {"label": "Cook", "role": "cook", "color": Color("d96f43")},
	"teacher": {"label": "Teacher", "role": "teacher", "color": Color("7656a8")},
	"factory_worker": {"label": "Factory worker", "role": "factory_worker", "color": Color("c45d42")},
	"engineer": {"label": "Engineer", "role": "engineer", "color": Color("4d7a9b")},
}


static func label_for(specialization: String) -> String:
	return str(PROFILES.get(specialization, PROFILES.courier).label)


static func preferred_role_for(specialization: String) -> String:
	return str(PROFILES.get(specialization, PROFILES.courier).role)


static func color_for(specialization: String) -> Color:
	return PROFILES.get(specialization, PROFILES.courier).color
