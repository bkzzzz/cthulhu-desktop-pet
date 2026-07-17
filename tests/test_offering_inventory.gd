extends RefCounted

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")
const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_catalog(failures)
	_test_normalization(failures)
	_test_shop_goods(failures)
	_test_shop_purchase_to_cursor(failures)
	_test_pet_specific_timed_buff(failures)
	_test_removed_altar_api(failures)
	return failures


static func _test_catalog(failures: Array[String]) -> void:
	var seen_ids := {}
	var previous_price := 0
	var previous_multiplier := 1.0
	for item_value in OfferingCatalog.ITEMS:
		var item: Dictionary = item_value
		var offering_id := String(item.get("id", ""))
		if offering_id.is_empty() or seen_ids.has(offering_id):
			failures.append("every shop offering must have a unique stable id")
		seen_ids[offering_id] = true

		if String(item.get("kind", "")) != OfferingCatalog.KIND:
			failures.append("%s must be marked as a consumable offering" % offering_id)
		var texture_path := String(item.get("texture", ""))
		if texture_path.is_empty() or not FileAccess.file_exists(texture_path):
			failures.append("%s must provide a valid texture" % offering_id)
		var price := int(item.get("price", 0))
		var multiplier := float(item.get("multiplier", 1.0))
		var duration_seconds := float(item.get("duration_seconds", 0.0))
		if price <= 0 or price <= previous_price or price > 40:
			failures.append("%s must stay on the small, strictly increasing manual-coin price curve" % offering_id)
		if multiplier <= 1.0 or multiplier <= previous_multiplier:
			failures.append("%s must grant a larger production multiplier than cheaper food" % offering_id)
		if duration_seconds < 45.0 or duration_seconds > 75.0:
			failures.append("%s boost duration must stay around one minute" % offering_id)
		if item.has("faith"):
			failures.append("%s must not retain the removed instant faith refund" % offering_id)
		previous_price = price
		previous_multiplier = multiplier
		if String(item.get("description", "")).is_empty():
			failures.append("%s must explain how the consumable is used" % offering_id)
		if item.has("faith_min") or item.has("faith_max") or item.has("stock_id"):
			failures.append("%s must not retain randomized altar stock fields" % offering_id)

	if seen_ids.size() < 10:
		failures.append("the shop must sell at least ten different offering foods")
	if int(OfferingCatalog.ITEMS[0].get("price", 0)) > 2:
		failures.append("the first offering must be affordable with only a few R coins")

	var copied_goods := OfferingCatalog.make_shop_goods()
	if copied_goods.size() != OfferingCatalog.ITEMS.size():
		failures.append("the shop offering factory must return every catalog item")
	elif not copied_goods.is_empty():
		copied_goods[0]["name"] = "mutated"
		var original: Dictionary = OfferingCatalog.ITEMS[0]
		if String(original.get("name", "")) == "mutated":
			failures.append("shop goods must be deep copies of immutable catalog data")


static func _test_normalization(failures: Array[String]) -> void:
	var normalized := OfferingCatalog.normalize_offering({
		"id": "red_fruit",
		"kind": "forged",
		"name": "免费大餐",
		"texture": "res://missing.png",
		"price": 0,
		"faith": 999999,
		"multiplier": 999.0,
		"duration_seconds": 999.0,
		"purchase_price": 8,
		"favor_gain": 999,
		"stock_id": "legacy"
	})
	if not OfferingCatalog.is_offering(normalized):
		failures.append("known legacy offerings must normalize into shop consumables")
	if String(normalized.get("name", "")) != "红果":
		failures.append("normalization must restore trusted catalog presentation")
	if not is_equal_approx(float(normalized.get("multiplier", 0.0)), 2.0):
		failures.append("normalization must restore the trusted production multiplier")
	if not is_equal_approx(float(normalized.get("duration_seconds", 0.0)), 60.0):
		failures.append("normalization must restore the trusted one-minute duration")
	if int(normalized.get("purchase_price", -1)) != 8:
		failures.append("normalization must preserve the exact paid price for cancellation")
	for removed_key in ["faith", "favor_gain", "stock_id", "faith_min", "faith_max"]:
		if normalized.has(removed_key):
			failures.append("normalized offerings must discard old altar field %s" % removed_key)
	if not OfferingCatalog.normalize_offering({"id": "unknown"}).is_empty():
		failures.append("unknown offering ids must be rejected")
	if OfferingCatalog.is_offering({"id": "red_fruit", "kind": "durable"}):
		failures.append("durable shop goods must not be mistaken for offerings")


static func _test_shop_goods(failures: Array[String]) -> void:
	var shop := ShopWindow.new()
	var goods: Array[Dictionary] = shop.call("_make_default_goods")
	var offering_count := 0
	for good in goods:
		var good_id := String(good.get("id", ""))
		if good_id == "seed1":
			failures.append("the dream seed must be removed from the offering shop")
		if OfferingCatalog.is_offering(good):
			offering_count += 1
	if offering_count != OfferingCatalog.ITEMS.size():
		failures.append("the default shop must list every offering food")

	shop.set_goods(goods)
	var fish := shop.get_good("fish")
	if not OfferingCatalog.is_offering(fish):
		failures.append("shop normalization must preserve valid offering metadata")
	if float(fish.get("multiplier", 0.0)) <= 1.0 or int(fish.get("price", 0)) > 40:
		failures.append("shop lookup must preserve the affordable timed boost metadata")
	shop.free()


static func _test_shop_purchase_to_cursor(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	var red_price := int(OfferingCatalog.ITEMS[0].get("price", 0))
	var starting_gold := red_price + 20
	main.set("_gold_coins", starting_gold)
	main.set("_faith_points", 23.0)
	main.set("_lifetime_faith", 17.0)
	var shop := ShopWindow.new()
	shop.setup()
	main.set("_shop_window", shop)

	main.call("_on_shop_purchase_requested", "red_fruit")
	var carried: Dictionary = main.get("_carried_offering")
	if String(carried.get("id", "")) != "red_fruit":
		failures.append("buying an offering must immediately put that food on the cursor")
	if int(carried.get("purchase_price", -1)) != red_price or int(main.get("_gold_coins")) != starting_gold - red_price:
		failures.append("buying a cursor offering must charge its exact gold price once")
	if not is_equal_approx(float(main.get("_faith_points")), 23.0):
		failures.append("shop purchases must not spend faith")
	var owned_counts: Dictionary = main.get("_shop_owned_counts")
	if owned_counts.has("red_fruit"):
		failures.append("consumable offerings must not enter the durable owned-count inventory")

	main.call("_on_shop_purchase_requested", "fish")
	if int(main.get("_gold_coins")) != starting_gold - red_price:
		failures.append("the shop must not charge for a second offering while one is already carried")
	var refused_carried: Dictionary = main.get("_carried_offering")
	if String(refused_carried.get("id", "")) != "red_fruit":
		failures.append("a refused second offering must not replace the carried food")

	main.call("_cancel_carried_offering")
	var cancelled_carried: Dictionary = main.get("_carried_offering")
	if not cancelled_carried.is_empty():
		failures.append("right-click cancellation must clear the carried offering")
	if int(main.get("_gold_coins")) != starting_gold:
		failures.append("cancelling before placement must refund the exact purchase price")
	if not is_equal_approx(float(main.get("_lifetime_faith")), 17.0):
		failures.append("an offering refund must not inflate lifetime-generated faith")

	main.set("_shop_window", null)
	shop.free()
	main.free()


static func _test_pet_specific_timed_buff(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	var base_rate: float = main.call("_get_faith_growth_rate")
	var pet1_rate: float = main.call("_get_pet_faith_per_second", "pet1", 1)
	var offering: Dictionary = OfferingCatalog.normalize_offering({"id": "red_fruit"})
	main.call("_apply_pet_offering_buff", "pet1", offering)
	var boosted_rate: float = main.call("_get_faith_growth_rate")
	if not is_equal_approx(boosted_rate, base_rate + pet1_rate):
		failures.append("an offering must multiply only the fed pet's faith production")
	if not is_equal_approx(float(main.call("_get_pet_offering_multiplier", "pet1")), 2.0):
		failures.append("feeding must activate the catalog multiplier on the target pet")
	if not is_equal_approx(float(main.call("_get_pet_offering_multiplier", "pet2")), 1.0):
		failures.append("feeding one pet must not boost any other pet")
	var buffs: Dictionary = main.get("_pet_offering_buffs")
	var pet1_buff: Dictionary = buffs.get("pet1", {})
	pet1_buff["expires_at"] = float(main.call("_get_now_seconds")) - 1.0
	main.call("_update_pet_offering_buffs")
	if not is_equal_approx(float(main.call("_get_faith_growth_rate")), base_rate):
		failures.append("an expired offering boost must restore the pet's normal production")
	main.free()


static func _test_removed_altar_api(failures: Array[String]) -> void:
	var drawer := SideDrawer.new()
	if drawer.has_signal("offering_drop_requested"):
		failures.append("the side drawer must not expose the removed altar selection signal")
	for method_name in [
		"get_offering_state",
		"restore_offering_state",
		"complete_offering_choice",
		"return_offering",
		"_generate_offering_choice",
		"_open_cult_window",
		"_on_altar_pressed"
	]:
		if drawer.has_method(method_name):
			failures.append("the side drawer must remove old altar method %s" % method_name)
	drawer.call("_create_toggle_button")
	var menu_window := drawer.get("_menu_window") as Window
	if menu_window == null:
		failures.append("the compact desktop menu handle must still be created")
	elif menu_window.get_node_or_null("MenuHandleRoot/CultAltar") != null:
		failures.append("the compact desktop menu handle must not contain an altar node")
	drawer.free()
