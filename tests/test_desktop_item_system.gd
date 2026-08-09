extends RefCounted

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const DesktopItemCatalog = preload("res://scripts/domain/desktop_item_catalog.gd")
const DesktopItemActor = preload("res://scripts/desktop_item_actor.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const Main = preload("res://scripts/main.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_item_catalog_assets(failures)
	_test_taskbar_grounding_and_horizontal_clamp(failures)
	_test_desktop_item_interaction_feedback(failures)
	_test_shop_item_category_and_actions(failures)
	_test_purchase_place_and_recall(failures)
	return failures


static func _test_item_catalog_assets(failures: Array[String]) -> void:
	var expected_ids := ["shovel", "coin_collector", "sofa"]
	if DesktopItemCatalog.ITEM_IDS != expected_ids:
		failures.append("the desktop item catalog must contain the three imported taskbar items")

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
		if not is_equal_approx(item.position.y + visual_size.y * 0.5, float(window_size.y)):
			failures.append("%s must sit flush on the taskbar contact line" % item_id)

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
	item.setup("shovel", Vector2(320.0, 40.0), Vector2i(900, 600))
	item.set_language("en")
	item.call("_set_pointer_hovered", true)
	var hint := item.get("_interaction_hint") as PanelContainer
	var title_label := item.get("_interaction_hint_title_label") as Label
	var action_label := item.get("_interaction_hint_action_label") as Label
	var interaction_area := item.get("_interaction_area") as Control
	if hint == null or title_label == null or action_label == null or interaction_area == null:
		failures.append("a deployed desktop item must create its interaction feedback")
	elif not hint.visible:
		failures.append("desktop item feedback must appear while it is hovered")
	elif not ("TASKBAR ALIGNED" in title_label.text):
		failures.append("desktop item feedback must explain its taskbar placement")
	elif not ("LEFT DRAG: MOVE HORIZONTALLY" in action_label.text) or not ("RIGHT CLICK: RETURN TO SHOP" in action_label.text):
		failures.append("desktop item feedback must explain horizontal dragging and shop return")
	elif interaction_area.mouse_default_cursor_shape != Control.CURSOR_MOVE:
		failures.append("desktop items must expose a move cursor for horizontal dragging")
	item.call("_set_pointer_hovered", false)
	if hint != null and hint.visible:
		failures.append("desktop item feedback must hide after the pointer leaves")
	item.free()


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
	var owned_labels: Array = shop.get("_slot_owned_labels")
	var price_labels: Array = shop.get("_slot_price_labels")
	var action_labels: Array = shop.get("_slot_action_labels")
	var slot_controls: Array = shop.get("_slot_controls")
	if page_label == null or page_label.text != "1/1":
		failures.append("the three desktop items must paginate independently in one item page")
	if owned_labels.is_empty() or String((owned_labels[0] as Label).text) != "BUY & PLACE":
		failures.append("an unowned desktop item must present a buy-and-place action")
	if action_labels.is_empty() or not ("CLICK TO BUY & PLACE" in String((action_labels[0] as Label).text)):
		failures.append("an unowned desktop item card must explain how to buy and place it")
	if slot_controls.is_empty() or (slot_controls[0] as Control).mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		failures.append("desktop item cards must expose a pointing-hand cursor across their full card")
	if not slot_controls.is_empty() and not ("CLICK TO BUY & PLACE" in String((slot_controls[0] as Control).tooltip_text)):
		failures.append("desktop item cards must expose their action as an interaction tooltip")

	shop.set_item_states({"shovel": {"owned": true, "deployed": true}})
	if String((owned_labels[0] as Label).text) != "RETURN TO SHOP":
		failures.append("a taskbar item card must present return-to-shop instead of repurchase")
	if not ("RETURN TO SHOP" in String((action_labels[0] as Label).text)):
		failures.append("a placed item card must clearly explain shop return")
	if price_labels.is_empty() or String((price_labels[0] as Label).text) != "ON TASKBAR":
		failures.append("a placed item card must show that it is on the taskbar")

	shop.set_item_states({"shovel": {"owned": true, "deployed": false}})
	if String((owned_labels[0] as Label).text) != "PLACE ON TASKBAR":
		failures.append("a returned item card must present placement without another purchase")
	if not ("CLICK TO PLACE" in String((action_labels[0] as Label).text)):
		failures.append("a returned item card must clearly explain placement")
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
	var shop := ShopWindow.new()
	shop.setup()
	shop.set_goods(DesktopItemCatalog.make_shop_goods())
	main.set("_shop_window", shop)
	var item_id := "shovel"
	var price := int(DesktopItemCatalog.get_definition(item_id).get("price", 0))
	main.set("_gold_coins", price)

	main.call("_on_shop_purchase_requested", item_id)
	var states: Dictionary = main.get("_item_states")
	var state: Dictionary = states.get(item_id, {})
	var deployed_actor := main.call("_get_desktop_item", item_id) as Node2D
	if not bool(state.get("owned", false)) or not bool(state.get("deployed", false)) or deployed_actor == null:
		failures.append("buying an item must create one deployed taskbar actor")
	if int(main.get("_gold_coins")) != 0:
		failures.append("the first item purchase must charge its fixed catalog price once")

	main.call("_on_shop_purchase_requested", item_id)
	states = main.get("_item_states")
	state = states.get(item_id, {})
	if bool(state.get("deployed", true)) or main.call("_get_desktop_item", item_id) != null:
		failures.append("using a placed item card must return it to the shop without duplication")
	if int(main.get("_gold_coins")) != 0:
		failures.append("returning an item to the shop must not charge or refund gold")

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
