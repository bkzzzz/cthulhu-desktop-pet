extends RefCounted

# Desktop items are visual, reusable shop goods. They deliberately have no
# combat stats: placing one decorates the taskbar instead of changing battles.
const KIND := "desktop_item"
const ITEM_IDS := ["shovel", "coin_collector", "sofa"]

const DEFINITIONS := {
	"shovel": {
		"id": "shovel",
		"kind": KIND,
		"name": "铲子",
		"name_en": "Shovel",
		"description": "可摆放在任务栏边的桌面道具。",
		"description_en": "A desktop item that sits flush against the taskbar.",
		"texture": "res://assets/furniture/shopItems/铲子.png",
		"price": 500,
		"visual_scale": 0.65,
		"default_x_fraction": 0.26
	},
	"coin_collector": {
		"id": "coin_collector",
		"kind": KIND,
		"name": "金币收集器",
		"name_en": "Coin Collector",
		"description": "可摆放在任务栏边的桌面道具。",
		"description_en": "A desktop item that sits flush against the taskbar.",
		"texture": "res://assets/furniture/shopItems/金币收集器.png",
		"price": 2_000,
		"visual_scale": 0.40,
		"default_x_fraction": 0.50
	},
	"sofa": {
		"id": "sofa",
		"kind": KIND,
		"name": "沙发",
		"name_en": "Sofa",
		"description": "可摆放在任务栏边的桌面道具。",
		"description_en": "A desktop item that sits flush against the taskbar.",
		"texture": "res://assets/furniture/shopItems/沙发.png",
		"price": 1_500,
		"visual_scale": 0.50,
		"default_x_fraction": 0.74
	}
}


static func has_item(item_id: String) -> bool:
	return DEFINITIONS.has(item_id.strip_edges())


static func get_definition(item_id: String) -> Dictionary:
	var definition_value: Variant = DEFINITIONS.get(item_id.strip_edges(), {})
	return (definition_value as Dictionary).duplicate(true) if definition_value is Dictionary else {}


static func make_shop_goods() -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	for item_id in ITEM_IDS:
		var definition := get_definition(item_id)
		if not definition.is_empty():
			goods.append(definition)
	return goods


static func is_item(good: Dictionary) -> bool:
	return String(good.get("kind", "")) == KIND and has_item(String(good.get("id", "")))


static func normalize_item(raw: Dictionary) -> Dictionary:
	var item_id := String(raw.get("id", raw.get("item_id", ""))).strip_edges()
	var normalized := get_definition(item_id)
	if normalized.is_empty():
		return {}
	# Prices and asset metadata are catalog-owned so a malformed save or UI event
	# cannot mint an unpriced desktop item.
	normalized["base_price"] = maxi(1, int(normalized.get("price", 1)))
	normalized["price"] = normalized["base_price"]
	normalized["visual_scale"] = clampf(float(normalized.get("visual_scale", 0.5)), 0.10, 2.0)
	normalized["default_x_fraction"] = clampf(
		float(normalized.get("default_x_fraction", 0.5)),
		0.0,
		1.0
	)
	return normalized


static func localize(item: Dictionary, language_code: String) -> Dictionary:
	var localized := item.duplicate(true)
	if language_code.strip_edges().to_lower() != "en":
		return localized
	localized["name"] = String(item.get("name_en", item.get("name", "Item")))
	localized["description"] = String(item.get("description_en", item.get("description", "")))
	return localized
