extends RefCounted

## Trusted definitions shared by the shop and the desktop drop flow. Offerings
## are consumables: buying one immediately puts it on the cursor instead of
## adding it to the shop's persistent owned-count inventory.

const KIND := "offering"

const ITEMS := [
	{
		"id": "red_fruit",
		"kind": KIND,
		"name": "红果",
		"texture": "res://assets/ui/foods/红果.png",
		"description": "清甜多汁。购买后会跟随鼠标，点击桌面即可投喂。",
		"price": 8,
		"faith": 3
	},
	{
		"id": "waffle",
		"kind": KIND,
		"name": "华夫饼",
		"texture": "res://assets/ui/foods/华夫饼.png",
		"description": "外脆内软，格子里偶尔会积一小滩海水。购买后点击桌面投喂。",
		"price": 12,
		"faith": 5
	},
	{
		"id": "chicken",
		"kind": KIND,
		"name": "鸡肉",
		"texture": "res://assets/ui/foods/鸡肉.png",
		"description": "正常烹熟的鸡肉，至少送检报告坚持这么写。购买后点击桌面投喂。",
		"price": 16,
		"faith": 7
	},
	{
		"id": "braised_intestine",
		"kind": KIND,
		"name": "九转大肠",
		"texture": "res://assets/ui/foods/九转大肠.png",
		"description": "气味很有存在感，附近宠物通常会主动赶来。购买后点击桌面投喂。",
		"price": 24,
		"faith": 10
	},
	{
		"id": "rice_paste",
		"kind": KIND,
		"name": "米糊",
		"texture": "res://assets/ui/foods/米糊.png",
		"description": "温热细软，碗底印着一行无法报销的小字。购买后点击桌面投喂。",
		"price": 9,
		"faith": 4
	},
	{
		"id": "thick_soup",
		"kind": KIND,
		"name": "浓汤",
		"texture": "res://assets/ui/foods/浓汤.png",
		"description": "浓得勺子能短暂站立，随后会自行躺下。购买后点击桌面投喂。",
		"price": 18,
		"faith": 8
	},
	{
		"id": "cheese",
		"kind": KIND,
		"name": "起司",
		"texture": "res://assets/ui/foods/起司.png",
		"description": "香味稳定，孔洞数量每次清点都不同。购买后点击桌面投喂。",
		"price": 14,
		"faith": 6
	},
	{
		"id": "blood_cup",
		"kind": KIND,
		"name": "血杯",
		"texture": "res://assets/ui/foods/血杯.png",
		"description": "颜色鲜红的营养饮料，供应商拒绝解释配料表。购买后点击桌面投喂。",
		"price": 28,
		"faith": 12
	},
	{
		"id": "eyeball_soup",
		"kind": KIND,
		"name": "眼球汤",
		"texture": "res://assets/ui/foods/眼球汤.png",
		"description": "汤里的主料会礼貌避开勺子。购买后点击桌面投喂。",
		"price": 36,
		"faith": 15
	},
	{
		"id": "fish",
		"kind": KIND,
		"name": "鱼",
		"texture": "res://assets/ui/foods/鱼.png",
		"description": "今日鲜鱼，离开冷柜后仍偶尔调整朝向。购买后点击桌面投喂。",
		"price": 20,
		"faith": 9
	}
]


static func make_shop_goods() -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	for item_value in ITEMS:
		var item: Dictionary = item_value
		goods.append(item.duplicate(true))
	return goods


static func normalize_offering(raw: Dictionary) -> Dictionary:
	var offering_id := String(raw.get("id", "")).strip_edges()
	var definition := _get_definition(offering_id)
	if definition.is_empty():
		return {}

	# Names, textures, prices, and rewards always come from the trusted catalog.
	# Only the exact price already paid is carried through for cancellation/save
	# migration; old altar offerings simply normalize with a paid price of zero.
	var normalized := definition.duplicate(true)
	if raw.has("purchase_price"):
		normalized["purchase_price"] = clampi(int(raw.get("purchase_price", 0)), 0, 1000000000)
	return normalized


static func is_offering(good: Dictionary) -> bool:
	if String(good.get("kind", "")) != KIND:
		return false
	return not _get_definition(String(good.get("id", "")).strip_edges()).is_empty()


static func _get_definition(offering_id: String) -> Dictionary:
	if offering_id.is_empty():
		return {}
	for item_value in ITEMS:
		var item: Dictionary = item_value
		if String(item.get("id", "")) == offering_id:
			return item
	return {}
