extends RefCounted

# Durable defensive furniture is intentionally priced outside the food economy.
# Food prices are dynamic, while a tower is a major mid-game capital purchase.
const KIND := "turret"
const TURRET_IDS := ["turret1", "turret2", "turret3", "turret4"]

const DEFINITIONS := {
	"turret1": {
		"id": "turret1",
		"kind": KIND,
		"name": "苍晶守卫",
		"name_en": "Azure Crystal Ward",
		"description": "以苍蓝晶核锁定远处敌人，稳定发射奥术脉冲。",
		"description_en": "A steady crystal ward that fires arcane pulses at distant enemies.",
		"texture": "res://assets/furniture/turret3/turret1.png",
		"price": 120_000,
		"max_health": 46.0,
		"max_durability": 46.0,
		"damage": 2.8,
		"cooldown": 0.92,
		"range": 700.0,
		"projectile_visual": "turret1",
		"visual_scale": 0.50,
		"aura_color": Color(0.20, 0.82, 1.0, 1.0),
		"attack_origin_height": 0.50
	},
	"turret2": {
		"id": "turret2",
		"kind": KIND,
		"name": "雷核方尖塔",
		"name_en": "Stormcore Obelisk",
		"description": "紫电在浮核间盘旋，能够更快地连续轰击敌群。",
		"description_en": "A violet stormcore that chains rapid pulses through the enemy line.",
		"texture": "res://assets/furniture/turret3/turret2.png",
		"price": 360_000,
		"max_health": 74.0,
		"max_durability": 74.0,
		"damage": 4.9,
		"cooldown": 0.70,
		"range": 760.0,
		"projectile_visual": "turret2",
		"visual_scale": 0.49,
		"aura_color": Color(0.66, 0.33, 1.0, 1.0),
		"attack_origin_height": 0.53
	},
	"turret3": {
		"id": "turret3",
		"kind": KIND,
		"name": "日耀棱镜塔",
		"name_en": "Sunlance Prism",
		"description": "将金色棱晶压缩成高能光束，对重装目标造成沉重伤害。",
		"description_en": "A golden prism that condenses high-energy lances for heavy targets.",
		"texture": "res://assets/furniture/turret3/turret3.png",
		"price": 900_000,
		"max_health": 118.0,
		"max_durability": 118.0,
		"damage": 9.0,
		"cooldown": 1.12,
		"range": 840.0,
		"projectile_visual": "turret3",
		"visual_scale": 0.53,
		"aura_color": Color(1.0, 0.72, 0.22, 1.0),
		"attack_origin_height": 0.50
	},
	"turret4": {
		"id": "turret4",
		"kind": KIND,
		"name": "虚界引力塔",
		"name_en": "Voidwell Singularity",
		"description": "环绕的碎片维持微型奇点，以毁灭性的虚空弹压制整片战线。",
		"description_en": "Orbiting fragments sustain a tiny singularity that suppresses an entire battle line.",
		# The imported source is intentionally named `turrent4.png`.
		"texture": "res://assets/furniture/turret3/turrent4.png",
		"price": 2_400_000,
		"max_health": 188.0,
		"max_durability": 188.0,
		"damage": 14.2,
		"cooldown": 0.64,
		"range": 920.0,
		"projectile_visual": "turret4",
		"visual_scale": 0.55,
		"aura_color": Color(0.70, 0.28, 1.0, 1.0),
		"attack_origin_height": 0.56
	}
}


static func has_turret(turret_id: String) -> bool:
	return DEFINITIONS.has(turret_id.strip_edges())


static func get_definition(turret_id: String) -> Dictionary:
	var definition_value: Variant = DEFINITIONS.get(turret_id.strip_edges(), {})
	return (definition_value as Dictionary).duplicate(true) if definition_value is Dictionary else {}


static func make_shop_goods() -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	for turret_id in TURRET_IDS:
		var definition := get_definition(turret_id)
		if not definition.is_empty():
			goods.append(definition)
	return goods


static func is_turret(good: Dictionary) -> bool:
	if String(good.get("kind", "")) != KIND:
		return false
	return has_turret(String(good.get("id", "")))


static func normalize_turret(raw: Dictionary) -> Dictionary:
	var turret_id := String(raw.get("id", raw.get("turret_id", ""))).strip_edges()
	var normalized := get_definition(turret_id)
	if normalized.is_empty():
		return {}

	var authored_price := maxi(1, int(normalized.get("price", 1)))
	normalized["base_price"] = authored_price
	# Towers use a fixed capital price rather than the food economy's dynamic
	# price model. Never trust a caller to discount or inflate that value.
	normalized["price"] = authored_price
	var maximum_health := maxf(
		1.0,
		float(normalized.get("max_health", normalized.get("max_durability", 1.0)))
	)
	normalized["max_health"] = maximum_health
	normalized["max_durability"] = maximum_health
	normalized["damage"] = maxf(0.0, float(normalized.get("damage", 0.0)))
	normalized["cooldown"] = maxf(0.05, float(normalized.get("cooldown", 1.0)))
	normalized["range"] = maxf(1.0, float(normalized.get("range", 1.0)))
	normalized["visual_scale"] = clampf(float(normalized.get("visual_scale", 0.5)), 0.10, 2.0)
	normalized["attack_origin_height"] = clampf(
		float(normalized.get("attack_origin_height", 0.5)),
		0.10,
		0.90
	)
	return normalized


static func get_default_durability(turret_id: String) -> float:
	var definition := get_definition(turret_id)
	return maxf(0.0, float(definition.get("max_health", definition.get("max_durability", 0.0))))


static func localize(turret: Dictionary, language_code: String) -> Dictionary:
	var localized := turret.duplicate(true)
	if language_code.strip_edges().to_lower() != "en":
		return localized
	localized["name"] = String(turret.get("name_en", turret.get("name", "Turret")))
	localized["description"] = String(
		turret.get("description_en", turret.get("description", ""))
	)
	return localized
