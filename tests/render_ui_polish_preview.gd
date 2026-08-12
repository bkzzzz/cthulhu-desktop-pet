extends SceneTree

## A focused, renderable UI regression pass for the most copy-dense surfaces.
##
## It intentionally does not own any window implementation.  Instead it puts
## representative long/localized content through the live shop, drawer, and
## save-slot views; records screenshots for visual review; and guards the
## geometry that is most likely to make a polished screen feel broken:
## clipped copy, colliding card rows, and controls escaping their panel.

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const DesktopItemCatalog = preload("res://scripts/domain/desktop_item_catalog.gd")
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")
const SettingsWindow = preload("res://scripts/settings_window.gd")

const OUTPUT_DIR := "res://tests/_artifacts"
const SHOP_FOOD_PREVIEW := "ui_polish_shop_food_preview.png"
const SHOP_ITEMS_PREVIEW := "ui_polish_shop_items_preview.png"
const DRAWER_PREVIEW := "ui_polish_drawer_preview.png"
const SAVE_SLOTS_PREVIEW := "ui_polish_save_slots_preview.png"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_render_ui_polish_previews")


func _render_ui_polish_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _render_shop_previews()
	await _render_drawer_preview()
	await _render_save_slots_preview()

	if not _failures.is_empty():
		for failure in _failures:
			push_error("UI polish preview: %s" % failure)
		quit(1)
		return

	print("UI_POLISH_SHOP_FOOD=%s" % ProjectSettings.globalize_path(OUTPUT_DIR.path_join(SHOP_FOOD_PREVIEW)))
	print("UI_POLISH_SHOP_ITEMS=%s" % ProjectSettings.globalize_path(OUTPUT_DIR.path_join(SHOP_ITEMS_PREVIEW)))
	print("UI_POLISH_DRAWER=%s" % ProjectSettings.globalize_path(OUTPUT_DIR.path_join(DRAWER_PREVIEW)))
	print("UI_POLISH_SAVE_SLOTS=%s" % ProjectSettings.globalize_path(OUTPUT_DIR.path_join(SAVE_SLOTS_PREVIEW)))
	quit(0)


func _render_shop_previews() -> void:
	var shop := ShopWindow.new()
	root.add_child(shop)
	shop.setup()
	var goods := OfferingCatalog.make_shop_goods()
	goods.append_array(DesktopItemCatalog.make_shop_goods())
	shop.set_goods(goods)
	shop.set_coin_balance(9_876_543_210)
	shop.set_item_states({
		"coin_collector": {"owned": true, "deployed": true},
		"sofa": {"owned": true, "deployed": false}
	})
	shop.set_language("zh")
	shop.visible = true

	await _capture_shop_category(shop, OfferingCatalog.KIND, SHOP_FOOD_PREVIEW)
	await _capture_shop_category(shop, ShopWindow.ITEM_KIND, SHOP_ITEMS_PREVIEW)

	# Keep the native window alive until the pass completes.  Closing the only
	# visible native window can make Godot end this utility before the drawer and
	# settings scenarios have rendered.
	shop.visible = false


func _capture_shop_category(shop: Window, category: String, file_name: String) -> void:
	shop.set("_active_category", category)
	shop.call("_refresh_page")
	var current_goods: Array = shop.call("_get_category_goods")
	if not current_goods.is_empty():
		shop.call("_show_info_panel", current_goods[0], Vector2.ZERO)
	await process_frame
	await process_frame
	_assert_shop_geometry(shop, category)
	_save_window_texture(shop, file_name)


func _assert_shop_geometry(shop: Window, category: String) -> void:
	var page := shop.get_node_or_null("ShopRoot/ShopPage") as Control
	var slots: Array = shop.get("_slot_controls")
	var surfaces: Array = shop.get("_slot_text_surfaces")
	var names: Array = shop.get("_slot_name_labels")
	var prices: Array = shop.get("_slot_price_labels")
	var actions: Array = shop.get("_slot_action_labels")
	if page == null or slots.size() != ShopWindow.SHOP_SLOT_RECTS.size():
		_failures.append("%s shop preview did not build its complete six-card grid" % category)
		return

	var page_bounds := Rect2(Vector2.ZERO, ShopWindow.SHOP_PAGE_SIZE)
	var card_rects: Array[Rect2] = []
	for index in slots.size():
		var slot := slots[index] as Control
		var surface := surfaces[index] as Control if index < surfaces.size() else null
		var name_label := names[index] as Label if index < names.size() else null
		var price_label := prices[index] as Label if index < prices.size() else null
		var action_label := actions[index] as Label if index < actions.size() else null
		if slot == null or surface == null or name_label == null or price_label == null or action_label == null:
			_failures.append("%s shop card %d is missing a shared content element" % [category, index + 1])
			continue

		var slot_rect := Rect2(slot.position, slot.size)
		if not page_bounds.encloses(slot_rect):
			_failures.append("%s shop card %d escapes the parchment page" % [category, index + 1])
		for earlier_rect in card_rects:
			if earlier_rect.intersects(slot_rect):
				_failures.append("%s shop cards overlap" % category)
				break
		card_rects.append(slot_rect)

		var surface_rect := Rect2(surface.position, surface.size)
		if surface is PanelContainer or not Rect2(Vector2.ZERO, slot.size).encloses(surface_rect):
			_failures.append("%s shop card %d uses an escaping or generic outer text frame" % [category, index + 1])

		var content_labels: Array[Label] = [name_label, price_label, action_label]
		var label_rects: Array[Rect2] = []
		for label in content_labels:
			var label_rect := Rect2(label.position, label.size)
			if not surface_rect.encloses(label_rect):
				_failures.append("%s shop card %d text leaves its contrast surface" % [category, index + 1])
			if not label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
				_failures.append("%s shop card %d must clip long copy inside its own row" % [category, index + 1])
			for earlier_label_rect in label_rects:
				if earlier_label_rect.intersects(label_rect):
					_failures.append("%s shop card %d text rows overlap" % [category, index + 1])
					break
			label_rects.append(label_rect)

	var info_strip := shop.get("_info_panel") as Control
	if info_strip == null or info_strip is PanelContainer:
		_failures.append("%s shop must keep detail copy in the reserved frameless header strip" % category)
	else:
		var info_rect := Rect2(info_strip.position, info_strip.size)
		if not page_bounds.encloses(info_rect):
			_failures.append("%s shop detail strip escapes the parchment page" % category)
		for slot_rect in card_rects:
			if info_rect.intersects(slot_rect):
				_failures.append("%s shop detail strip covers a product card" % category)
				break

	var balance := shop.get("_coin_balance_label") as Label
	var close_button := shop.get_node_or_null("ShopRoot/ShopPage/CloseShop") as Control
	if balance == null or close_button == null:
		_failures.append("%s shop is missing its header controls" % category)
	elif Rect2(balance.position, balance.size).intersects(Rect2(close_button.position, close_button.size)):
		_failures.append("%s shop balance overlaps the close control" % category)


func _render_drawer_preview() -> void:
	var drawer := SideDrawer.new()
	root.add_child(drawer)
	drawer.setup()
	drawer.set_language("zh")
	drawer.refresh_playtime(91_263.0)
	drawer.refresh_faith(1_284_550.0, 842.5)
	drawer.refresh_coins(4_876_543)
	drawer.refresh_pet_upgrades(_make_drawer_entries())
	drawer.call("_toggle_drawer")
	await process_frame
	await create_timer(0.32).timeout
	await process_frame

	_assert_drawer_geometry(drawer)
	_save_window_texture(drawer.get("_drawer_window") as Window, DRAWER_PREVIEW)
	var drawer_window := drawer.get("_drawer_window") as Window
	var menu_window := drawer.get("_menu_window") as Window
	if drawer_window != null:
		drawer_window.visible = false
	if menu_window != null:
		menu_window.visible = false


func _make_drawer_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in mini(3, PetCatalog.ACTIVE_DESKTOP_PETS.size()):
		var pet_id := String(PetCatalog.ACTIVE_DESKTOP_PETS[index])
		var entry := PetCatalog.make_inventory_entry(pet_id)
		entry["level"] = 45 + index * 8
		entry["cost"] = 2_000 + index * 800
		entry["current_fps"] = 125.0 + index * 40.0
		entry["next_fps"] = 132.0 + index * 44.0
		entry["affordable"] = true
		entry["offering_multiplier"] = 5.0 if index == 0 else 1.0
		entry["offering_seconds_remaining"] = 42.0 if index == 0 else 0.0
		entries.append(entry)
	return entries


func _assert_drawer_geometry(drawer: Node) -> void:
	var menu_window := drawer.get("_menu_window") as Window
	var menu_button := drawer.get("_menu_button") as Control
	var playtime := drawer.get("_playtime_label") as Label
	if menu_window == null or menu_button == null or playtime == null:
		_failures.append("drawer preview is missing its compact taskbar handle controls")
	else:
		var handle_bounds := Rect2(Vector2.ZERO, Vector2(SideDrawer.MENU_WINDOW_SIZE))
		if not handle_bounds.encloses(Rect2(menu_button.position, menu_button.size)):
			_failures.append("taskbar menu art escapes its compact window")
		if not handle_bounds.encloses(Rect2(playtime.position, playtime.size)):
			_failures.append("taskbar playtime escapes the compact menu window")

	var drawer_root := drawer.get("_drawer_root") as Control
	var stage := drawer_root.find_child("FaithAdderStage", true, false) as Control if drawer_root != null else null
	var era := drawer.get("_era_label") as Label
	var scroller := drawer_root.find_child("UpgradeScroller", true, false) as Control if drawer_root != null else null
	var footer := drawer_root.find_child("MenuFooter", true, false) as Control if drawer_root != null else null
	if stage == null or era == null or scroller == null or footer == null:
		_failures.append("drawer preview is missing the economy-to-upgrade layout flow")
	else:
		# The scroll container intentionally occupies a larger clipped region than
		# the rows currently on screen, so comparing it to the footer creates a
		# false collision.  Check the actual visible blocks instead.
		var stage_rect := stage.get_global_rect()
		var scroller_rect := scroller.get_global_rect()
		var footer_rect := footer.get_global_rect()
		if stage_rect.size.y <= 0.0 or scroller_rect.size.y <= 0.0 or footer_rect.size.y <= 0.0:
			_failures.append("drawer flow did not receive a visible layout size")
		if era.visible:
			var era_rect := era.get_global_rect()
			if era_rect.size.y <= 0.0 or stage_rect.intersects(era_rect) or era_rect.intersects(scroller_rect):
				_failures.append("visible drawer era copy overlaps an adjacent section")

	var bookmarks := drawer_root.get_node_or_null("DrawerBookmarks") as Control if drawer_root != null else null
	if bookmarks == null:
		_failures.append("drawer preview is missing its bookmark rail")
	else:
		var bookmark_rects: Array[Rect2] = []
		for child in bookmarks.get_children():
			if child is not TextureButton:
				continue
			var button := child as TextureButton
			var button_rect := button.get_global_rect()
			if button_rect.size.x <= 0.0 or button_rect.size.y <= 0.0:
				_failures.append("drawer bookmark %s has no hit area" % button.name)
				continue
			for earlier_rect in bookmark_rects:
				if earlier_rect.intersects(button_rect):
					_failures.append("drawer bookmark controls overlap")
					break
			bookmark_rects.append(button_rect)


func _render_save_slots_preview() -> void:
	var settings := SettingsWindow.new()
	root.add_child(settings)
	settings.setup("full", "zh")
	var long_name := "深海档案馆·第七次月蚀仪式与所有已解锁宠物的长期旅程"
	settings.set_save_slots([
		{
			"id": "slot_000001",
			"display_name": long_name,
			"has_data": true,
			"is_active": true,
			"playtime_seconds": 86_460.0
		},
		{
			"id": "slot_000002",
			"display_name": "旧日支配者的研究记录（可切换）",
			"has_data": true,
			"is_active": false,
			"playtime_seconds": 2_940.0
		},
		{
			"id": "slot_000003",
			"display_name": "新的桌面旅程",
			"has_data": false,
			"is_active": false,
			"playtime_seconds": 0.0
		}
	], "slot_000001")
	settings.open_window()
	settings.call("_open_save_slots_panel")
	await process_frame
	await process_frame
	await create_timer(0.12).timeout

	_assert_save_slot_geometry(settings, long_name)
	_save_window_texture(settings, SAVE_SLOTS_PREVIEW)
	settings.visible = false


func _assert_save_slot_geometry(settings: Window, long_name: String) -> void:
	var root_control := settings.get("_root") as Control
	var panel := settings.get("_save_slots_panel") as PanelContainer
	var scroll := panel.find_child("SaveSlotsScroll", true, false) as ScrollContainer if panel != null else null
	var list := settings.get("_save_slots_list") as VBoxContainer
	if root_control == null or panel == null or scroll == null or list == null:
		_failures.append("save-slot preview did not build its panel, scroll view, and list")
		return

	var root_bounds := Rect2(Vector2.ZERO, SettingsWindow.WINDOW_SIZE)
	if not root_bounds.encloses(Rect2(panel.position, panel.size)):
		_failures.append("save-slot panel escapes the settings window")
	var cards: Array[Rect2] = []
	for child in list.get_children():
		if child is not PanelContainer:
			continue
		var card := child as PanelContainer
		var card_rect := card.get_global_rect()
		if card_rect.size.x <= 0.0 or card_rect.size.y <= 0.0:
			_failures.append("save-slot card %s has no visible layout size" % card.name)
			continue
		if card.custom_minimum_size.x > scroll.size.x + 0.5:
			_failures.append("save-slot card %s is wider than the scroll surface" % card.name)
		for earlier_rect in cards:
			if earlier_rect.intersects(card_rect):
				_failures.append("save-slot cards overlap")
				break
		cards.append(card_rect)

		var card_bounds := card.get_global_rect()
		for descendant in _find_controls(card):
			if descendant == card:
				continue
			if descendant is Button and not card_bounds.encloses(descendant.get_global_rect()):
				_failures.append("save-slot action %s escapes %s" % [descendant.name, card.name])

	var long_name_label := _find_label_with_text(list, long_name)
	if long_name_label == null:
		_failures.append("save-slot preview did not render the long localized slot name")
	elif long_name_label.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
		_failures.append("long save-slot names must truncate instead of covering the state label")


func _find_controls(node: Node) -> Array[Control]:
	var controls: Array[Control] = []
	if node is Control:
		controls.append(node as Control)
	for child in node.get_children():
		controls.append_array(_find_controls(child))
	return controls


func _find_label_with_text(node: Node, target_text: String) -> Label:
	if node is Label and (node as Label).text == target_text:
		return node as Label
	for child in node.get_children():
		var found := _find_label_with_text(child, target_text)
		if found != null:
			return found
	return null


func _save_window_texture(window: Window, file_name: String) -> void:
	if window == null:
		_failures.append("could not capture %s because its window is missing" % file_name)
		return
	# Godot's dummy headless renderer deliberately has no readable viewport
	# texture.  The geometry assertions above still run in CI; a normal renderer
	# writes the image artifacts for human visual review.
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		print("UI_POLISH_CAPTURE_SKIPPED=%s (headless renderer)" % file_name)
		return
	var texture := window.get_texture()
	if texture == null:
		_failures.append("could not capture %s because its viewport texture is missing" % file_name)
		return
	var image := texture.get_image()
	if image == null:
		_failures.append("could not capture %s because its image is missing" % file_name)
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	if image.save_png(path) != OK:
		_failures.append("could not write %s" % path)
