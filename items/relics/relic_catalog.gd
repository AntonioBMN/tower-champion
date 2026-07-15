class_name RelicCatalog
extends RefCounted

const RELICS := {
	"crimson_blade": {
		"name_key": "RELIC_CRIMSON_BLADE_NAME",
		"description_key": "RELIC_CRIMSON_BLADE_DESCRIPTION",
		"color": Color(0.92, 0.18, 0.22, 1.0),
		"effects": {"attack_damage_add": 1},
	},
	"wind_boots": {
		"name_key": "RELIC_WIND_BOOTS_NAME",
		"description_key": "RELIC_WIND_BOOTS_DESCRIPTION",
		"color": Color(0.24, 0.78, 1.0, 1.0),
		"effects": {"speed_multiplier": 1.15},
	},
	"far_eye": {
		"name_key": "RELIC_FAR_EYE_NAME",
		"description_key": "RELIC_FAR_EYE_DESCRIPTION",
		"color": Color(0.68, 0.38, 1.0, 1.0),
		"effects": {
			"attack_range_add": 24.0,
			"attack_width_add": 8.0,
		},
	},
	"iron_heart": {
		"name_key": "RELIC_IRON_HEART_NAME",
		"description_key": "RELIC_IRON_HEART_DESCRIPTION",
		"color": Color(0.95, 0.56, 0.18, 1.0),
		"effects": {
			"max_health_add": 1,
			"heal_amount": 1,
		},
	},
}


static func get_relic(relic_id: String) -> Dictionary:
	if not RELICS.has(relic_id):
		return {}

	return RELICS[relic_id].duplicate(true)


static func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for relic_id in RELICS:
		result.append(relic_id)
	return result


static func has_relic(relic_id: String) -> bool:
	return RELICS.has(relic_id)
