extends RefCounted

## Gold is one account balance. The six coin sheets are visual denominations
## used by world drops only; they never become separate stored currencies.
const MAX_GOLD := 9_000_000_000_000_000_000
const ACCOUNT_ICON_PATH := "res://assets/ui/coins/MonedaD.png"


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


static func format_compact(gold: int) -> String:
	return "$ %s" % _format_account_number(sanitize_gold(gold))


static func format_exact_gold(gold: int) -> String:
	return "$%s" % _format_account_number(sanitize_gold(gold))


static func get_conversion_tooltip(gold: int, language := "en") -> String:
	var balance := format_exact_gold(gold)
	return (
		"账户余额：%s\n所有硬币都会存入同一个金钱账户" % balance
		if language == "zh"
		else "Account balance: %s\nEvery coin is deposited into the same money account" % balance
	)


static func make_icon_texture(_gold: int) -> Texture2D:
	var texture := load(ACCOUNT_ICON_PATH) as Texture2D
	if texture == null:
		return null
	var frame_count := 5
	var frame_width := float(texture.get_width()) / float(frame_count)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, 0.0, frame_width, float(texture.get_height()))
	return atlas


static func _format_account_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var grouped := ""
	var first_group_size := digits.length() % 3
	if first_group_size == 0:
		first_group_size = 3
	grouped = digits.substr(0, first_group_size)
	var cursor := first_group_size
	while cursor < digits.length():
		grouped += "," + digits.substr(cursor, 3)
		cursor += 3
	return grouped
