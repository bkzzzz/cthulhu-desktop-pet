extends RefCounted

const BASE_DRAW_COST := 75.0
const DRAW_COST_GROWTH := 1.60
const MAX_DRAW_COST := 8_000_000_000_000_000_000
const CAMPAIGN_TARGET_HOURS := 800.0
const CAMPAIGN_PET_COUNT_TARGET := 100

const BUFFS := [
	{
		"id": "whisper",
		"name": "低语残响",
		"rarity": "普通",
		"bonus": 0.10,
		"weight": 65.0,
		"color": "#b8c4b2",
		"description": "所有宠物的信仰产出永久提高 10%。"
	},
	{
		"id": "omen",
		"name": "深海征兆",
		"rarity": "罕见",
		"bonus": 0.20,
		"weight": 25.0,
		"color": "#83c7b5",
		"description": "所有宠物的信仰产出永久提高 20%。"
	},
	{
		"id": "revelation",
		"name": "禁忌启示",
		"rarity": "稀有",
		"bonus": 0.40,
		"weight": 8.0,
		"color": "#82aee8",
		"description": "所有宠物的信仰产出永久提高 40%。"
	},
	{
		"id": "outer_blessing",
		"name": "外神赐福",
		"rarity": "神话",
		"bonus": 1.0,
		"weight": 2.0,
		"color": "#e8bd62",
		"description": "所有宠物的信仰产出永久提高 100%。"
	}
]


static func draw_cost(draw_count: int) -> int:
	var safe_count := maxi(0, draw_count)
	var raw_cost := BASE_DRAW_COST * pow(DRAW_COST_GROWTH, float(safe_count))
	if not is_finite(raw_cost) or raw_cost >= float(MAX_DRAW_COST):
		return MAX_DRAW_COST
	return maxi(1, int(round(raw_cost)))


static func roll(unit_roll: float, pity_count := 0) -> Dictionary:
	var pool: Array = BUFFS
	if pity_count >= 11:
		pool = [BUFFS[2], BUFFS[3]]
	var total_weight := 0.0
	for buff in pool:
		total_weight += float(buff.get("weight", 0.0))
	if total_weight <= 0.0:
		return {}

	var target := clampf(unit_roll, 0.0, 0.999999) * total_weight
	var accumulated := 0.0
	for buff in pool:
		accumulated += float(buff.get("weight", 0.0))
		if target < accumulated:
			return buff.duplicate(true)
	return pool.back().duplicate(true)


static func apply_buff(current_bonus: float, buff: Dictionary) -> float:
	var safe_bonus := maxf(0.0, current_bonus)
	var bonus := maxf(0.0, float(buff.get("bonus", 0.0)))
	return safe_bonus + bonus


static func next_pity_count(current_pity: int, buff: Dictionary) -> int:
	return 0 if float(buff.get("bonus", 0.0)) >= 0.40 else maxi(0, current_pity) + 1
