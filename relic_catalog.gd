class_name RelicCatalog
extends RefCounted

const RELICS := {
	"crimson_blade": {
		"name": "Lamina Carmesim",
		"description": "+1 de dano da espada",
		"color": Color(0.92, 0.18, 0.22, 1.0),
		"effects": {"attack_damage_add": 1},
	},
	"wind_boots": {
		"name": "Botas do Vendaval",
		"description": "+15% de velocidade",
		"color": Color(0.24, 0.78, 1.0, 1.0),
		"effects": {"speed_multiplier": 1.15},
	},
	"far_eye": {
		"name": "Olho Longinquo",
		"description": "+24 de alcance e +8 de largura",
		"color": Color(0.68, 0.38, 1.0, 1.0),
		"effects": {
			"attack_range_add": 24.0,
			"attack_width_add": 8.0,
		},
	},
	"iron_heart": {
		"name": "Coracao de Ferro",
		"description": "+1 de vida maxima e cura 1",
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
