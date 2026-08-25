extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if SideDrawer.RATE_SUFFIX != "/s":
		failures.append("all growth rates must use the /s suffix")
	if SideDrawer._format_playtime(3723.9) != "01:02:03":
		failures.append("the menu playtime must format total runtime as HH:MM:SS")
	if SideDrawer.MENU_WINDOW_SIZE.x > int(SideDrawer.MENU_ICON_SIZE.x) + 16:
		failures.append("the menu handle must not reserve the removed altar's desktop space")
	if SideDrawer.MENU_WINDOW_SIZE.y > int(SideDrawer.MENU_ICON_SIZE.y) + 16:
		failures.append("the compact menu window must closely fit the visible banner")
	if SideDrawer.MENU_TO_DRAWER_GAP > 4:
		failures.append("the menu handle must sit farther right near the drawer edge")
	var bookmark_stack_height := (SideDrawer.BOOKMARK_SIZE.y * 5.0) + (SideDrawer.BOOKMARK_SEPARATION * 5.0)
	if SideDrawer.BOOKMARK_CONTAINER_HEIGHT < bookmark_stack_height:
		failures.append("all five drawer bookmarks must fit inside the clickable bookmark strip")
	if FileAccess.file_exists("res://scripts/windows_clickthrough_helper.ps1"):
		failures.append("desktop input must not depend on an asynchronous clickthrough helper")
	var formatter := SideDrawer.new()
	formatter.call("set_language", "zh")
	_check(failures, formatter.call("_format_number", 1250.0, false, true), "1.25K")
	_check(failures, formatter.call("_format_number", 18400.0, false, true), "18.4K")
	_check(failures, formatter.call("_format_number", 125000.0, false, true), "125K")
	_check(failures, formatter.call("_get_upgrade_level_text", {"level": 7}), "Lv.7")
	_check(failures, formatter.call("_get_upgrade_level_text", {"upgrade_level": 1250}), "Lv.1.25K")
	_check(failures, formatter.call("_get_upgrade_growth_text", {
		"current_fps": 1.25,
		"next_fps": 2.5
	}), "增速 1.25/s")
	_check(failures, formatter.call("_get_upgrade_gain_text", {
		"current_fps": 1.25,
		"next_fps": 2.5
	}), "提升增速 +1.25/s")
	_check(failures, formatter.call("_get_money_rate_text", {
		"current_money_rate": 12.5,
		"next_money_rate": 13.75,
		"money_rate_gain": 1.25
	}), "金钱产出  $12.50/分钟")
	_check(failures, formatter.call("_get_rarity_stars_text", {"rarity_stars": 3}, {}), "★★★")
	_check(failures, formatter.call("_get_upgrade_cost_text", {"cost": 25}), "消耗 25")
	_check(failures, formatter.call("_get_upgrade_tooltip_text", {}), "点击升级宠物，提高信仰与金钱掉落")
	_check(failures, formatter.call("_get_upgrade_cost_text", {"is_max_level": true}), "已满级")
	_check(failures, formatter.call("_get_upgrade_tooltip_text", {"is_max_level": true}), "宠物已满级")
	var compact_layout: Vector2 = formatter.call("_get_bookmark_layout", 400.0)
	if compact_layout.x + (SideDrawer.BOOKMARK_CONTAINER_HEIGHT * compact_layout.y) > 400.01:
		failures.append("all five bookmarks must scale inside a short screen")
	var screen_rect := Rect2i(0, 0, 1920, 1080)
	var bottom_usable_rect := Rect2i(0, 0, 1920, 1040)
	var bottom_position := SideDrawer._get_menu_position_for_anchor(
		screen_rect,
		bottom_usable_rect,
		SideDrawer.MENU_WINDOW_SIZE,
		0.5
	)
	if bottom_position.y + SideDrawer.MENU_WINDOW_SIZE.y != bottom_usable_rect.end.y:
		failures.append("the draggable menu handle must stay attached to a bottom taskbar")
	var left_usable_rect := Rect2i(48, 0, 1872, 1080)
	var left_position := SideDrawer._get_menu_position_for_anchor(
		screen_rect,
		left_usable_rect,
		SideDrawer.MENU_WINDOW_SIZE,
		0.5
	)
	if left_position.x != left_usable_rect.position.x:
		failures.append("the draggable menu handle must follow a left-side taskbar")
	formatter.call("set_menu_handle_anchor", 2.0)
	if not is_equal_approx(float(formatter.call("get_menu_handle_anchor")), 1.0):
		failures.append("saved menu handle anchors must remain inside the taskbar span")

	if not formatter.has_method("refresh_pet_upgrades") or formatter.has_method("refresh_pet_upgrade_counts"):
		failures.append("the drawer must expose only the pure pet-upgrade refresh API")
	if not formatter.has_signal("pet_upgrade_requested"):
		failures.append("the drawer must expose the pure pet-upgrade signal")
	if not formatter.has_signal("pet_rename_requested"):
		failures.append("the editable detail card must expose pet rename requests")
	if not formatter.has_signal("menu_handle_moved"):
		failures.append("dragging the desktop menu handle must expose a persistence signal")
	if formatter.has_signal("offering_drop_requested") or formatter.has_method("get_offering_state"):
		failures.append("the side drawer must not retain altar offering inventory APIs")

	var upgrade_requests: Array[String] = []
	formatter.pet_upgrade_requested.connect(func(pet_id: String) -> void: upgrade_requests.append(pet_id))
	formatter.call("_on_pet_upgrade_pressed", "pet2", null)
	if upgrade_requests != ["pet2"]:
		failures.append("clicking a pet row must request exactly one pet upgrade")

	formatter.set("_drawer_open", true)
	formatter.call("_on_drawer_close_bookmark_pressed")
	if bool(formatter.get("_drawer_open")):
		failures.append("the independent close bookmark must close the drawer")

	formatter.call("_create_drawer_window")
	formatter.call("_build_pending_drawer_work", 64)
	formatter.call("_create_upgrade_detail_panel")
	var drawer_root := formatter.get("_drawer_root") as Control
	var drawer_panel := formatter.get("_drawer_panel") as PanelContainer
	var era_label := formatter.get("_era_label") as Label
	if era_label == null or drawer_panel == null:
		failures.append("the drawer must create its era label")
	else:
		var faith_stage := drawer_root.find_child("FaithAdderStage", true, false) as Control
		var upgrade_scroller := drawer_root.find_child("UpgradeScroller", true, false) as ScrollContainer
		var era_parent := era_label.get_parent()
		if faith_stage == null or upgrade_scroller == null or era_parent != faith_stage.get_parent() or era_parent != upgrade_scroller.get_parent():
			failures.append("the era line must share the main flow between faith and pet upgrades")
		else:
			var flow_children := era_parent.get_children()
			var faith_index := flow_children.find(faith_stage)
			var era_index := flow_children.find(era_label)
			var upgrades_index := flow_children.find(upgrade_scroller)
			if era_index <= faith_index or era_index >= upgrades_index:
				failures.append("the era line must sit directly above the pet upgrade block instead of at the drawer top")
		if era_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or era_label.custom_minimum_size.y < SideDrawer.ERA_LABEL_HEIGHT:
			failures.append("the era line must remain a centered, readable upgrade-section heading")
		if (
			era_label.custom_minimum_size.x >= SideDrawer.DRAWER_CONTENT_WIDTH
			or not is_equal_approx(era_label.custom_minimum_size.x, SideDrawer.ERA_LABEL_WIDTH)
			or era_label.size_flags_horizontal != Control.SIZE_SHRINK_CENTER
		):
			failures.append("the era line must be shorter than the drawer content and centered instead of stretching past it")
	if drawer_root.find_child("FollowerSummary", true, false) != null:
		failures.append("the faith header must not retain the follower summary line")
	var faith_value := formatter.get("_faith_value_label") as Label
	var faith_growth := formatter.get("_faith_growth_value_label") as Label
	var gold_value := formatter.get("_coin_value_label") as Label
	var gold_center := drawer_root.find_child("GoldBalanceCenter", true, false) as CenterContainer
	var gold_row := drawer_root.find_child("GoldBalanceRow", true, false) as HBoxContainer
	var gold_icon := drawer_root.find_child("GoldIcon", true, false) as TextureRect
	if faith_value == null or faith_growth == null:
		failures.append("the faith header must create both total and growth labels")
	elif Rect2(faith_value.position, faith_value.size).intersects(Rect2(faith_growth.position, faith_growth.size)):
		failures.append("the large faith total must not overlap its growth-rate label")
	if gold_value == null or not gold_value.text.begins_with("$"):
		failures.append("the drawer must show a money-marked gold balance above pet upgrades")
	if drawer_root.find_child("GoldTitle", true, false) != null:
		failures.append("the money row must not repeat a separate gold title")
	if gold_center == null or gold_row == null or gold_icon == null or gold_value == null:
		failures.append("the money icon and amount must share one centered row")
	else:
		var stage := drawer_root.find_child("FaithAdderStage", true, false) as Control
		if not is_equal_approx(gold_center.position.x + gold_center.size.x * 0.5, SideDrawer.DRAWER_CONTENT_WIDTH * 0.5):
			failures.append("the complete money row must align to the drawer center axis")
		if gold_icon.get_parent() != gold_row or gold_value.get_parent() != gold_row:
			failures.append("the coin icon and money amount must be aligned by the same row container")
		if faith_growth != null and gold_center.position.y <= faith_growth.position.y + faith_growth.size.y:
			failures.append("the money row must leave visible space below faith growth")
		if stage == null or (gold_center.position.y + gold_center.size.y) * stage.scale.y > stage.custom_minimum_size.y:
			failures.append("the money row must remain immediately above the pet upgrade block")
	var bookmark_container := drawer_root.get_node_or_null("DrawerBookmarks") as VBoxContainer
	var bookmark_names: Array[String] = []
	if bookmark_container != null:
		for child in bookmark_container.get_children():
			if child is TextureButton:
				bookmark_names.append(String(child.name))
	if bookmark_names != ["仓库Bookmark", "商店Bookmark", "成就Bookmark", "新闻Bookmark", "设置Bookmark", "收起Bookmark"]:
		failures.append("drawer bookmarks must keep warehouse/shop/achievements/news/settings/close order")

	var detail_name_edit := formatter.get("_upgrade_detail_name_edit") as LineEdit
	if detail_name_edit == null or detail_name_edit.max_length != 40:
		failures.append("pet detail names must be editable and capped at 40 characters")
	else:
		var rename_requests: Array[String] = []
		formatter.pet_rename_requested.connect(
			func(pet_id: String, custom_name: String) -> void:
				rename_requests.append("%s:%s" % [pet_id, custom_name])
		)
		formatter.set("_upgrade_detail_pet_id", "pet2")
		detail_name_edit.text = "  新名字  "
		formatter.call("_commit_upgrade_detail_name")
		if rename_requests != ["pet2:新名字"]:
			failures.append("committing the detail name must emit one trimmed rename request")

	var locked_evolution_text: String = formatter.call("_get_upgrade_evolution_text", {
		"id": "pet1",
		"name": "腐生眷族",
		"level": 99,
		"evolved": false,
	}, "pet1")
	if "自动" in locked_evolution_text or "Lv.100 进化" not in locked_evolution_text:
		failures.append("the menu pet detail must describe level-100 evolution without automatic wording")
	var evolved_text: String = formatter.call("_get_upgrade_evolution_text", {
		"id": "pet1",
		"name": "腐生眷族",
		"level": 100,
		"evolved": true,
		"evolution_name": "渊生眷族",
	}, "pet1")
	if evolved_text != "进化完成\n渊生眷族":
		failures.append("the menu pet detail must say only evolution complete after evolving")

	formatter.call("_create_toggle_button")
	var menu_window := formatter.get("_menu_window") as Window
	if menu_window == null or menu_window.get_node_or_null("MenuHandleRoot/CultAltar") != null:
		failures.append("the desktop menu handle must not create the removed altar")
	var menu_root: Control = null
	if menu_window != null:
		menu_root = menu_window.get_node_or_null("MenuHandleRoot") as Control
	var playtime_label: Label = null
	if menu_root != null:
		playtime_label = menu_root.get_node_or_null("PlaytimeLabel") as Label
	if playtime_label == null:
		failures.append("the desktop menu handle must expose a persistent playtime label")
	else:
		formatter.call("refresh_playtime", 3723.9)
		if (
			playtime_label.get_parent() != menu_root
			or playtime_label.mouse_filter != Control.MOUSE_FILTER_IGNORE
			or playtime_label.z_index <= 2
			or playtime_label.position.y > 8.0
			or playtime_label.position.x + playtime_label.size.x > float(SideDrawer.MENU_WINDOW_SIZE.x)
		):
			failures.append("the persistent playtime must sit inertly in the menu handle's upper-right corner")
		if drawer_root != null and drawer_root.find_child("PlaytimeLabel", true, false) != null:
			failures.append("the persistent playtime must not be placed inside the opened drawer UI")
	formatter.call("set_language", "en")
	var detail_window := formatter.get("_upgrade_detail_window") as Window
	if menu_window == null or menu_window.title != "Menu":
		failures.append("the native menu handle title must switch to English")
	if detail_window == null or detail_window.title != "Pet Details":
		failures.append("the native pet-detail title must switch to English")
	if detail_name_edit == null or detail_name_edit.placeholder_text != "Pet name" or "输入" in detail_name_edit.tooltip_text:
		failures.append("the pet-detail rename controls must switch fully to English")
	if playtime_label == null or playtime_label.text != "PLAY 01:02:03":
		failures.append("the menu playtime must show the persisted total in English")
	formatter.call("set_language", "zh")
	if playtime_label == null or playtime_label.text != "时长 01:02:03":
		failures.append("the menu playtime must localize without leaving the menu handle")
	formatter.free()
	return failures


static func _check(failures: Array[String], actual: String, expected: String) -> void:
	if actual != expected:
		failures.append("number format: expected %s, got %s" % [expected, actual])
