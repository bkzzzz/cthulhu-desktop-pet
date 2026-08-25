extends RefCounted

const CurrencyDisplay = preload("res://scripts/domain/currency_display.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_six_drop_assets_are_visual_denominations(failures)
	_test_account_arithmetic(failures)
	_test_single_balance_display(failures)
	_test_account_icon_is_cached(failures)
	_test_drawer_keeps_one_account_icon(failures)
	return failures


static func _test_six_drop_assets_are_visual_denominations(failures: Array[String]) -> void:
	var previous_value := 0
	for type_id in ["R", "P", "D", "C", "S", "G"]:
		var value := CoinDrop.get_coin_value(type_id)
		var path := CoinDrop.get_coin_texture(type_id)
		if value <= previous_value:
			failures.append("the six world-drop animations must represent increasing money values")
		if path.is_empty() or not ResourceLoader.exists(path):
			failures.append("world-drop denomination asset must remain importable: %s" % path)
		previous_value = value


static func _test_account_arithmetic(failures: Array[String]) -> void:
	if CurrencyDisplay.add_gold(CurrencyDisplay.MAX_GOLD - 5, 10) != CurrencyDisplay.MAX_GOLD:
		failures.append("gold rewards must saturate safely instead of overflowing the saved balance")
	if CurrencyDisplay.add_gold(5, -10) != 0:
		failures.append("gold spending must saturate safely instead of producing a negative balance")
	if CurrencyDisplay.add_gold(100, 900) != 1000:
		failures.append("different coin animations must still deposit into one integer account")


static func _test_single_balance_display(failures: Array[String]) -> void:
	var cases := {
		999: "$ 999",
		1000: "$ 1,000",
		1_250_000: "$ 1,250,000",
		1_250_000_000: "$ 1,250,000,000"
	}
	for gold_value in cases:
		var actual := CurrencyDisplay.format_compact(int(gold_value))
		if actual != String(cases[gold_value]):
			failures.append("money account display expected %s, got %s" % [cases[gold_value], actual])
		if actual.contains("RC") or actual.contains("YC") or actual.contains("GC"):
			failures.append("the account must never present drop animations as separate currencies")


static func _test_account_icon_is_cached(failures: Array[String]) -> void:
	var first_icon := CurrencyDisplay.make_icon_texture(0)
	var later_icon := CurrencyDisplay.make_icon_texture(CurrencyDisplay.MAX_GOLD)
	if first_icon == null or later_icon == null:
		failures.append("the account display must provide an icon texture")
	elif first_icon.get_instance_id() != later_icon.get_instance_id():
		failures.append("money balance refreshes must reuse the account icon texture")


static func _test_drawer_keeps_one_account_icon(failures: Array[String]) -> void:
	var drawer := SideDrawer.new()
	drawer.call("_create_drawer_window")
	drawer.call("_build_pending_drawer_work", 64)
	drawer.refresh_coins(1_250_000_000)
	var label := drawer.get("_coin_value_label") as Label
	var icon := drawer.get("_coin_icon") as TextureRect
	if label == null or label.text != "$ 1,250,000,000":
		failures.append("the drawer must show one exact bank-style money balance")
	if icon == null or not (icon.texture is AtlasTexture):
		failures.append("the drawer must keep one stable money icon beside the account total")
	else:
		var atlas := icon.texture as AtlasTexture
		if atlas.atlas == null or atlas.atlas.resource_path != CurrencyDisplay.ACCOUNT_ICON_PATH:
			failures.append("large balances must not swap the account icon to another coin type")
	drawer.free()
