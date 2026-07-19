extends RefCounted

const KIND := "offering"

const ENGLISH_COPY := {
	"red_fruit": ["Red Fruit", "Sweet and juicy. Doubles this pet's faith production for 60 seconds."],
	"rice_paste": ["Rice Paste", "Warm and soft. Raises this pet's faith production to ×2.5 for 60 seconds."],
	"waffle": ["Waffle", "Crisp outside and soft within. Raises this pet's faith production to ×3 for 60 seconds."],
	"cheese": ["Cheese", "Richly fragrant. Raises this pet's faith production to ×4 for 60 seconds."],
	"chicken": ["Chicken", "Cooked chicken. Raises this pet's faith production to ×5 for 60 seconds."],
	"thick_soup": ["Thick Soup", "A bowl of hearty soup. Raises this pet's faith production to ×6.5 for 60 seconds."],
	"fish": ["Fresh Fish", "Today's fresh catch. Raises this pet's faith production to ×8 for 60 seconds."],
	"braised_intestine": ["Braised Intestine", "An unmistakably fragrant dish. Raises this pet's faith production to ×10 for 60 seconds."],
	"blood_cup": ["Blood Cup", "A vivid red nutritional drink. Raises this pet's faith production to ×13 for 60 seconds."],
	"eyeball_soup": ["Eyeball Soup", "The most lavish specialty. Raises this pet's faith production to ×16 for 60 seconds."]
}

const ITEMS := [
	{
		"id": "red_fruit",
		"kind": KIND,
		"name": "红果",
		"texture": "res://assets/ui/foods/红果.png",
		"description": "清甜多汁。投喂后，该宠物的信仰产量提高至2倍，持续60秒。",
		"price": 2,
		"multiplier": 2.0,
		"duration_seconds": 60.0
	},
	{
		"id": "rice_paste",
		"kind": KIND,
		"name": "米糊",
		"texture": "res://assets/ui/foods/米糊.png",
		"description": "温热细软。投喂后，该宠物的信仰产量提高至2.5倍，持续60秒。",
		"price": 3,
		"multiplier": 2.5,
		"duration_seconds": 60.0
	},
	{
		"id": "waffle",
		"kind": KIND,
		"name": "华夫饼",
		"texture": "res://assets/ui/foods/华夫饼.png",
		"description": "外脆内软。投喂后，该宠物的信仰产量提高至3倍，持续60秒。",
		"price": 5,
		"multiplier": 3.0,
		"duration_seconds": 60.0
	},
	{
		"id": "cheese",
		"kind": KIND,
		"name": "起司",
		"texture": "res://assets/ui/foods/起司.png",
		"description": "香味浓郁。投喂后，该宠物的信仰产量提高至4倍，持续60秒。",
		"price": 7,
		"multiplier": 4.0,
		"duration_seconds": 60.0
	},
	{
		"id": "chicken",
		"kind": KIND,
		"name": "鸡肉",
		"texture": "res://assets/ui/foods/鸡肉.png",
		"description": "烹熟的鸡肉。投喂后，该宠物的信仰产量提高至5倍，持续60秒。",
		"price": 10,
		"multiplier": 5.0,
		"duration_seconds": 60.0
	},
	{
		"id": "thick_soup",
		"kind": KIND,
		"name": "浓汤",
		"texture": "res://assets/ui/foods/浓汤.png",
		"description": "一碗浓汤。投喂后，该宠物的信仰产量提高至6.5倍，持续60秒。",
		"price": 14,
		"multiplier": 6.5,
		"duration_seconds": 60.0
	},
	{
		"id": "fish",
		"kind": KIND,
		"name": "鱼",
		"texture": "res://assets/ui/foods/鱼.png",
		"description": "今日鲜鱼。投喂后，该宠物的信仰产量提高至8倍，持续60秒。",
		"price": 19,
		"multiplier": 8.0,
		"duration_seconds": 60.0
	},
	{
		"id": "braised_intestine",
		"kind": KIND,
		"name": "九转大肠",
		"texture": "res://assets/ui/foods/九转大肠.png",
		"description": "香味很有存在感。投喂后，该宠物的信仰产量提高至10倍，持续60秒。",
		"price": 25,
		"multiplier": 10.0,
		"duration_seconds": 60.0
	},
	{
		"id": "blood_cup",
		"kind": KIND,
		"name": "血杯",
		"texture": "res://assets/ui/foods/血杯.png",
		"description": "颜色鲜红的营养饮料。投喂后，该宠物的信仰产量提高至13倍，持续60秒。",
		"price": 32,
		"multiplier": 13.0,
		"duration_seconds": 60.0
	},
	{
		"id": "eyeball_soup",
		"kind": KIND,
		"name": "眼球汤",
		"texture": "res://assets/ui/foods/眼球汤.png",
		"description": "最昂贵的特别料理。投喂后，该宠物的信仰产量提高至16倍，持续60秒。",
		"price": 40,
		"multiplier": 16.0,
		"duration_seconds": 60.0
	}
]


static func make_shop_goods() -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	for item_value in ITEMS:
		var item: Dictionary = item_value
		goods.append(item.duplicate(true))
	return goods


static func localize(offering: Dictionary, language_code: String) -> Dictionary:
	var localized := offering.duplicate(true)
	if language_code != "en":
		return localized
	var copy_value: Variant = ENGLISH_COPY.get(String(offering.get("id", "")), [])
	if copy_value is Array and copy_value.size() >= 2:
		localized["name"] = String(copy_value[0])
		localized["description"] = String(copy_value[1])
	return localized


static func normalize_offering(raw: Dictionary) -> Dictionary:
	var offering_id := String(raw.get("id", "")).strip_edges()
	var definition := _get_definition(offering_id)
	if definition.is_empty():
		return {}

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
