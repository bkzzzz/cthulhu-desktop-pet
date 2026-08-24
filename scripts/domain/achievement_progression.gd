extends RefCounted

const DEFINITIONS := [
	{"id": "battle_1", "metric": "battle_victories", "target": 1.0, "gold": 750, "faith": 500.0,
		"name": "First Blood", "name_zh": "初战告捷", "description": "Win 1 battle", "description_zh": "赢得 1 场战斗"},
	{"id": "battle_10", "metric": "battle_victories", "target": 10.0, "gold": 12_000, "faith": 20_000.0,
		"name": "Battle Hardened", "name_zh": "百战之躯", "description": "Win 10 battles", "description_zh": "赢得 10 场战斗"},
	{"id": "battle_50", "metric": "battle_victories", "target": 50.0, "gold": 250_000, "faith": 1_000_000.0,
		"name": "Unbroken Legion", "name_zh": "不败军团", "description": "Win 50 battles", "description_zh": "赢得 50 场战斗"},
	{"id": "rate_1", "metric": "faith_rate", "target": 1.0, "gold": 1_000, "faith": 1_000.0,
		"name": "A Whisper Becomes a Choir", "name_zh": "低语成歌", "description": "Reach 1 faith per second", "description_zh": "信仰增长达到 1/秒"},
	{"id": "rate_100", "metric": "faith_rate", "target": 100.0, "gold": 20_000, "faith": 50_000.0,
		"name": "Gathering Momentum", "name_zh": "声势渐盛", "description": "Reach 100 faith per second", "description_zh": "信仰增长达到 100/秒"},
	{"id": "rate_10000", "metric": "faith_rate", "target": 10_000.0, "gold": 300_000, "faith": 2_000_000.0,
		"name": "The Signal Spreads", "name_zh": "信号扩散", "description": "Reach 10,000 faith per second", "description_zh": "信仰增长达到 10,000/秒"},
	{"id": "rate_500000", "metric": "faith_rate", "target": 500_000.0, "gold": 5_000_000, "faith": 30_000_000.0,
		"name": "Cosmic Broadcast", "name_zh": "群星广播", "description": "Reach 500,000 faith per second", "description_zh": "信仰增长达到 500,000/秒"},
	{"id": "followers_100", "metric": "followers", "target": 100.0, "gold": 2_500, "faith": 3_000.0,
		"name": "A Real Congregation", "name_zh": "初具规模", "description": "Register 100 followers", "description_zh": "拥有 100 名教众"},
	{"id": "followers_10000", "metric": "followers", "target": 10_000.0, "gold": 75_000, "faith": 250_000.0,
		"name": "City of Believers", "name_zh": "信徒之城", "description": "Register 10,000 followers", "description_zh": "拥有 10,000 名教众"},
	{"id": "followers_1000000", "metric": "followers", "target": 1_000_000.0, "gold": 2_000_000, "faith": 15_000_000.0,
		"name": "One Million Voices", "name_zh": "百万呼声", "description": "Register 1,000,000 followers", "description_zh": "拥有 1,000,000 名教众"},
	{"id": "pets_3", "metric": "pets_unlocked", "target": 3.0, "gold": 15_000, "faith": 25_000.0,
		"name": "Growing Brood", "name_zh": "眷族初成", "description": "Unlock 3 pets", "description_zh": "解锁 3 只宠物"},
	{"id": "pets_6", "metric": "pets_unlocked", "target": 6.0, "gold": 400_000, "faith": 2_500_000.0,
		"name": "Eldritch Household", "name_zh": "异界家族", "description": "Unlock 6 pets", "description_zh": "解锁 6 只宠物"},
	{"id": "pets_10", "metric": "pets_unlocked", "target": 10.0, "gold": 8_000_000, "faith": 50_000_000.0,
		"name": "The Family Is Complete", "name_zh": "眷族齐聚", "description": "Unlock all 10 pets", "description_zh": "解锁全部 10 只宠物"},
]


static func get_definition(achievement_id: String) -> Dictionary:
	for definition_value in DEFINITIONS:
		var definition := definition_value as Dictionary
		if String(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)
	return {}


static func get_progress(definition: Dictionary, metrics: Dictionary) -> float:
	var metric_id := String(definition.get("metric", ""))
	var raw_value := float(metrics.get(metric_id, 0.0))
	return maxf(0.0, raw_value) if is_finite(raw_value) else 0.0


static func is_complete(definition: Dictionary, metrics: Dictionary) -> bool:
	return get_progress(definition, metrics) + 0.000001 >= maxf(0.0, float(definition.get("target", INF)))


static func sanitize_claimed_ids(raw_value: Variant) -> Array[String]:
	var valid_ids := {}
	for definition_value in DEFINITIONS:
		valid_ids[String((definition_value as Dictionary).get("id", ""))] = true
	var sanitized: Array[String] = []
	if not raw_value is Array:
		return sanitized
	for id_value in raw_value:
		var achievement_id := String(id_value)
		if valid_ids.has(achievement_id) and not sanitized.has(achievement_id):
			sanitized.append(achievement_id)
	return sanitized
