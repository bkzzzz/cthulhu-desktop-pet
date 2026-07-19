extends RefCounted

## Gold remains the only stored/spendable currency. Crystals are display-only
## denominations so saves and economy arithmetic never need a migration.
const MAX_GOLD := 9_000_000_000_000_000_000
const RED_CRYSTAL_GOLD := 1_000_000
const YELLOW_CRYSTAL_GOLD := 1_000_000_000
const GRAY_CRYSTAL_GOLD := 1_000_000_000_000

const GOLD_ICON_PATH := "res://assets/ui/coins/MonedaD.png"
const RED_CRYSTAL_ICON_PATH := "res://assets/ui/coins/spr_coin_roj.png"
const YELLOW_CRYSTAL_ICON_PATH := "res://assets/ui/coins/spr_coin_ama.png"
const GRAY_CRYSTAL_ICON_PATH := "res://assets/ui/coins/spr_coin_gri.png"

const GOLD_KIND := "gold"
const RED_CRYSTAL_KIND := "red_crystal"
const YELLOW_CRYSTAL_KIND := "yellow_crystal"
const GRAY_CRYSTAL_KIND := "gray_crystal"


static func sanitize_gold(gold: int) -> int:
	return clampi(gold, 0, MAX_GOLD)


static func add_gold(current_gold: int, change: int) -> int:
	var current := sanitize_gold(current_gold)
	if change >= 0:
		if change >= MAX_GOLD - current:
			return MAX_GOLD
		return current + change
	if change <= -current:
		return 0
	return current + change


static func decompose(gold: int) -> Dictionary:
	var remaining := sanitize_gold(gold)
	var gray := int(remaining / GRAY_CRYSTAL_GOLD)
	remaining %= GRAY_CRYSTAL_GOLD
	var yellow := int(remaining / YELLOW_CRYSTAL_GOLD)
	remaining %= YELLOW_CRYSTAL_GOLD
	var red := int(remaining / RED_CRYSTAL_GOLD)
	remaining %= RED_CRYSTAL_GOLD
	return {
		GRAY_CRYSTAL_KIND: gray,
		YELLOW_CRYSTAL_KIND: yellow,
		RED_CRYSTAL_KIND: red,
		GOLD_KIND: remaining
	}


static func compose(denominations: Dictionary) -> int:
	var gray := clampi(
		int(denominations.get(GRAY_CRYSTAL_KIND, 0)),
		0,
		int(MAX_GOLD / GRAY_CRYSTAL_GOLD)
	)
	var yellow := clampi(
		int(denominations.get(YELLOW_CRYSTAL_KIND, 0)),
		0,
		int(MAX_GOLD / YELLOW_CRYSTAL_GOLD)
	)
	var red := clampi(
		int(denominations.get(RED_CRYSTAL_KIND, 0)),
		0,
		int(MAX_GOLD / RED_CRYSTAL_GOLD)
	)
	var gold := clampi(int(denominations.get(GOLD_KIND, 0)), 0, MAX_GOLD)
	var total := gray * GRAY_CRYSTAL_GOLD
	if total > MAX_GOLD - yellow * YELLOW_CRYSTAL_GOLD:
		return MAX_GOLD
	total += yellow * YELLOW_CRYSTAL_GOLD
	if total > MAX_GOLD - red * RED_CRYSTAL_GOLD:
		return MAX_GOLD
	total += red * RED_CRYSTAL_GOLD
	if total > MAX_GOLD - gold:
		return MAX_GOLD
	return total + gold


static func get_primary_display(gold: int) -> Dictionary:
	var safe_gold := sanitize_gold(gold)
	if safe_gold >= GRAY_CRYSTAL_GOLD:
		return _make_display(
			GRAY_CRYSTAL_KIND,
			"GC",
			GRAY_CRYSTAL_GOLD,
			GRAY_CRYSTAL_ICON_PATH,
			safe_gold
		)
	if safe_gold >= YELLOW_CRYSTAL_GOLD:
		return _make_display(
			YELLOW_CRYSTAL_KIND,
			"YC",
			YELLOW_CRYSTAL_GOLD,
			YELLOW_CRYSTAL_ICON_PATH,
			safe_gold
		)
	if safe_gold >= RED_CRYSTAL_GOLD:
		return _make_display(
			RED_CRYSTAL_KIND,
			"RC",
			RED_CRYSTAL_GOLD,
			RED_CRYSTAL_ICON_PATH,
			safe_gold
		)
	return _make_display(GOLD_KIND, "$", 1, GOLD_ICON_PATH, safe_gold)


static func format_compact(gold: int) -> String:
	var display := get_primary_display(gold)
	var amount_text := _format_scaled_amount(
		sanitize_gold(gold),
		int(display.get("gold_value", 1))
	)
	if String(display.get("kind", GOLD_KIND)) == GOLD_KIND:
		return "$ %s" % amount_text
	return "%s %s" % [amount_text, String(display.get("code", ""))]


static func format_exact_gold(gold: int) -> String:
	return "$%d" % sanitize_gold(gold)


static func get_conversion_tooltip(gold: int, language := "en") -> String:
	var safe_gold := sanitize_gold(gold)
	if language == "zh":
		return "%s = %d 金币\n红晶 = %d · 黄晶 = %d · 灰晶 = %d" % [
			format_compact(safe_gold),
			safe_gold,
			RED_CRYSTAL_GOLD,
			YELLOW_CRYSTAL_GOLD,
			GRAY_CRYSTAL_GOLD
		]
	return "%s = %d gold\nRed crystal = %d · Yellow crystal = %d · Gray crystal = %d" % [
		format_compact(safe_gold),
		safe_gold,
		RED_CRYSTAL_GOLD,
		YELLOW_CRYSTAL_GOLD,
		GRAY_CRYSTAL_GOLD
	]


static func make_icon_texture(gold: int) -> Texture2D:
	var display := get_primary_display(gold)
	var texture := load(String(display.get("icon_path", GOLD_ICON_PATH))) as Texture2D
	if texture == null:
		return null
	var frame_count := 5
	var frame_width := float(texture.get_width()) / float(frame_count)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, 0.0, frame_width, float(texture.get_height()))
	return atlas


static func _make_display(
	kind: String,
	code: String,
	gold_value: int,
	icon_path: String,
	total_gold: int
) -> Dictionary:
	return {
		"kind": kind,
		"code": code,
		"gold_value": gold_value,
		"icon_path": icon_path,
		"whole_units": int(total_gold / gold_value),
		"gold": total_gold
	}


static func _format_scaled_amount(gold: int, denomination_value: int) -> String:
	var safe_value := maxi(1, denomination_value)
	var whole := int(gold / safe_value)
	if safe_value == 1:
		return str(whole)
	var remainder := gold % safe_value
	var hundredths := int((remainder * 100 + int(safe_value / 2)) / safe_value)
	if hundredths >= 100:
		whole += 1
		hundredths = 0
	if hundredths == 0:
		return str(whole)
	if hundredths % 10 == 0:
		return "%d.%d" % [whole, int(hundredths / 10)]
	return "%d.%02d" % [whole, hundredths]
