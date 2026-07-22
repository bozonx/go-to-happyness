class_name CitizenRoleProfile
extends RefCounted

const PROFILES := {
	"unassigned": {"label": "Unassigned", "role": "", "color": "b9b5aa"},
	"builder": {"label": "Builder", "role": "construction", "color": "d8a647"},
	"forestry": {"label": "Forester", "role": "forestry", "color": "3f9b61"},
	"farming": {"label": "Farmer", "role": "farming", "color": "5c8fc9"},
	"excavation": {"label": "Digger", "role": "excavation", "color": "a6744b"},
	"courier": {"label": "Courier", "role": "courier", "color": "a85d91"},
	"cook": {"label": "Cook", "role": "cook", "color": "d96f43"},
	"teacher": {"label": "Teacher", "role": "teacher", "color": "7656a8"},
	"factory_worker": {"label": "Factory worker", "role": "factory_worker", "color": "c45d42"},
	"engineer": {"label": "Engineer", "role": "engineer", "color": "4d7a9b"},
	"seller": {"label": "Seller", "role": "seller", "color": "5ca0cf"},
	"craftsman": {"label": "Craftsman", "role": "craftsman", "color": "c49a4b"},
	"official": {"label": "Employment officer", "role": "official", "color": "8a8f99"},
}


static func label_for(specialization: String) -> String:
	return str(PROFILES.get(specialization, PROFILES.courier).label)


static func preferred_role_for(specialization: String) -> String:
	return str(PROFILES.get(specialization, PROFILES.courier).role)


static func color_for(specialization: String) -> Color:
	var hex_str: String = str(PROFILES.get(specialization, PROFILES.courier).color)
	return Color(hex_str)
