extends RefCounted

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const TurretCatalog = preload("res://scripts/domain/turret_catalog.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const TurretActor = preload("res://scripts/turret_actor.gd")
const Main = preload("res://scripts/main.gd")


class TowerProbe extends Node2D:
	var turret_id := "turret1"
	var durability := 10.0
	var defeated := false

	func get_turret_id() -> String:
		return turret_id

	func set_durability(current_hp: float, _maximum_hp: float) -> void:
		durability = current_hp

	func receive_battle_hit(_knockback := 0.0) -> void:
		pass

	func hide_for_battle_defeat() -> void:
		defeated = true


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_turret_catalog(failures)
	_test_turret_grounding(failures)
	_test_turret_interaction_feedback(failures)
	_test_shop_categories(failures)
	_test_purchase_deploy_and_recall(failures)
	_test_battle_durability_and_destruction(failures)
	return failures


static func _test_turret_catalog(failures: Array[String]) -> void:
	var previous_price := 0
	for turret_id_value in TurretCatalog.TURRET_IDS:
		var turret_id := String(turret_id_value)
		var definition := TurretCatalog.get_definition(turret_id)
		var price := int(definition.get("price", 0))
		if definition.is_empty() or String(definition.get("kind", "")) != TurretCatalog.KIND:
			failures.append("%s must remain a recognized tower shop item" % turret_id)
		if price <= previous_price or price < 100_000:
			failures.append("tower prices must stay strictly increasing and be mid-game expensive")
		if float(definition.get("max_health", 0.0)) <= 0.0 or float(definition.get("damage", 0.0)) <= 0.0:
			failures.append("%s must provide durability and combat damage" % turret_id)
		if not FileAccess.file_exists(String(definition.get("texture", ""))):
			failures.append("%s must point at an imported furniture texture" % turret_id)
		previous_price = price

	var forged := TurretCatalog.normalize_turret({"id": "turret1", "kind": "food", "price": 1})
	if int(forged.get("price", 0)) != int(TurretCatalog.get_definition("turret1").get("price", 0)):
		failures.append("tower normalization must reject a forged low price")
	var inflated := TurretCatalog.normalize_turret({"id": "turret1", "price": 999_999_999})
	if int(inflated.get("price", 0)) != int(TurretCatalog.get_definition("turret1").get("price", 0)):
		failures.append("tower normalization must retain its fixed catalog price")
	if not TurretCatalog.normalize_turret({"id": "missing_turret"}).is_empty():
		failures.append("unknown tower ids must be rejected")


static func _test_turret_grounding(failures: Array[String]) -> void:
	var tower := TurretActor.new()
	var window_size := Vector2i(900, 600)
	tower.setup("turret1", Vector2(320.0, 40.0), window_size)
	var visual_size: Vector2 = tower.call("_get_visual_size")
	if not is_equal_approx(tower.position.y + visual_size.y * 0.5, float(window_size.y)):
		failures.append("a tower base must sit flush on the taskbar contact line")
	var dragged_position: Vector2 = tower.call("_clamp_to_window", Vector2(480.0, 20.0))
	if not is_equal_approx(dragged_position.y, tower.position.y):
		failures.append("tower dragging must keep its Y axis fixed to the desktop ground")
	tower.free()


static func _test_turret_interaction_feedback(failures: Array[String]) -> void:
	var tower := TurretActor.new()
	tower.setup("turret1", Vector2(320.0, 40.0), Vector2i(900, 600))
	tower.set_language("zh")
	tower.call("_set_pointer_hovered", true)
	var hint := tower.get("_interaction_hint") as PanelContainer
	var title_label := tower.get("_interaction_hint_title_label") as Label
	var action_label := tower.get("_interaction_hint_action_label") as Label
	if hint == null or title_label == null or action_label == null:
		failures.append("a deployed tower must create a reusable interaction hint")
	elif not hint.visible:
		failures.append("tower interaction feedback must appear while it is hovered")
	elif not ("耐久" in title_label.text) or not ("左键拖动" in action_label.text):
		failures.append("tower hover feedback must explain durability, drag, and recall")

	tower.set_battle_mode(true)
	if action_label != null and not ("战斗中不可移动" in action_label.text):
		failures.append("tower feedback must explain why movement is locked during battle")
	tower.free()


static func _test_shop_categories(failures: Array[String]) -> void:
	var shop := ShopWindow.new()
	shop.setup()
	var goods := OfferingCatalog.make_shop_goods()
	goods.append_array(TurretCatalog.make_shop_goods())
	shop.set_goods(goods)

	var food_tab := shop.get_node_or_null("ShopRoot/ShopCategoryTabs/OfferingCategoryTab") as TextureButton
	var tower_tab := shop.get_node_or_null("ShopRoot/ShopCategoryTabs/TurretCategoryTab") as TextureButton
	var furniture_tab := shop.get_node_or_null("ShopRoot/ShopCategoryTabs/FurnitureCategoryTab") as TextureButton
	if food_tab == null or tower_tab == null or furniture_tab == null:
		failures.append("the shop must provide separate food, tower, and furniture category tabs")
	elif tower_tab.position.x >= ShopWindow.PAGE_ORIGIN.x or tower_tab.position.x + tower_tab.size.x <= ShopWindow.PAGE_ORIGIN.x:
		failures.append("the tower tab must protrude from and overlap the shop page edge")
	elif tower_tab.texture_normal == null or tower_tab.texture_normal.resource_path != "res://assets/ui/newElements/书签.png":
		failures.append("shop category tabs must reuse the side-menu bookmark art")
	else:
		var hover_left := tower_tab.position.x + tower_tab.pivot_offset.x * (1.0 - ShopWindow.CATEGORY_TAB_HOVER_SCALE)
		if hover_left < 0.0:
			failures.append("shop bookmark hover must remain inside the transparent window gutter")
		if tower_tab.position.x + tower_tab.size.x < ShopWindow.PAGE_ORIGIN.x + ShopWindow.CATEGORY_TAB_PAGE_OVERLAP:
			failures.append("shop bookmarks must visibly overlap the shop edge")

	var passthrough := shop.mouse_passthrough_polygon
	var expected_page_x := ShopWindow.PAGE_ORIGIN.x * float(shop.size.x) / float(ShopWindow.WINDOW_SIZE.x)
	if passthrough.size() < 8 or not is_equal_approx(passthrough[0].x, expected_page_x):
		failures.append("shop tab hit regions must scale with the native shop window")
	_assert_category_tab_edge_hit_coverage(shop, food_tab, "Offering", failures)
	_assert_category_tab_edge_hit_coverage(shop, tower_tab, "Turret", failures)
	_assert_category_tab_edge_hit_coverage(shop, furniture_tab, "Furniture", failures)

	shop.set("_active_category", ShopWindow.FURNITURE_KIND)
	shop.call("_refresh_page")
	var empty_panel := shop.get_node_or_null("ShopRoot/ShopPage/EmptyCategoryPanel") as PanelContainer
	var furniture_page_label := shop.get("_page_label") as Label
	var furniture_slots: Array = shop.get("_slot_controls")
	if empty_panel == null or not empty_panel.visible:
		failures.append("the empty furniture category must show a deliberate coming-soon state")
	if furniture_page_label == null or furniture_page_label.text != "1/1":
		failures.append("the empty furniture category must keep the compact page indicator stable")
	for slot_value in furniture_slots:
		var furniture_slot := slot_value as Control
		if furniture_slot != null and furniture_slot.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			failures.append("empty furniture cards must not emit purchase input")
			break
	shop.set_goods(goods)
	if String(shop.get("_active_category")) != ShopWindow.FURNITURE_KIND:
		failures.append("a shop state sync must not force the empty furniture category back to food")

	shop.set("_active_category", TurretCatalog.KIND)
	shop.call("_refresh_page")
	var page_label := shop.get("_page_label") as Label
	var owned_labels: Array = shop.get("_slot_owned_labels")
	var price_labels: Array = shop.get("_slot_price_labels")
	var action_labels: Array = shop.get("_slot_action_labels")
	var slot_controls: Array = shop.get("_slot_controls")
	if page_label == null or page_label.text != "1/1":
		failures.append("the tower category must paginate its four towers independently")
	if owned_labels.is_empty() or String((owned_labels[0] as Label).text) != "BUY":
		failures.append("an unowned tower card must present a purchase action")
	if action_labels.is_empty() or not ("CLICK TO BUY" in String((action_labels[0] as Label).text)):
		failures.append("an unowned tower card must visibly tell the player to click to buy and deploy")
	if slot_controls.is_empty() or (slot_controls[0] as Control).mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		failures.append("tower shop cards must expose a pointing-hand cursor across their full card")

	shop.set_turret_states({
		"turret1": {"owned": true, "deployed": true, "current_hp": 19.0}
	})
	if String((owned_labels[0] as Label).text) != "RECALL":
		failures.append("a deployed tower card must present recall instead of repurchase")
	if not ("CLICK TO RECALL" in String((action_labels[0] as Label).text)):
		failures.append("a deployed tower card must visibly tell the player how to recall it")
	if price_labels.is_empty() or not ("DURABILITY" in String((price_labels[0] as Label).text)):
		failures.append("an owned tower card must show its remaining durability")
	shop.set_language("zh")
	if String((owned_labels[0] as Label).text) != "收回":
		failures.append("tower card actions must localize with the shop language")
	if not ("点击收回" in String((action_labels[0] as Label).text)):
		failures.append("tower card interaction prompts must localize with the shop language")
	shop.free()


static func _assert_category_tab_edge_hit_coverage(
	shop: Window,
	visual_tab: TextureButton,
	kind_name: String,
	failures: Array[String]
) -> void:
	if shop == null or visual_tab == null:
		return
	var page_root := shop.get_node_or_null("ShopRoot/ShopPage") as Control
	var hit_layer := shop.get_node_or_null("ShopRoot/ShopCategoryTabHitAreas") as Control
	var hit_area := shop.get_node_or_null(
		"ShopRoot/ShopCategoryTabHitAreas/%sCategoryTabHitArea" % kind_name
	) as Control
	if page_root == null or hit_layer == null or hit_area == null:
		failures.append("shop %s bookmark must expose a dedicated rectangular hit area" % kind_name)
		return
	if hit_layer.get_index() <= page_root.get_index():
		failures.append("shop %s bookmark hit layer must be later than the page in input order" % kind_name)
	if hit_area.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("shop %s bookmark hit area must stop pointer input" % kind_name)
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
				failures.append("shop %s bookmark hover edge must remain inside its hit area" % kind_name)
				break
			if not Geometry2D.is_point_in_polygon(design_point * native_scale, shop.mouse_passthrough_polygon):
				failures.append("shop %s bookmark hover edge must remain inside the native input region" % kind_name)
				break
	visual_tab.scale = original_scale


static func _test_purchase_deploy_and_recall(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	var shop := ShopWindow.new()
	shop.setup()
	shop.set_goods(TurretCatalog.make_shop_goods())
	main.set("_shop_window", shop)
	var price := int(TurretCatalog.get_definition("turret1").get("price", 0))
	main.set("_gold_coins", price)

	main.call("_on_shop_purchase_requested", "turret1")
	var states: Dictionary = main.get("_turret_states")
	var state: Dictionary = states.get("turret1", {})
	var deployed_actor := main.call("_get_desktop_turret", "turret1") as Node2D
	if not bool(state.get("owned", false)) or not bool(state.get("deployed", false)) or deployed_actor == null:
		failures.append("buying a tower must create one permanent deployed desktop actor")
	if int(main.get("_gold_coins")) != 0:
		failures.append("the first tower purchase must charge its fixed catalog price once")

	main.call("_on_shop_purchase_requested", "turret1")
	states = main.get("_turret_states")
	state = states.get("turret1", {})
	if bool(state.get("deployed", true)) or main.call("_get_desktop_turret", "turret1") != null:
		failures.append("purchasing an already deployed tower must recall it instead of duplicating it")
	if int(main.get("_gold_coins")) != 0:
		failures.append("recalling a tower must not charge or refund gold")

	main.call("_on_shop_purchase_requested", "turret1")
	states = main.get("_turret_states")
	state = states.get("turret1", {})
	if not bool(state.get("deployed", false)) or main.call("_get_desktop_turret", "turret1") == null:
		failures.append("a recalled owned tower must deploy again without another purchase")
	main.set("_shop_window", null)
	shop.free()
	main.free()


static func _test_battle_durability_and_destruction(failures: Array[String]) -> void:
	var main := Main.new()
	main.set("_persistence_enabled", false)
	main.set("_battle_active", true)
	main.set("_turret_states", {
		"turret1": {
			"owned": true,
			"deployed": true,
			"current_hp": 10.0,
			"position_x": 240.0,
			"position_y": 310.0
		}
	})
	var tower := TowerProbe.new()
	tower.position = Vector2(240.0, 310.0)
	main.add_child(tower)
	var towers: Array = main.get("_turrets")
	towers.append(tower)
	var battle := main.get("_battle_controller") as Node
	var tower_key := str(tower.get_instance_id())
	battle.set("_battle_turret_health", {tower_key: 10.0})
	battle.set("_battle_turret_max_health", {tower_key: 10.0})

	battle.call("_damage_battle_defender", tower, 3.0, 0.0)
	var states: Dictionary = main.get("_turret_states")
	var state: Dictionary = states.get("turret1", {})
	if not is_equal_approx(float(state.get("current_hp", -1.0)), 7.0):
		failures.append("battle damage must immediately persist tower durability")

	battle.call("_damage_battle_defender", tower, 20.0, 0.0)
	states = main.get("_turret_states")
	if states.has("turret1") or not tower.defeated:
		failures.append("a destroyed tower must be removed so it can be bought again")
	main.free()
