extends RefCounted

const CurrencyDisplay = preload("res://scripts/domain/currency_display.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_denomination_order_and_assets(failures)
	_test_exact_integer_round_trip(failures)
	_test_compact_display_selection(failures)
	_test_drawer_icon_selection(failures)
	return failures


static func _test_denomination_order_and_assets(failures: Array[String]) -> void:
	if not (
		CurrencyDisplay.RED_CRYSTAL_GOLD
		< CurrencyDisplay.YELLOW_CRYSTAL_GOLD
		and CurrencyDisplay.YELLOW_CRYSTAL_GOLD
		< CurrencyDisplay.GRAY_CRYSTAL_GOLD
	):
		failures.append("red, yellow, and gray crystals must represent increasing gold values")
	for path in [
		CurrencyDisplay.RED_CRYSTAL_ICON_PATH,
		CurrencyDisplay.YELLOW_CRYSTAL_ICON_PATH,
		CurrencyDisplay.GRAY_CRYSTAL_ICON_PATH
	]:
		if not ResourceLoader.exists(path):
			failures.append("currency denomination asset must remain importable: %s" % path)


static func _test_exact_integer_round_trip(failures: Array[String]) -> void:
	var mixed_value := 1_234_567_890_123
	var parts := CurrencyDisplay.decompose(mixed_value)
	if (
		int(parts.get(CurrencyDisplay.GRAY_CRYSTAL_KIND, -1)) != 1
		or int(parts.get(CurrencyDisplay.YELLOW_CRYSTAL_KIND, -1)) != 234
		or int(parts.get(CurrencyDisplay.RED_CRYSTAL_KIND, -1)) != 567
		or int(parts.get(CurrencyDisplay.GOLD_KIND, -1)) != 890_123
	):
		failures.append("currency decomposition must use exact integer crystal denominations")
	if CurrencyDisplay.compose(parts) != mixed_value:
		failures.append("display denominations must reconstruct the unchanged underlying gold value")
	var maximum_parts := CurrencyDisplay.decompose(CurrencyDisplay.MAX_GOLD)
	if CurrencyDisplay.compose(maximum_parts) != CurrencyDisplay.MAX_GOLD:
		failures.append("currency conversion must remain exact at the supported save maximum")
	if CurrencyDisplay.add_gold(CurrencyDisplay.MAX_GOLD - 5, 10) != CurrencyDisplay.MAX_GOLD:
		failures.append("gold rewards must saturate safely instead of overflowing the saved balance")
	if CurrencyDisplay.add_gold(5, -10) != 0:
		failures.append("gold spending must saturate safely instead of producing a negative balance")


static func _test_compact_display_selection(failures: Array[String]) -> void:
	var cases := {
		999_999: "$ 999999",
		1_000_000: "1 RC",
		1_250_000_000: "1.25 YC",
		1_250_000_000_000: "1.25 GC"
	}
	for gold_value in cases:
		var actual := CurrencyDisplay.format_compact(int(gold_value))
		if actual != String(cases[gold_value]):
			failures.append("currency display expected %s, got %s" % [cases[gold_value], actual])


static func _test_drawer_icon_selection(failures: Array[String]) -> void:
	var drawer := SideDrawer.new()
	drawer.call("_create_drawer_window")
	drawer.refresh_coins(1_250_000_000)
	var label := drawer.get("_coin_value_label") as Label
	var icon := drawer.get("_coin_icon") as TextureRect
	if label == null or label.text != "1.25 YC":
		failures.append("the drawer must replace billion-scale gold text with yellow crystals")
	if icon == null or not (icon.texture is AtlasTexture):
		failures.append("the drawer must show a denomination sprite beside the currency amount")
	else:
		var atlas := icon.texture as AtlasTexture
		if atlas.atlas == null or atlas.atlas.resource_path != CurrencyDisplay.YELLOW_CRYSTAL_ICON_PATH:
			failures.append("the drawer must select the yellow crystal asset for billion-scale gold")
	drawer.free()
