extends RefCounted

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const DesktopItemCatalog = preload("res://scripts/domain/desktop_item_catalog.gd")
const DesktopItemActor = preload("res://scripts/desktop_item_actor.gd")
const CoinCollectorShovel = preload("res://scripts/coin_collector_shovel.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const Main = preload("res://scripts/main.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")

const ITEM_MENU_SIZE_TOLERANCE := 12.0
const EXPECTED_ITEM_SCALES := {
	"coin_collector": 0.70,
	"sofa": 0.64
}
const EXPECTED_ITEM_X_FRACTIONS := {
	"coin_collector": 0.42,
	"sofa": 0.72
}


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_item_catalog_assets(failures)
	_test_taskbar_grounding_and_horizontal_clamp(failures)
	_test_desktop_item_interaction_feedback(failures)
	_test_coin_collector_automation(failures)
	_test_shop_item_category_and_actions(failures)
	_test_purchase_place_and_recall(failures)
	return failures


static func _test_item_catalog_assets(failures: Array[String]) -> void:
	var expected_ids := ["coin_collector", "sofa"]
	if DesktopItemCatalog.ITEM_IDS != expected_ids:
		failures.append("the desktop item catalog must contain only the two purchasable taskbar items")
	if DesktopItemCatalog.has_item("shovel"):
		failures.append("the shovel must remain a coin-collector component, not a shop item")
	if not FileAccess.file_exists(CoinCollectorShovel.SHOVEL_TEXTURE):
		failures.append("the coin collector's shovel component must use the imported shovel asset")

	for item_id_value in DesktopItemCatalog.ITEM_IDS:
		var item_id := String(item_id_value)
		var definition := DesktopItemCatalog.get_definition(item_id)
		var texture_path := String(definition.get("texture", ""))
		if definition.is_empty() or String(definition.get("kind", "")) != DesktopItemCatalog.KIND:
			failures.append("%s must remain a recognized desktop item" % item_id)
			continue
		if not texture_path.begins_with("res://assets/furniture/shopItems/"):
			failures.append("%s must use an imported shop-item texture" % item_id)
		elif not FileAccess.file_exists(texture_path) or load(texture_path) == null:
			failures.append("%s must point at a loadable imported texture" % item_id)
		if int(definition.get("price", 0)) <= 0:
			failures.append("%s must have a positive fixed catalog price" % item_id)
		if float(definition.get("visual_scale", 0.0)) <= 0.0:
			failures.append("%s must define a visible desktop scale" % item_id)
		if not is_equal_approx(
			float(definition.get("visual_scale", 0.0)),
			float(EXPECTED_ITEM_SCALES.get(item_id, 0.0))
		):
			failures.append("%s must use the calibrated taskbar visual scale" % item_id)
		if not is_equal_approx(
			float(definition.get("default_x_fraction", -1.0)),
			float(EXPECTED_ITEM_X_FRACTIONS.get(item_id, -1.0))
		):
			failures.append("%s must use its calibrated default taskbar position" % item_id)

	var first_id := String(expected_ids[0])
	var forged := DesktopItemCatalog.normalize_item({"id": first_id, "kind": "food", "price": 1})
	if int(forged.get("price", 0)) != int(DesktopItemCatalog.get_definition(first_id).get("price", 0)):
		failures.append("desktop item normalization must reject forged prices")
	if not DesktopItemCatalog.normalize_item({"id": "missing_item"}).is_empty():
		failures.append("unknown desktop item ids must be rejected")


static func _test_taskbar_grounding_and_horizontal_clamp(failures: Array[String]) -> void:
	var window_size := Vector2i(1200, 720)
	for item_id_value in DesktopItemCatalog.ITEM_IDS:
		var item_id := String(item_id_value)
		var item := DesktopItemActor.new()
		item.setup(item_id, Vector2(480.0, 20.0), window_size)
		var visual_size: Vector2 = item.call("_get_visual_size")
		var definition := item.get_item_definition()
		var texture := load(String(definition.get("texture", ""))) as Texture2D
		if not is_equal_approx(item.position.y + visual_size.y * 0.5, float(window_size.y)):
			failures.append("%s must sit flush on the taskbar contact line" % item_id)
		if absf(visual_size.x - SideDrawer.MENU_ICON_SIZE.x) > ITEM_MENU_SIZE_TOLERANCE \
		or absf(visual_size.y - SideDrawer.MENU_ICON_SIZE.y) > ITEM_MENU_SIZE_TOLERANCE:
			failures.append("%s must remain within 12 px of the menu summon handle size" % item_id)
		if texture == null:
			failures.append("%s must retain a texture for taskbar grounding" % item_id)
		else:
			var image := texture.get_image()
			if image == null or not _has_opaque_bottom_pixel(image):
				failures.append("%s must retain opaque pixels on its bottom canvas row" % item_id)
			else:
				var visible_bottom := item.position.y + _get_opaque_bottom_offset(
					texture,
					float(definition.get("visual_scale", 1.0))
				)
				if not is_equal_approx(visible_bottom, float(window_size.y)):
					failures.append("%s opaque visual base must meet the taskbar without a gap" % item_id)

		var left_clamp: Vector2 = item.call("_clamp_to_window", Vector2(-10_000.0, -10_000.0))
		var horizontal_move: Vector2 = item.call("_clamp_to_window", Vector2(680.0, 40.0))
		var right_clamp: Vector2 = item.call("_clamp_to_window", Vector2(10_000.0, 10_000.0))
		if not is_equal_approx(left_clamp.y, item.position.y) or not is_equal_approx(horizontal_move.y, item.position.y) or not is_equal_approx(right_clamp.y, item.position.y):
			failures.append("%s must keep a fixed taskbar Y position while dragged" % item_id)
		if left_clamp.x < visual_size.x * 0.5 - 0.01 or right_clamp.x > float(window_size.x) - visual_size.x * 0.5 + 0.01:
			failures.append("%s must remain fully inside the desktop horizontally" % item_id)
		if not is_equal_approx(horizontal_move.x, 680.0):
			failures.append("%s must allow a horizontal position change away from its edges" % item_id)
		item.free()


static func _test_desktop_item_interaction_feedback(failures: Array[String]) -> void:
	var item := DesktopItemActor.new()
	item.setup("coin_collector", Vector2(320.0, 40.0), Vector2i(900, 600))
	item.set_language("en")
	item.call("_set_pointer_hovered", true)
	var hint := item.get("_interaction_hint") as PanelContainer
	var action_label := item.get("_interaction_hint_action_label") as Label
	var interaction_area := item.get("_interaction_area") as Control
	if hint == null or action_label == null or interaction_area == null:
		failures.append("a deployed desktop item must create its interaction feedback")
	elif not hint.visible:
		failures.append("desktop item feedback must appear while it is hovered")
	elif action_label.text != "DRAG HORIZONTALLY  ·  RIGHT-CLICK TO RETURN":
		failures.append("desktop item feedback must give one concise drag-and-return hint")
	elif interaction_area.mouse_default_cursor_shape != Control.CURSOR_MOVE:
		failures.append("desktop items must expose a move cursor for horizontal dragging")
	item.call("_set_pointer_hovered", false)
	if hint != null and hint.visible:
		failures.append("desktop item feedback must hide after the pointer leaves")
	item.free()


static func _test_coin_collector_automation(failures: Array[String]) -> void:
	var collector := DesktopItemActor.new()
	collector.setup("coin_collector", Vector2(520.0, 40.0), Vector2i(960, 600))
	var shovel := CoinCollectorShovel.new()
	collector.add_child(shovel)
	shovel.setup()
	var shovel_sprite := shovel.get_node_or_null("CoinCollectorShovelSprite") as Sprite2D
	if shovel_sprite == null:
		failures.append("a deployed coin collector must create its shovel animation component")
	else:
		var collector_texture := load(String(collector.get_item_definition().get("texture", ""))) as Texture2D
		var collector_sprite := collector.get_node_or_null("DesktopItemSprite") as Sprite2D
		if collector_texture == null or collector_sprite == null or shovel_sprite.texture == null:
			failures.append("the collector and shovel must expose grounded sprite textures")
		else:
			var collector_bottom := collector.position.y + _get_opaque_bottom_offset(
				collector_texture,
				float(collector.get_item_definition().get("visual_scale", 1.0))
			)
			var shovel_bottom := collector.position.y + shovel.position.y + shovel_sprite.position.y \
				+ _get_opaque_bottom_offset(shovel_sprite.texture, absf(shovel_sprite.scale.y))
			if not is_equal_approx(shovel_bottom, collector_bottom) or not is_equal_approx(shovel_bottom, 600.0):
				failures.append("the shovel's actual opaque bottom must share the collector taskbar baseline")
			# The baseline equation must remain correct if future item calibration
			# changes the collector scale; the shovel itself deliberately keeps its
			# authored scale so the test exercises unequal sprite dimensions too.
			var original_scale := float(collector.get_item_definition().get("visual_scale", 1.0))
			for alternate_scale in [0.46, 1.02]:
				collector.item_data["visual_scale"] = alternate_scale
				collector_sprite.scale = Vector2.ONE * alternate_scale
				collector.set_window_bounds(Vector2i(960, 600))
				shovel.call("_refresh_home_position")
				shovel_sprite.position = shovel.get("_home_position")
				collector_bottom = collector.position.y + _get_opaque_bottom_offset(
					collector_texture,
					alternate_scale
				)
				shovel_bottom = collector.position.y + shovel.position.y + shovel_sprite.position.y \
					+ _get_opaque_bottom_offset(shovel_sprite.texture, absf(shovel_sprite.scale.y))
				if not is_equal_approx(shovel_bottom, collector_bottom) or not is_equal_approx(shovel_bottom, 600.0):
					failures.append("the shovel baseline must stay grounded at every collector scale")
					break
			collector.item_data["visual_scale"] = original_scale
			collector_sprite.scale = Vector2.ONE * original_scale
			collector.set_window_bounds(Vector2i(960, 600))
			shovel.call("_refresh_home_position")
			shovel_sprite.position = shovel.get("_home_position")

	var coin := CoinDrop.new()
	coin.setup("P", Vector2(180.0, 560.0), Vector2i(960, 600), 584.0)
	coin.set("_settled", true)
	coin.set("_settled_age", CoinDrop.PICKUP_ARM_DELAY_SECONDS)
	var collected := {"value": 0}
	coin.collected.connect(func(_actor: Node2D, _type: String, value: int) -> void:
		collected["value"] = int(collected.get("value", 0)) + value
	)
	if not bool(coin.call("can_be_collected_by_collector")):
		failures.append("only visibly settled currency should be eligible for collector pickup")
	elif not shovel.begin_collection(coin):
		failures.append("the collector shovel must start a sweep for an eligible desktop coin")
	else:
		for _step in 24:
			coin.call("_process", 0.1)
		if int(collected.get("value", 0)) != CoinDrop.get_coin_value("P"):
			failures.append("collector pickup must emit the existing coin-collected reward value")
		if shovel.is_collecting():
			failures.append("the shovel must finish its cycle after the selected coin is collected")

	var manual_priority_coin := CoinDrop.new()
	manual_priority_coin.setup("R", Vector2(280.0, 560.0), Vector2i(960, 600), 584.0)
	manual_priority_coin.set("_settled", true)
	manual_priority_coin.set("_settled_age", CoinDrop.PICKUP_ARM_DELAY_SECONDS)
	manual_priority_coin.set("_magnetized", true)
	if shovel.begin_collection(manual_priority_coin):
		failures.append("a player-started mouse magnet pickup must win over a pending shovel sweep")
	manual_priority_coin.set("_magnetized", false)
	if not shovel.begin_collection(manual_priority_coin):
		failures.append("the collector must retry a coin after the manual magnet pickup is no longer active")
	else:
		shovel.cancel_collection()
		if bool(manual_priority_coin.call("is_collector_collecting")):
			failures.append("returning a collector must cancel its in-flight coin pickup")

	var moving_coin := CoinDrop.new()
	moving_coin.setup("R", Vector2(360.0, 560.0), Vector2i(960, 600), 584.0)
	moving_coin.set("_settled", true)
	moving_coin.set("_settled_age", CoinDrop.PICKUP_ARM_DELAY_SECONDS)
	if shovel.begin_collection(moving_coin):
		collector.position.x = 700.0
		shovel.call("_process", 0.016)
		var live_target: Vector2 = moving_coin.get("_collector_target")
		if not is_equal_approx(live_target.x, shovel.get_deposit_position().x):
			failures.append("an in-flight coin must retarget when its collector moves")
		moving_coin.call("retarget_collector_collection", Vector2(-500.0, 10_000.0))
		var bounded_target: Vector2 = moving_coin.get("_collector_target")
		if bounded_target.x < 18.0 or bounded_target.y > 566.0:
			failures.append("collector retargeting must remain inside the current desktop bounds")
		# Simulate the production fallback cancelling a coin directly after the
		# transfer began. The shovel must release its busy state too.
		moving_coin.call("cancel_collector_collection")
		shovel.call("_process", 0.016)
		if shovel.is_collecting():
			failures.append("external post-transfer coin cancellation must not leave the shovel busy")
	else:
		failures.append("the collector must remain reusable for moving-target pickup")

	var visual_coin := CoinDrop.new()
	visual_coin.setup("G", Vector2(420.0, 560.0), Vector2i(960, 600), 584.0)
	visual_coin.configure_celebration(Vector2.ZERO)
	if bool(visual_coin.call("can_be_collected_by_collector")):
		failures.append("collector pickup must skip zero-value battle celebration visuals")
	coin.free()
	manual_priority_coin.free()
	moving_coin.free()
	visual_coin.free()
	collector.free()


static func _test_shop_item_category_and_actions(failures: Array[String]) -> void:
	var shop := ShopWindow.new()
	shop.setup()
	var goods := OfferingCatalog.make_shop_goods()
	goods.append_array(DesktopItemCatalog.make_shop_goods())
	shop.set_goods(goods)
	shop.set_coin_balance(100_000)
	shop.set_language("en")

	if ShopWindow.SHOP_CATEGORIES.size() != 2 or not ShopWindow.SHOP_CATEGORIES.has(ShopWindow.ITEM_KIND):
		failures.append("the shop must expose food and item categories only")
	var category_buttons: Dictionary = shop.get("_category_buttons")
	var food_tab := category_buttons.get(OfferingCatalog.KIND) as TextureButton
	var item_tab := category_buttons.get(ShopWindow.ITEM_KIND) as TextureButton
	if food_tab == null or item_tab == null:
		failures.append("the shop must provide a dedicated item bookmark")
	elif item_tab.position.x >= ShopWindow.PAGE_ORIGIN.x or item_tab.position.x + item_tab.size.x <= ShopWindow.PAGE_ORIGIN.x:
		failures.append("the item bookmark must protrude from and overlap the shop page edge")
	elif item_tab.texture_normal == null:
		failures.append("the item bookmark must use the shop bookmark art")
	else:
		var item_tab_label := item_tab.get_node_or_null("CategoryLabel") as Label
		if item_tab_label == null or item_tab_label.text != "ITEMS":
			failures.append("the item bookmark must have a clear item label")
		_assert_category_tab_edge_hit_coverage(shop, item_tab, "items", failures)

	shop.set("_active_category", ShopWindow.ITEM_KIND)
	shop.call("_refresh_page")
	var page_label := shop.get("_page_label") as Label
	var price_labels: Array = shop.get("_slot_price_labels")
	var action_labels: Array = shop.get("_slot_action_labels")
	var slot_controls: Array = shop.get("_slot_controls")
	if page_label == null or page_label.text != "1/1":
		failures.append("the two desktop items must paginate independently in one item page")
	if action_labels.is_empty() or String((action_labels[0] as Label).text) != "BUY & PLACE":
		failures.append("an unowned desktop item must present the shared buy-and-place action row")
	if slot_controls.is_empty() or (slot_controls[0] as Control).mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		failures.append("desktop item cards must expose a pointing-hand cursor across their full card")

	shop.set_item_states({"coin_collector": {"owned": true, "deployed": true}})
	if String((action_labels[0] as Label).text) != "RETURN TO SHOP":
		failures.append("a placed item card must present return-to-shop instead of repurchase")
	if price_labels.is_empty() or String((price_labels[0] as Label).text) != "OWNED":
		failures.append("a placed item card must share the owned price presentation with the unified shop")

	shop.set_item_states({"coin_collector": {"owned": true, "deployed": false}})
	if String((action_labels[0] as Label).text) != "PLACE ON TASKBAR":
		failures.append("a returned item card must present placement without another purchase")
	shop.free()


static func _assert_category_tab_edge_hit_coverage(
	shop: Window,
	visual_tab: TextureButton,
	kind_label: String,
	failures: Array[String]
) -> void:
	if shop == null or visual_tab == null:
		return
	var page_root := shop.get_node_or_null("ShopRoot/ShopPage") as Control
	var hit_layer := shop.get_node_or_null("ShopRoot/ShopCategoryTabHitAreas") as Control
	var hit_area := hit_layer.get_node_or_null("%sHitArea" % visual_tab.name) as Control if hit_layer != null else null
	if page_root == null or hit_layer == null or hit_area == null:
		failures.append("shop %s bookmark must expose a dedicated rectangular hit area" % kind_label)
		return
	if hit_layer.get_index() <= page_root.get_index():
		failures.append("shop %s bookmark hit layer must be later than the page in input order" % kind_label)
	if hit_area.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("shop %s bookmark hit area must stop pointer input" % kind_label)
		return
	var original_scale := visual_tab.scale
	visual_tab.scale = Vector2.ONE * ShopWindow.CATEGORY_TAB_HOVER_SCALE
	var visual_rect := Rect2(
		visual_tab.position + visual_tab.pivot_offset * (Vector2.ONE - visual_tab.scale),
		visual_tab.size * visual_tab.scale
	)
	var hit_rect := Rect2(hit_area.position, hit_area.size)
	var native_scale := Vector2(
		float(shop.size.x) / float(ShopWindow.WINDOW_SIZE.x),
		float(shop.size.y) / float(ShopWindow.WINDOW_SIZE.y)
	)
	for y_factor in [0.02, 0.5, 0.98]:
		for x_factor in [0.02, 0.5, 0.98]:
			var design_point := visual_rect.position + visual_rect.size * Vector2(x_factor, y_factor)
			if not hit_rect.has_point(design_point):
				failures.append("shop %s bookmark hover edge must remain inside its hit area" % kind_label)
				break
			if not Geometry2D.is_point_in_polygon(design_point * native_scale, shop.mouse_passthrough_polygon):
				failures.append("shop %s bookmark hover edge must remain inside the native input region" % kind_label)
				break
	visual_tab.scale = original_scale


static func _test_purchase_place_and_recall(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_pet_window_size", Vector2i(900, 600))
	main.set("_language", "en")
	var shop := ShopWindow.new()
	shop.setup()
	shop.set_language("en")
	shop.set_goods(DesktopItemCatalog.make_shop_goods())
	main.set("_shop_window", shop)
	var item_id := "coin_collector"
	var price := int(DesktopItemCatalog.get_definition(item_id).get("price", 0))
	main.set("_gold_coins", price)

	main.call("_on_shop_purchase_requested", item_id)
	var states: Dictionary = main.get("_item_states")
	var state: Dictionary = states.get(item_id, {})
	var deployed_actor := main.call("_get_desktop_item", item_id) as Node2D
	if not bool(state.get("owned", false)) or not bool(state.get("deployed", false)) or deployed_actor == null:
		failures.append("buying an item must create one deployed taskbar actor")
	elif deployed_actor.get_node_or_null("CoinCollectorShovel") == null:
		failures.append("buying the collector must spawn its attached shovel component")
	if int(main.get("_gold_coins")) != 0:
		failures.append("the first item purchase must charge its fixed catalog price once")
	var result_label := shop.get("_result_label") as Label
	if result_label == null or not result_label.text.begins_with("Placed ") or result_label.text.contains("drag"):
		failures.append("item purchase feedback must stay a short placement confirmation")

	main.call("_on_shop_purchase_requested", item_id)
	states = main.get("_item_states")
	state = states.get(item_id, {})
	if bool(state.get("deployed", true)) or main.call("_get_desktop_item", item_id) != null:
		failures.append("using a placed item card must return it to the shop without duplication")
	if int(main.get("_gold_coins")) != 0:
		failures.append("returning an item to the shop must not charge or refund gold")
	if result_label == null or not result_label.text.begins_with("Returned ") or result_label.text.contains("Click"):
		failures.append("item return feedback must stay a short return confirmation")

	main.call("_on_shop_purchase_requested", item_id)
	states = main.get("_item_states")
	state = states.get(item_id, {})
	if not bool(state.get("deployed", false)) or main.call("_get_desktop_item", item_id) == null:
		failures.append("a returned owned item must place again without another purchase")
	if int(main.get("_gold_coins")) != 0:
		failures.append("placing a returned owned item must not charge gold again")
	main.set("_shop_window", null)
	shop.free()
	main.free()


static func _has_opaque_bottom_pixel(image: Image) -> bool:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false
	var bottom_y := image.get_height() - 1
	for x in image.get_width():
		if image.get_pixel(x, bottom_y).a > 0.02:
			return true
	return false


static func _get_opaque_bottom_offset(texture: Texture2D, visual_scale: float) -> float:
	if texture == null:
		return 0.0
	var bottom_edge := texture.get_size().y * 0.5
	var image := texture.get_image()
	if image != null:
		var used_rect := image.get_used_rect()
		if used_rect.size.y > 0:
			bottom_edge = float(used_rect.end.y) - texture.get_size().y * 0.5
	return bottom_edge * absf(visual_scale)
