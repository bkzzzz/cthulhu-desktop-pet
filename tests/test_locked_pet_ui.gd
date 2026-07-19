extends RefCounted

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const SideDrawer = preload("res://scripts/side_drawer_controller.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	var drawer := SideDrawer.new()
	drawer.set("_upgrade_entries", [_make_entry("pet1", "Unlocked One")])
	drawer.call("_create_drawer_window")

	_assert_locked_row(failures, drawer, "pet2")
	var pet1_icon := (drawer.get("_upgrade_icons") as Dictionary).get("pet1") as TextureRect
	if pet1_icon == null or pet1_icon.modulate != Color.WHITE:
		failures.append("an unlocked menu pet must retain its normal full-color portrait")

	# Renames are fed through a separate UI path. They must never reveal a pet
	# absent from the authoritative unlocked-entry snapshot.
	drawer.call("set_pet_name", "pet2", "Leaked Name")
	var pet2_name := (drawer.get("_upgrade_name_labels") as Dictionary).get("pet2") as Label
	if pet2_name == null or pet2_name.text != SideDrawer.LOCKED_PET_TEXT:
		failures.append("renaming a locked pet must not reveal its name")

	# Verify both directions so a gacha unlock restores the real row and a full
	# game reset hides it again without rebuilding the drawer.
	drawer.set("_drawer_open", true)
	drawer.call("refresh_pet_upgrades", [
		_make_entry("pet1", "Unlocked One"),
		_make_entry("pet2", "Unlocked Two"),
	])
	var pet2_button := (drawer.get("_upgrade_buttons") as Dictionary).get("pet2") as TextureButton
	var pet2_icon := (drawer.get("_upgrade_icons") as Dictionary).get("pet2") as TextureRect
	if pet2_button == null or not bool(pet2_button.get_meta("pet_unlocked", false)):
		failures.append("unlocking a pet must restore its menu row")
	if pet2_name == null or pet2_name.text != "Unlocked Two":
		failures.append("unlocking a pet must restore its real display name")
	if pet2_icon == null or pet2_icon.modulate != Color.WHITE:
		failures.append("unlocking a pet must restore its full-color portrait")

	drawer.call("refresh_pet_upgrades", [_make_entry("pet1", "Unlocked One")])
	_assert_locked_row(failures, drawer, "pet2")

	_assert_language_fonts(failures, drawer)
	_assert_short_screen_layout(failures, drawer)
	drawer.free()
	return failures


static func _make_entry(pet_id: String, display_name: String) -> Dictionary:
	return {
		"id": pet_id,
		"name": display_name,
		"level": 3,
		"icon": String(PetCatalog.get_definition(pet_id).get("icon", "")),
		"cost": 12,
		"current_fps": 1.5,
		"next_fps": 2.0,
		"affordable": true,
	}


static func _assert_locked_row(failures: Array[String], drawer: Node, pet_id: String) -> void:
	var button := (drawer.get("_upgrade_buttons") as Dictionary).get(pet_id) as TextureButton
	var name_label := (drawer.get("_upgrade_name_labels") as Dictionary).get(pet_id) as Label
	var level_label := (drawer.get("_upgrade_level_labels") as Dictionary).get(pet_id) as Label
	var cost_label := (drawer.get("_upgrade_cost_labels") as Dictionary).get(pet_id) as Label
	var bonus_label := (drawer.get("_upgrade_bonus_labels") as Dictionary).get(pet_id) as Label
	var icon := (drawer.get("_upgrade_icons") as Dictionary).get(pet_id) as TextureRect
	if button == null or not button.disabled or bool(button.get_meta("pet_unlocked", true)):
		failures.append("%s must have a disabled, explicitly locked menu row" % pet_id)
	var protected_texts := [
		name_label.text if name_label != null else "",
		level_label.text if level_label != null else "",
		cost_label.text if cost_label != null else "",
		bonus_label.text if bonus_label != null else "",
		button.tooltip_text if button != null else "",
	]
	for protected_text_value in protected_texts:
		var protected_text := String(protected_text_value).replace("\n", "")
		if protected_text.is_empty() or not protected_text.contains("?") or not protected_text.replace("?", "").is_empty():
			failures.append("%s locked name, level, rate, cost and tooltip must contain question marks only" % pet_id)
			break
	if icon == null or icon.texture == null:
		failures.append("%s locked portrait must preserve its alpha silhouette" % pet_id)
	elif (
		icon.modulate.r > 0.05
		or icon.modulate.g > 0.05
		or icon.modulate.b > 0.05
		or not is_equal_approx(icon.modulate.a, 1.0)
	):
		failures.append("%s locked portrait must render as a near-black silhouette" % pet_id)


static func _assert_language_fonts(failures: Array[String], drawer: Node) -> void:
	drawer.call("set_language", "en")
	var english_font := drawer.call("_get_ui_font") as Font
	var english_theme := drawer.call("_get_ui_theme") as Theme
	drawer.call("set_language", "zh")
	var chinese_font := drawer.call("_get_ui_font") as Font
	var chinese_theme := drawer.call("_get_ui_theme") as Theme
	if english_font == null or chinese_font == null or english_font.get_instance_id() == chinese_font.get_instance_id():
		failures.append("English and Chinese drawer modes must use distinct font objects")
	if english_font is not SystemFont:
		failures.append("English drawer body copy must use a system UI font with normal word spacing")
	var english_display_font := SideDrawer.LanguageSettings.get_display_font("en")
	if english_display_font == null or english_display_font.get_instance_id() == english_font.get_instance_id():
		failures.append("the pixel display face must be separate from the English body font")
	var chinese_display_font := SideDrawer.LanguageSettings.get_display_font("zh")
	var numeric_display_font := SideDrawer.LanguageSettings.get_numeric_display_font()
	if chinese_display_font == null or chinese_display_font.get_instance_id() == chinese_font.get_instance_id():
		failures.append("Chinese headings must use a stronger display weight than Chinese body copy")
	if numeric_display_font == null or numeric_display_font.get_instance_id() != english_display_font.get_instance_id():
		failures.append("large counters must keep the authored pixel-number face in both languages")
	var faith_value := drawer.get("_faith_value_label") as Label
	var faith_growth := drawer.get("_faith_growth_value_label") as Label
	var gold_value := drawer.get("_coin_value_label") as Label
	var era_value := drawer.get("_era_label") as Label
	for numeric_label in [faith_value, faith_growth, gold_value]:
		if numeric_label == null or numeric_label.get_theme_font("font").get_instance_id() != numeric_display_font.get_instance_id():
			failures.append("Chinese mode must apply the pixel-number face to every large economy counter")
			break
	if era_value == null or era_value.get_theme_font("font").get_instance_id() != chinese_display_font.get_instance_id():
		failures.append("Chinese era text must use the dedicated bold CJK display font")
	if chinese_font is not SystemFont:
		failures.append("Chinese drawer mode must use a SystemFont with CJK fallbacks")
	else:
		var font_names := Array((chinese_font as SystemFont).font_names)
		if not font_names.has("Microsoft YaHei UI") and not font_names.has("Noto Sans CJK SC"):
			failures.append("Chinese drawer font must list a known CJK-capable family")
	var drawer_root := drawer.get("_drawer_root") as Control
	if drawer_root == null or drawer_root.theme != chinese_theme or english_theme == chinese_theme:
		failures.append("switching drawer language must replace the theme on existing controls")


static func _assert_short_screen_layout(failures: Array[String], drawer: Node) -> void:
	var short_stage_height := float(SideDrawer._get_responsive_adder_stage_height(600.0))
	var tall_stage_height := float(SideDrawer._get_responsive_adder_stage_height(1440.0))
	if not is_equal_approx(short_stage_height, 300.0):
		failures.append("a 600px-high screen must compact the drawer adder stage")
	if not is_equal_approx(tall_stage_height, SideDrawer.ADDER_STAGE_HEIGHT):
		failures.append("a tall screen must preserve the drawer's full-size adder art")
	drawer.set("_drawer_screen_size", Vector2i(SideDrawer.DRAWER_WIDTH, 600))
	drawer.call("_refresh_adder_stage_geometry")
	var stage := drawer.get("_adder_stage") as Control
	var scroller_height := float(drawer.call("_get_upgrade_scroll_height"))
	if stage == null or not is_equal_approx(stage.custom_minimum_size.y, 300.0):
		failures.append("the live drawer must reserve the compact adder height on a 600px screen")
	if not is_equal_approx(scroller_height, 128.0):
		failures.append("a 600px drawer must retain a visible upgrade scroller and footer without clipping")
