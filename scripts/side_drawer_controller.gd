extends Node

signal inventory_requested
signal shop_requested
signal gacha_requested
signal news_requested
signal settings_requested
signal quit_requested
signal pet_upgrade_requested(pet_id: String)
signal pet_rename_requested(pet_id: String, custom_name: String)
signal faith_add_requested(amount: int)
signal menu_handle_moved(anchor: float)
signal drawer_opened

const PetCatalog = preload("res://scripts/pet_catalog.gd")
const RecoveryProgressRing = preload("res://scripts/recovery_progress_ring.gd")
const BoostAura = preload("res://scripts/boost_aura.gd")
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")
const CurrencyDisplay = preload("res://scripts/domain/currency_display.gd")
const DisplayLayout = preload("res://scripts/domain/display_layout.gd")

const DESKTOP_MARGIN_X := 24
const DRAWER_BOOKMARK_WIDTH := 226
const DRAWER_PANEL_WIDTH := 548
const DRAWER_WIDTH := DRAWER_BOOKMARK_WIDTH + DRAWER_PANEL_WIDTH
const DRAWER_CONTENT_MARGIN_X := 34
const DRAWER_CONTENT_WIDTH := DRAWER_PANEL_WIDTH - (DRAWER_CONTENT_MARGIN_X * 2)
const DRAWER_SLIDE_SPEED := 1800.0
const DRAWER_CONTENT_TOP_MARGIN := 46
const ERA_LABEL_HEIGHT := 34.0
const ERA_LABEL_WIDTH := DRAWER_CONTENT_WIDTH - 56.0
const MENU_WINDOW_SIZE := Vector2i(228, 150)
const PLAYTIME_LABEL_SIZE := Vector2(114.0, 22.0)
const MENU_TO_DRAWER_GAP := 2
const MENU_DRAG_THRESHOLD := 6.0
const RATE_SUFFIX := "/s"
const POSITION_RETRY_FRAMES := 12
const DISPLAY_LAYOUT_POLL_SECONDS := 1.0

enum TaskbarEdge {
	BOTTOM,
	TOP,
	LEFT,
	RIGHT
}

const MENU_ICON_TEXTURE := "res://assets/ui/newElements/菜单栏呼出.png"
const DRAWER_BACKGROUND_TEXTURE := "res://assets/ui/newElements/菜单栏2.png"
const DRAWER_BACKGROUND_BOTTOM_CROP := 570.0
const ADDER_TEXTURE := "res://assets/ui/newElements/adder.png"
const GLOW_TEXTURE := "res://assets/ui/newElements/glow.png"
const UPGRADE_EFFECT_TEXTURE := "res://assets/ui/newElements/upgradeEffect.png"
const UPGRADE_TEXTURE := "res://assets/ui/testElements/upgrade.png"
const BOOKMARK_TEXTURE := "res://assets/ui/newElements/书签.png"
const COIN_TEXTURE := "res://assets/ui/coins/MonedaD.png"

const MENU_ICON_SIZE := Vector2(218.0, 140.0)
const ADDER_STAGE_HEIGHT := 484.0
const ADDER_SIZE := Vector2(244.0, 296.0)
const GLOW_SIZE := Vector2(230.0, 210.0)
const GLOW_ROTATION_SPEED := 0.65
const FAITH_COUNTER_VALUE_FONT_MAX := 68
const FAITH_COUNTER_VALUE_FONT_MIN := 32
const UPGRADE_ROW_SIZE := Vector2(468.0, 116.0)
const UPGRADE_PROFILE_BOX_SIZE := Vector2(68.0, 68.0)
const UPGRADE_ICON_SIZE := Vector2(62.0, 62.0)
const UPGRADE_ROW_GAP := 6
const UPGRADE_LOCKED_ROWS := 12
const UPGRADE_SCROLL_TOP_PADDING := 44
const UPGRADE_SCROLL_BOTTOM_PADDING := 24
const UPGRADE_SCROLL_MIN_HEIGHT := 64.0
const UPGRADE_SCROLL_MAX_HEIGHT := 760.0
const LOCKED_PET_TEXT := "??????"
const LOCKED_PET_LEVEL_TEXT := "????\n????"
const LOCKED_PET_SILHOUETTE_COLOR := Color(0.025, 0.025, 0.035, 1.0)
const SYMBOL_EFFECT_TEXTURES := [
	"res://assets/ui/newElements/符号特效1.png",
	"res://assets/ui/newElements/符号特效2.png",
	"res://assets/ui/newElements/符号特效3.png",
	"res://assets/ui/newElements/符号特效4.png",
	"res://assets/ui/newElements/符号特效5.png"
]
const SYMBOL_BURST_COUNT := 14
const SYMBOL_BURST_COOLDOWN_SECONDS := 0.12
const SYMBOL_EFFECT_SIZE := Vector2(6.0, 9.0)
const SYMBOL_SOURCE_SPREAD := Vector2(168.0, 196.0)
const DRAWER_SYMBOL_COUNT := 22
const DRAWER_SYMBOL_SIZE := Vector2(28.0, 40.0)
const DRAWER_SYMBOL_SPEED_MIN := 18.0
const DRAWER_SYMBOL_SPEED_MAX := 42.0
const DRAWER_SYMBOL_UPDATE_INTERVAL := 1.0 / 30.0
const UPGRADE_EFFECT_SIZE := Vector2(150.0, 142.0)
const UPGRADE_DETAIL_HOVER_DELAY := 0.45
const UPGRADE_DETAIL_HIDE_GRACE := 0.22
const UPGRADE_DETAIL_SIZE := Vector2i(420, 280)
const UPGRADE_DETAIL_GAP := 14
const UPGRADE_DETAIL_SCREEN_MARGIN := 24
const UPGRADE_DETAIL_SAFE_PADDING := 18.0
const BOOKMARK_SIZE := Vector2(258.0, 82.0)
const BOOKMARK_CONTAINER_TOP := 106.0
const BOOKMARK_SEPARATION := 12
const BOOKMARK_CONTAINER_HEIGHT := 570.0
const BOOKMARK_SCREEN_MARGIN := 8.0
const BOOKMARK_SAFE_INSET_X := 8.0
const BOOKMARK_LABEL_POSITION := Vector2(84.0, 0.0)
const BOOKMARK_LABEL_SIZE := Vector2(124.0, 82.0)

var _menu_window: Window
var _menu_button: TextureButton
var _menu_hint: Label
var _playtime_label: Label
var _drawer_window: Window
var _drawer_root: Control
var _bookmark_container: VBoxContainer
var _drawer_background: TextureRect
var _drawer_panel: PanelContainer
var _drawer_symbol_layer: Control
var _drawer_symbols: Array[TextureRect] = []
var _era_label: Label
var _upgrade_detail_panel: PanelContainer
var _upgrade_detail_window: Window
var _upgrade_detail_name_edit: LineEdit
var _upgrade_detail_rarity_label: Label
var _upgrade_detail_profile_label: Label
var _upgrade_detail_evolution_icon: TextureRect
var _upgrade_detail_evolution_label: Label
var _upgrade_detail_stats_label: RichTextLabel
var _hovered_upgrade_pet_id := ""
var _hovered_upgrade_button: Control
var _upgrade_detail_hover_time := 0.0
var _upgrade_detail_hide_timer := 0.0
var _upgrade_detail_panel_hovered := false
var _upgrade_detail_pet_id := ""
var _upgrade_detail_source_button: Control
var _updating_upgrade_detail_name := false
var _upgrade_detail_last_committed_name := ""
var _adder_glow: Sprite2D
var _adder_button: TextureButton
var _adder_stage: Control
var _upgrade_scroller: ScrollContainer
var _quit_button: Button
var _drawer_open := false
var _drawer_target_x := 0
var _drawer_closed_x := 0
var _drawer_screen_position := Vector2i.ZERO
var _drawer_screen_size := Vector2i(DRAWER_WIDTH, 720)
var _position_retry_frames := 0
var _menu_handle_anchor := -1.0
var _menu_drag_active := false
var _menu_drag_moved := false
var _menu_drag_suppress_click := false
var _menu_drag_start_pointer := Vector2.ZERO
var _menu_drag_pointer_offset := Vector2.ZERO

var _faith_value_label: Label
var _faith_boost_glow_label: Label
var _faith_boost_aura: Control
var _faith_title_label: Label
var _faith_growth_value_label: Label
var _coin_icon: TextureRect
var _coin_value_label: Label
var _faith_count := 0.0
var _coin_count := 0
var _follower_count := 0
var _faith_growth_rate := 0.0
var _faith_boost_active := false
var _follower_growth_rate := 0.0
var _upgrade_entries := []
var _upgrade_buttons := {}
var _upgrade_name_labels := {}
var _upgrade_level_labels := {}
var _upgrade_cost_labels := {}
var _upgrade_bonus_labels := {}
var _upgrade_last_levels := {}
var _upgrade_affordables := {}
var _upgrade_recovery_rings := {}
var _upgrade_icons := {}
var _upgrade_boost_auras := {}
var _ui_theme: Theme
var _ui_font: Font
var _upgrade_row_texture: Texture2D
var _menu_hit_images := {}
var _bookmark_labels := {}
var _language := LanguageSettings.DEFAULT_LANGUAGE
var _playtime_seconds := 0.0
var _rng := RandomNumberGenerator.new()
var _symbol_effect_textures: Array[Texture2D] = []
var _adder_symbol_burst_cooldown := 0.0
var _drawer_symbol_update_time := 0.0
var _display_layout_poll_time := 0.0


func setup() -> void:
	_rng.randomize()
	_load_symbol_effect_textures()
	_create_toggle_button()
	_create_drawer_window()
	_position_retry_frames = POSITION_RETRY_FRAMES
	call_deferred("_place_menu_window")
	call_deferred("_refresh_drawer_geometry")


func _process(delta: float) -> void:
	_adder_symbol_burst_cooldown = maxf(0.0, _adder_symbol_burst_cooldown - maxf(0.0, delta))
	if _position_retry_frames > 0:
		_position_retry_frames -= 1
		_place_menu_window()
		_refresh_drawer_geometry()
	if _menu_drag_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_menu_drag()
	_display_layout_poll_time += maxf(0.0, delta)
	if _display_layout_poll_time >= DISPLAY_LAYOUT_POLL_SECONDS:
		_display_layout_poll_time = 0.0
		if not _menu_drag_active:
			_refresh_drawer_geometry()

	_update_drawer_slide(delta)
	if _drawer_window != null and _drawer_window.visible:
		_update_upgrade_detail_hover(delta)
		_drawer_symbol_update_time += maxf(0.0, delta)
		if _drawer_symbol_update_time >= DRAWER_SYMBOL_UPDATE_INTERVAL:
			_update_drawer_background_symbols(_drawer_symbol_update_time)
			_drawer_symbol_update_time = 0.0
		if _adder_glow != null:
			_adder_glow.rotation += GLOW_ROTATION_SPEED * delta
	else:
		_drawer_symbol_update_time = 0.0


func refresh_faith(faith_count: float, growth_rate: float) -> void:
	_faith_count = faith_count
	_faith_growth_rate = growth_rate

	if _faith_value_label != null:
		var next_faith_text := _format_number(faith_count, false, true)
		if _faith_value_label.text != next_faith_text:
			var needs_refit := _faith_value_label.text.length() != next_faith_text.length()
			_faith_value_label.text = next_faith_text
			if _faith_boost_glow_label != null:
				_faith_boost_glow_label.text = next_faith_text
			if needs_refit:
				_fit_font_to_text(_faith_value_label, _faith_value_label.text, FAITH_COUNTER_VALUE_FONT_MAX, FAITH_COUNTER_VALUE_FONT_MIN, 7)
				if _faith_boost_glow_label != null:
					_fit_font_to_text(_faith_boost_glow_label, next_faith_text, FAITH_COUNTER_VALUE_FONT_MAX, FAITH_COUNTER_VALUE_FONT_MIN, 7)
			if _faith_boost_active:
				_play_boosted_faith_growth_pulse()

	if _faith_growth_value_label != null:
		var next_growth_text := "+%s%s" % [_format_number(_faith_growth_rate, true), RATE_SUFFIX]
		if _faith_growth_value_label.text != next_growth_text:
			var needs_refit := _faith_growth_value_label.text.length() != next_growth_text.length()
			_faith_growth_value_label.text = next_growth_text
			if needs_refit:
				_fit_font_to_text(_faith_growth_value_label, _faith_growth_value_label.text, 22, 14, 10)

func refresh_pet_upgrades(entries: Array) -> void:
	var next_entries := []
	var entries_by_id := {}
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var entry_copy := entry.duplicate()
		next_entries.append(entry_copy)
		var entry_pet_id := String(entry_copy.get("id", ""))
		if not entry_pet_id.is_empty():
			entries_by_id[entry_pet_id] = entry_copy
	_upgrade_entries = next_entries
	if _drawer_window != null and not _drawer_window.visible and not _drawer_open:
		return

	var any_boost_active := false
	var strongest_boost := 1.0
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var entry: Dictionary = entries_by_id.get(pet_id, {})
		var unlocked := not entry.is_empty()
		_set_upgrade_row_locked_state(pet_id, not unlocked)
		if not unlocked:
			continue
		var level_label := _upgrade_level_labels.get(pet_id) as Label
		var name_label := _upgrade_name_labels.get(pet_id) as Label
		var level := _get_upgrade_level(entry)
		var recovering := bool(entry.get("recovering", false))
		var offering_multiplier := maxf(1.0, float(entry.get("offering_multiplier", 1.0)))
		var offering_seconds := maxf(0.0, float(entry.get("offering_seconds_remaining", 0.0)))
		var boost_active := offering_multiplier > 1.001 and offering_seconds > 0.0
		any_boost_active = any_boost_active or boost_active
		if boost_active:
			strongest_boost = maxf(strongest_boost, offering_multiplier)
		var boost_aura := _upgrade_boost_auras.get(pet_id) as Control
		if boost_aura != null:
			boost_aura.call("set_boost", boost_active, offering_multiplier)
		if name_label != null:
			_set_fitted_label_text(
				name_label,
				String(entry.get("name", _get_pet_display_name(pet_id, PetCatalog.get_definition(pet_id)))),
				19,
				12,
				12
			)
		if level_label != null:
			_set_fitted_label_text(
				level_label,
				("LEVEL\n%s" if _language == "en" else "等级\n%s") % _get_upgrade_level_text(entry),
				25,
				18,
				6
			)
			if _upgrade_last_levels.has(pet_id) and level > int(_upgrade_last_levels.get(pet_id, level)):
				_pulse_count_label(level_label)
		_upgrade_last_levels[pet_id] = level

		var cost_label := _upgrade_cost_labels.get(pet_id) as Label
		var affordable: bool = entry.get("affordable", false) == true
		var affordability_changed := (
			not _upgrade_affordables.has(pet_id)
			or bool(_upgrade_affordables.get(pet_id, false)) != affordable
		)
		_upgrade_affordables[pet_id] = affordable
		var upgrade_button := _upgrade_buttons.get(pet_id) as TextureButton
		if upgrade_button != null:
			if affordability_changed:
				_set_upgrade_row_affordable(upgrade_button, affordable)
			var next_tooltip := _get_upgrade_tooltip_text(entry)
			if upgrade_button.tooltip_text != next_tooltip:
				upgrade_button.tooltip_text = next_tooltip
		var recovery_ring := _upgrade_recovery_rings.get(pet_id) as Control
		if recovery_ring != null:
			if recovery_ring.visible != recovering:
				recovery_ring.visible = recovering
			if recovering:
				recovery_ring.call("set_progress", float(entry.get("recovery_progress", 0.0)))
		var icon := _upgrade_icons.get(pet_id) as TextureRect
		if icon != null:
			var icon_path := String(entry.get("icon", PetCatalog.get_definition(pet_id).get("icon", "")))
			if String(icon.get_meta("source_path", "")) != icon_path:
				icon.texture = PetCatalog.make_icon_texture(icon_path, 12)
				icon.set_meta("source_path", icon_path)

		if cost_label != null:
			_set_fitted_label_text(cost_label, _get_upgrade_cost_text(entry), 19, 14, 6)
			if affordability_changed:
				cost_label.add_theme_color_override("font_color", Color(0.78, 0.96, 0.76, 1.0) if affordable else Color(0.84, 0.76, 0.66, 1.0))

		var bonus_label := _upgrade_bonus_labels.get(pet_id) as Label
		if bonus_label != null:
			_set_fitted_label_text(bonus_label, _get_upgrade_growth_text(entry), 17, 11, 18)

	_set_any_boost_visual(any_boost_active, strongest_boost)

	if _upgrade_detail_window != null and _upgrade_detail_window.visible and not _upgrade_detail_pet_id.is_empty():
		if _upgrade_detail_source_button != null and is_instance_valid(_upgrade_detail_source_button):
			_show_upgrade_detail_panel(_upgrade_detail_pet_id, _upgrade_detail_source_button)


func set_pet_name(pet_id: String, display_name: String) -> void:
	if pet_id.is_empty():
		return
	var is_unlocked := false
	for entry_index in _upgrade_entries.size():
		var entry: Dictionary = _upgrade_entries[entry_index]
		if String(entry.get("id", "")) != pet_id:
			continue
		entry["name"] = display_name
		_upgrade_entries[entry_index] = entry
		is_unlocked = true
		break
	if not is_unlocked:
		return
	var name_label := _upgrade_name_labels.get(pet_id) as Label
	if name_label != null:
		_set_fitted_label_text(name_label, display_name, 19, 12, 12)
	if (
		_upgrade_detail_pet_id == pet_id
		and _upgrade_detail_name_edit != null
		and not _upgrade_detail_name_edit.has_focus()
	):
		_upgrade_detail_name_edit.text = display_name


func refresh_era(display_text: String) -> void:
	if _era_label != null:
		_era_label.text = display_text


func refresh_playtime(total_seconds: float) -> void:
	_playtime_seconds = maxf(0.0, total_seconds)
	_refresh_playtime_label()


func refresh_followers(follower_count: int, growth_rate: float) -> void:
	_follower_count = maxi(0, follower_count)
	_follower_growth_rate = maxf(0.0, growth_rate)


func refresh_coins(coin_count: int) -> void:
	_coin_count = maxi(0, coin_count)
	if _coin_icon != null:
		_coin_icon.texture = CurrencyDisplay.make_icon_texture(_coin_count)
		_coin_icon.tooltip_text = CurrencyDisplay.get_conversion_tooltip(_coin_count, _language)
	if _coin_value_label == null:
		return
	var next_text := CurrencyDisplay.format_compact(_coin_count)
	_coin_value_label.tooltip_text = CurrencyDisplay.get_conversion_tooltip(_coin_count, _language)
	if _coin_value_label.text == next_text:
		return
	_coin_value_label.text = next_text
	_fit_font_to_text(_coin_value_label, next_text, 34, 20, 12)
	_pulse_count_label(_coin_value_label)


func set_language(language_code: String) -> void:
	_language = LanguageSettings.sanitize(language_code)
	_apply_language_theme()
	if _quit_button != null:
		_quit_button.text = "QUIT" if _language == "en" else "退出"
	refresh_coins(_coin_count)
	if _menu_window != null:
		_menu_window.title = "Menu" if _language == "en" else "菜单栏"
	if _menu_hint != null:
		_menu_hint.text = "MENU" if _language == "en" else "菜单栏"
	_refresh_playtime_label()
	if _upgrade_detail_window != null:
		_upgrade_detail_window.title = "Pet Details" if _language == "en" else "宠物详情"
	if _upgrade_detail_name_edit != null:
		_upgrade_detail_name_edit.placeholder_text = "Pet name" if _language == "en" else "宠物名字"
		_upgrade_detail_name_edit.tooltip_text = (
			"Enter a new name, then press Enter or click elsewhere to save"
			if _language == "en"
			else "输入新名字，按回车或点击别处保存"
		)
	if _faith_title_label != null:
		_faith_title_label.text = "FAITH" if _language == "en" else "信仰点数"
	var labels := {
		"inventory": "INVENTORY" if _language == "en" else "仓库",
		"shop": "SHOP" if _language == "en" else "商店",
		"gacha": "GACHA" if _language == "en" else "抽卡",
		"news": "NEWS" if _language == "en" else "新闻",
		"settings": "SETTINGS" if _language == "en" else "设置",
		"close": "CLOSE" if _language == "en" else "收起"
	}
	for bookmark_id in labels:
		var label := _bookmark_labels.get(bookmark_id) as Label
		if label != null:
			label.text = String(labels[bookmark_id])
			_fit_font_to_text(label, label.text, 24, 14, 9)
	if not _upgrade_entries.is_empty():
		refresh_pet_upgrades(_upgrade_entries)


func set_menu_handle_anchor(anchor: float) -> void:
	_menu_handle_anchor = clampf(anchor, 0.0, 1.0) if is_finite(anchor) else -1.0
	if _menu_window != null:
		_place_menu_window()


func get_menu_handle_anchor() -> float:
	if _menu_handle_anchor >= 0.0:
		return clampf(_menu_handle_anchor, 0.0, 1.0)
	var usable_rect := _get_current_screen_usable_rect()
	return _get_default_menu_anchor(_get_current_screen_rect(), usable_rect)


func is_upgrade_ui_visible() -> bool:
	return _drawer_open or (_drawer_window != null and _drawer_window.visible)


func _create_toggle_button() -> void:
	_menu_window = Window.new()
	_menu_window.name = "MenuHandleWindow"
	_menu_window.title = "菜单栏"
	_menu_window.size = MENU_WINDOW_SIZE
	_menu_window.borderless = true
	_menu_window.always_on_top = false
	_menu_window.unfocusable = true
	_menu_window.unresizable = true
	_menu_window.transparent = true
	_menu_window.transparent_bg = true
	_menu_window.visible = false
	add_child(_menu_window)

	var menu_root := Control.new()
	menu_root.name = "MenuHandleRoot"
	menu_root.theme = _get_ui_theme()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_window.add_child(menu_root)

	_menu_button = TextureButton.new()
	_menu_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_menu_button.name = "MenuBanner"
	_menu_button.texture_normal = load(MENU_ICON_TEXTURE) as Texture2D
	_menu_button.texture_hover = _menu_button.texture_normal
	_menu_button.texture_pressed = _menu_button.texture_normal
	_apply_texture_click_mask(_menu_button)
	_menu_button.ignore_texture_size = true
	_menu_button.stretch_mode = TextureButton.STRETCH_SCALE
	_menu_button.size = MENU_ICON_SIZE
	_menu_button.position = Vector2(MENU_WINDOW_SIZE.x - _menu_button.size.x - 2.0, MENU_WINDOW_SIZE.y - _menu_button.size.y)
	_menu_button.pivot_offset = _menu_button.size * 0.5
	_menu_button.z_index = 2
	_menu_button.mouse_entered.connect(_on_menu_button_hovered.bind(true))
	_menu_button.mouse_exited.connect(_on_menu_button_hovered.bind(false))
	_menu_button.gui_input.connect(_on_menu_button_gui_input)
	_menu_button.pressed.connect(_on_drawer_button_pressed)
	menu_root.add_child(_menu_button)

	_menu_hint = Label.new()
	_menu_hint.text = "菜单栏"
	_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_hint.position = _menu_button.position + Vector2(8.0, -5.0)
	_menu_hint.size = Vector2(76.0, 24.0)
	_menu_hint.visible = false
	_menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_hint.z_index = 3
	_menu_hint.add_theme_font_size_override("font_size", 16)
	_menu_hint.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	_menu_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 1.0))
	_menu_hint.add_theme_constant_override("outline_size", 4)
	menu_root.add_child(_menu_hint)

	_playtime_label = Label.new()
	_playtime_label.name = "PlaytimeLabel"
	_playtime_label.position = Vector2(
		float(MENU_WINDOW_SIZE.x) - PLAYTIME_LABEL_SIZE.x - 6.0,
		4.0
	)
	_playtime_label.size = PLAYTIME_LABEL_SIZE
	_playtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_playtime_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_playtime_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playtime_label.z_index = 4
	_playtime_label.add_theme_font_size_override("font_size", 13)
	_playtime_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 0.96))
	_playtime_label.add_theme_color_override("font_outline_color", Color(0.035, 0.02, 0.03, 0.96))
	_playtime_label.add_theme_constant_override("outline_size", 3)
	menu_root.add_child(_playtime_label)
	_refresh_playtime_label()
	_menu_window.mouse_passthrough_polygon = PackedVector2Array([
		_menu_button.position,
		_menu_button.position + Vector2(_menu_button.size.x, 0.0),
		_menu_button.position + _menu_button.size,
		_menu_button.position + Vector2(0.0, _menu_button.size.y)
	])


func _create_drawer_window() -> void:
	_drawer_window = Window.new()
	_drawer_window.name = "SideDrawerWindow"
	_drawer_window.title = "Cthulu Panel"
	_drawer_window.borderless = true
	_drawer_window.always_on_top = false
	_drawer_window.unresizable = true
	_drawer_window.transparent = true
	_drawer_window.transparent_bg = true
	_drawer_window.visible = false
	add_child(_drawer_window)

	_drawer_root = Control.new()
	_drawer_root.name = "SideDrawerRoot"
	_drawer_root.theme = _get_ui_theme()
	_drawer_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer_window.add_child(_drawer_root)

	_drawer_background = TextureRect.new()
	_drawer_background.name = "DrawerArtBackground"
	_drawer_background.texture = _make_drawer_background_texture()
	_drawer_background.position = Vector2(DRAWER_BOOKMARK_WIDTH - 10, 0)
	_drawer_background.size = Vector2(DRAWER_PANEL_WIDTH + 10, _drawer_screen_size.y)
	_drawer_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drawer_background.stretch_mode = TextureRect.STRETCH_SCALE
	_drawer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_background.z_index = 2
	_drawer_root.add_child(_drawer_background)

	_bookmark_container = VBoxContainer.new()
	_bookmark_container.name = "DrawerBookmarks"
	_bookmark_container.position = Vector2(BOOKMARK_SAFE_INSET_X, BOOKMARK_CONTAINER_TOP)
	_bookmark_container.size = Vector2(BOOKMARK_SIZE.x, BOOKMARK_CONTAINER_HEIGHT)
	_bookmark_container.z_index = 1
	_bookmark_container.add_theme_constant_override("separation", BOOKMARK_SEPARATION)
	_drawer_root.add_child(_bookmark_container)

	_bookmark_container.add_child(_make_bookmark_button("仓库", _on_inventory_bookmark_pressed, "inventory"))
	_bookmark_container.add_child(_make_bookmark_button("商店", _on_shop_bookmark_pressed, "shop"))
	_bookmark_container.add_child(_make_bookmark_button("抽卡", _on_gacha_bookmark_pressed, "gacha"))
	_bookmark_container.add_child(_make_bookmark_button("新闻", _on_news_bookmark_pressed, "news"))
	_bookmark_container.add_child(_make_bookmark_button("设置", _on_settings_bookmark_pressed, "settings"))
	_bookmark_container.add_child(_make_bookmark_button("收起", _on_drawer_close_bookmark_pressed, "close"))
	var bookmark_spacer := Control.new()
	bookmark_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bookmark_container.add_child(bookmark_spacer)

	_drawer_panel = PanelContainer.new()
	_drawer_panel.name = "SideDrawer"
	_drawer_panel.position = Vector2(DRAWER_BOOKMARK_WIDTH - 10, 0)
	_drawer_panel.size = Vector2(DRAWER_PANEL_WIDTH + 10, _drawer_screen_size.y)
	_drawer_panel.clip_contents = true
	_drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer_panel.z_index = 3
	_drawer_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_drawer_root.add_child(_drawer_panel)
	_create_drawer_symbol_layer()
	_create_upgrade_detail_panel()

	var margin := MarginContainer.new()
	margin.z_index = 2
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", DRAWER_CONTENT_MARGIN_X)
	margin.add_theme_constant_override("margin_top", DRAWER_CONTENT_TOP_MARGIN)
	margin.add_theme_constant_override("margin_right", DRAWER_CONTENT_MARGIN_X)
	margin.add_theme_constant_override("margin_bottom", 20)
	_drawer_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, 1)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	content.add_child(_make_faith_adder_stage())
	_create_era_label(content)
	var upgrade_offset := Control.new()
	upgrade_offset.custom_minimum_size = Vector2(1, 4)
	content.add_child(upgrade_offset)
	content.add_child(_make_upgrade_scroller())

	var footer := CenterContainer.new()
	footer.name = "MenuFooter"
	footer.custom_minimum_size = Vector2(1.0, 42.0)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(footer)
	_quit_button = _make_quit_button()
	footer.add_child(_quit_button)

	set_language(_language)
	_refresh_drawer_geometry(false)


func _create_era_label(parent: Node) -> void:
	_era_label = Label.new()
	_era_label.name = "EraDisplay"
	_era_label.custom_minimum_size = Vector2(ERA_LABEL_WIDTH, ERA_LABEL_HEIGHT)
	_era_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_era_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_era_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_era_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_era_label.add_theme_font_size_override("font_size", 17)
	_era_label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.48, 0.98))
	_era_label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.02, 1.0))
	_era_label.add_theme_constant_override("outline_size", 3)
	var era_style := StyleBoxFlat.new()
	era_style.bg_color = Color(0.035, 0.065, 0.045, 0.78)
	era_style.border_color = Color(0.48, 0.43, 0.22, 0.72)
	era_style.set_border_width_all(1)
	era_style.set_corner_radius_all(7)
	_era_label.add_theme_stylebox_override("normal", era_style)
	parent.add_child(_era_label)


func _make_drawer_background_texture() -> Texture2D:
	var base_texture := load(DRAWER_BACKGROUND_TEXTURE) as Texture2D
	if base_texture == null:
		return null

	var drawer_texture := base_texture
	var crop_height := maxi(1, int(round(float(drawer_texture.get_height()) - DRAWER_BACKGROUND_BOTTOM_CROP)))
	if crop_height >= drawer_texture.get_height():
		return drawer_texture

	var atlas := AtlasTexture.new()
	atlas.atlas = drawer_texture
	atlas.region = Rect2(0.0, 0.0, float(drawer_texture.get_width()), float(crop_height))
	return atlas


func _create_drawer_symbol_layer() -> void:
	_drawer_symbol_layer = Control.new()
	_drawer_symbol_layer.name = "DrawerSymbolFlow"
	_drawer_symbol_layer.position = Vector2.ZERO
	_drawer_symbol_layer.size = _drawer_panel.size if _drawer_panel != null else Vector2(DRAWER_PANEL_WIDTH, _drawer_screen_size.y)
	_drawer_symbol_layer.clip_contents = true
	_drawer_symbol_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_symbol_layer.z_index = 0
	_drawer_panel.add_child(_drawer_symbol_layer)

	_drawer_symbols.clear()
	for index in DRAWER_SYMBOL_COUNT:
		var symbol := TextureRect.new()
		symbol.name = "FlowSymbol%d" % index
		symbol.texture = load(String(SYMBOL_EFFECT_TEXTURES[index % SYMBOL_EFFECT_TEXTURES.size()])) as Texture2D
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		symbol.z_index = 0
		_drawer_symbol_layer.add_child(symbol)
		_drawer_symbols.append(symbol)
		_reset_drawer_symbol(symbol, true)


func _update_drawer_background_symbols(delta: float) -> void:
	if _drawer_symbol_layer == null or _drawer_symbols.is_empty():
		return
	if _drawer_window == null or not _drawer_window.visible:
		return

	var panel_size := _drawer_symbol_layer.size
	for symbol in _drawer_symbols:
		if symbol == null or not is_instance_valid(symbol):
			continue

		var phase := float(symbol.get_meta("phase", 0.0)) + delta * float(symbol.get_meta("wave_speed", 0.6))
		var y := symbol.position.y + float(symbol.get_meta("speed", DRAWER_SYMBOL_SPEED_MIN)) * delta
		var x := float(symbol.get_meta("base_x", symbol.position.x)) + sin(phase) * float(symbol.get_meta("drift", 0.0))
		symbol.position = Vector2(x, y)
		symbol.set_meta("phase", phase)
		if y > panel_size.y + symbol.size.y:
			_reset_drawer_symbol(symbol, false)


func _reset_drawer_symbol(symbol: TextureRect, scatter_y: bool) -> void:
	if symbol == null:
		return

	var panel_size := Vector2(DRAWER_PANEL_WIDTH, float(_drawer_screen_size.y))
	if _drawer_symbol_layer != null and _drawer_symbol_layer.size.x > 0.0 and _drawer_symbol_layer.size.y > 0.0:
		panel_size = _drawer_symbol_layer.size

	var scale := _rng.randf_range(0.9, 1.65)
	symbol.size = DRAWER_SYMBOL_SIZE * scale
	var max_x := maxf(28.0, panel_size.x - symbol.size.x - 28.0)
	var base_x := _rng.randf_range(28.0, max_x)
	var y := _rng.randf_range(-panel_size.y, panel_size.y) if scatter_y else -symbol.size.y - _rng.randf_range(4.0, 90.0)
	symbol.position = Vector2(base_x, y)
	symbol.modulate = Color(0.78, 1.0, 0.72, _rng.randf_range(0.14, 0.28))
	symbol.rotation = _rng.randf_range(-0.12, 0.12)
	symbol.set_meta("base_x", base_x)
	symbol.set_meta("speed", _rng.randf_range(DRAWER_SYMBOL_SPEED_MIN, DRAWER_SYMBOL_SPEED_MAX))
	symbol.set_meta("drift", _rng.randf_range(4.0, 18.0))
	symbol.set_meta("wave_speed", _rng.randf_range(0.35, 0.9))
	symbol.set_meta("phase", _rng.randf_range(0.0, TAU))


func _create_upgrade_detail_panel() -> void:
	_upgrade_detail_window = Window.new()
	_upgrade_detail_window.name = "UpgradeDetailWindow"
	_upgrade_detail_window.title = "宠物详情"
	_upgrade_detail_window.theme = _get_ui_theme()
	_upgrade_detail_window.size = UPGRADE_DETAIL_SIZE
	_upgrade_detail_window.borderless = true
	_upgrade_detail_window.transparent = true
	_upgrade_detail_window.transparent_bg = true
	_upgrade_detail_window.unresizable = true
	_upgrade_detail_window.always_on_top = false
	_upgrade_detail_window.visible = false
	_upgrade_detail_window.close_requested.connect(_hide_upgrade_detail_panel)
	add_child(_upgrade_detail_window)

	_upgrade_detail_panel = PanelContainer.new()
	_upgrade_detail_panel.name = "UpgradeDetailPanel"
	_upgrade_detail_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_detail_panel.z_index = 20
	_upgrade_detail_panel.add_theme_stylebox_override("panel", _make_upgrade_detail_style())
	_upgrade_detail_panel.mouse_entered.connect(_on_upgrade_detail_panel_hovered.bind(true))
	_upgrade_detail_panel.mouse_exited.connect(_on_upgrade_detail_panel_hovered.bind(false))
	_upgrade_detail_window.add_child(_upgrade_detail_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_upgrade_detail_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	_upgrade_detail_name_edit = LineEdit.new()
	_upgrade_detail_name_edit.placeholder_text = "宠物名字"
	_upgrade_detail_name_edit.max_length = 40
	_upgrade_detail_name_edit.custom_minimum_size = Vector2(232.0, 34.0)
	_upgrade_detail_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_detail_name_edit.tooltip_text = "输入新名字，按回车或点击别处保存"
	_upgrade_detail_name_edit.add_theme_stylebox_override("normal", _make_line_edit_style(false))
	_upgrade_detail_name_edit.add_theme_stylebox_override("focus", _make_line_edit_style(true))
	_upgrade_detail_name_edit.add_theme_font_size_override("font_size", 18)
	_upgrade_detail_name_edit.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	_upgrade_detail_name_edit.add_theme_color_override("font_placeholder_color", Color(0.56, 0.54, 0.43, 0.86))
	_upgrade_detail_name_edit.add_theme_color_override("font_selected_color", Color(0.02, 0.03, 0.02, 1.0))
	_upgrade_detail_name_edit.add_theme_color_override("selection_color", Color(0.66, 0.72, 0.44, 0.82))
	_upgrade_detail_name_edit.add_theme_color_override("caret_color", Color(0.96, 0.88, 0.62, 1.0))
	_upgrade_detail_name_edit.text_submitted.connect(_on_upgrade_detail_name_submitted)
	_upgrade_detail_name_edit.focus_exited.connect(_on_upgrade_detail_name_focus_exited)
	header.add_child(_upgrade_detail_name_edit)

	_upgrade_detail_rarity_label = Label.new()
	_upgrade_detail_rarity_label.text = "★"
	_upgrade_detail_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_upgrade_detail_rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_detail_rarity_label.custom_minimum_size = Vector2(120.0, 34.0)
	_upgrade_detail_rarity_label.add_theme_font_size_override("font_size", 18)
	_upgrade_detail_rarity_label.add_theme_color_override("font_color", Color(0.96, 0.8, 0.34, 1.0))
	_upgrade_detail_rarity_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_upgrade_detail_rarity_label.add_theme_constant_override("outline_size", 3)
	header.add_child(_upgrade_detail_rarity_label)

	_upgrade_detail_profile_label = Label.new()
	_upgrade_detail_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_detail_profile_label.custom_minimum_size = Vector2(382.0, 52.0)
	_upgrade_detail_profile_label.add_theme_font_size_override("font_size", 14)
	_upgrade_detail_profile_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.62, 1.0))
	content.add_child(_upgrade_detail_profile_label)

	var evolution_panel := PanelContainer.new()
	evolution_panel.name = "EvolutionPreview"
	evolution_panel.custom_minimum_size = Vector2(382.0, 92.0)
	var evolution_style := StyleBoxFlat.new()
	evolution_style.bg_color = Color(0.025, 0.045, 0.035, 0.94)
	evolution_style.border_color = Color(0.42, 0.46, 0.28, 0.86)
	evolution_style.set_border_width_all(1)
	evolution_style.set_corner_radius_all(7)
	evolution_panel.add_theme_stylebox_override("panel", evolution_style)
	content.add_child(evolution_panel)
	var evolution_row := HBoxContainer.new()
	evolution_row.add_theme_constant_override("separation", 12)
	evolution_panel.add_child(evolution_row)
	var evolution_center := CenterContainer.new()
	evolution_center.custom_minimum_size = Vector2(88.0, 88.0)
	evolution_row.add_child(evolution_center)
	_upgrade_detail_evolution_icon = TextureRect.new()
	_upgrade_detail_evolution_icon.name = "EvolutionFormIcon"
	_upgrade_detail_evolution_icon.custom_minimum_size = Vector2(78.0, 78.0)
	_upgrade_detail_evolution_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_upgrade_detail_evolution_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	evolution_center.add_child(_upgrade_detail_evolution_icon)
	_upgrade_detail_evolution_label = Label.new()
	_upgrade_detail_evolution_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_detail_evolution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_detail_evolution_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_detail_evolution_label.custom_minimum_size = Vector2(270.0, 88.0)
	_upgrade_detail_evolution_label.add_theme_font_size_override("font_size", 15)
	_upgrade_detail_evolution_label.add_theme_color_override("font_color", Color(0.84, 0.82, 0.62, 1.0))
	evolution_row.add_child(_upgrade_detail_evolution_label)

	_upgrade_detail_stats_label = RichTextLabel.new()
	_upgrade_detail_stats_label.bbcode_enabled = true
	_upgrade_detail_stats_label.fit_content = true
	_upgrade_detail_stats_label.scroll_active = false
	_upgrade_detail_stats_label.custom_minimum_size = Vector2(362.0, 38.0)
	_upgrade_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_detail_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_detail_stats_label.add_theme_font_size_override("normal_font_size", 15)
	_upgrade_detail_stats_label.add_theme_color_override("default_color", Color(0.82, 0.86, 0.68, 1.0))
	_upgrade_detail_stats_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_upgrade_detail_stats_label.add_theme_constant_override("outline_size", 2)
	content.add_child(_upgrade_detail_stats_label)


func _make_faith_adder_stage() -> Control:
	var stage := Control.new()
	_adder_stage = stage
	stage.name = "FaithAdderStage"
	stage.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, ADDER_STAGE_HEIGHT)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.clip_contents = false

	_adder_glow = Sprite2D.new()
	_adder_glow.name = "FaithAdderGlow"
	var glow_texture := load(GLOW_TEXTURE) as Texture2D
	_adder_glow.texture = glow_texture
	_adder_glow.centered = true
	_adder_glow.position = Vector2(DRAWER_CONTENT_WIDTH * 0.5 + 2.0, 68.0 + (GLOW_SIZE.y * 0.5))
	if glow_texture != null:
		_adder_glow.scale = Vector2(GLOW_SIZE.x / glow_texture.get_width(), GLOW_SIZE.y / glow_texture.get_height())
	_adder_glow.modulate = Color(1.0, 1.0, 1.0, 0.82)
	stage.add_child(_adder_glow)

	var button := _make_faith_adder_button()
	button.position = Vector2((DRAWER_CONTENT_WIDTH - ADDER_SIZE.x) * 0.5, 20.0)
	stage.add_child(button)

	_faith_boost_aura = BoostAura.new()
	_faith_boost_aura.name = "FaithBoostAura"
	_faith_boost_aura.position = Vector2((DRAWER_CONTENT_WIDTH - 400.0) * 0.5, 256.0)
	_faith_boost_aura.size = Vector2(400.0, 126.0)
	_faith_boost_aura.call("setup", BoostAura.AuraMode.FAITH_COUNTER)
	stage.add_child(_faith_boost_aura)

	_faith_boost_glow_label = Label.new()
	_faith_boost_glow_label.name = "FaithBoostDigitGlow"
	_faith_boost_glow_label.text = _format_number(_faith_count, false, true)
	_faith_boost_glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faith_boost_glow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_faith_boost_glow_label.position = Vector2((DRAWER_CONTENT_WIDTH - 300.0) * 0.5, 282.0)
	_faith_boost_glow_label.size = Vector2(300.0, 72.0)
	_faith_boost_glow_label.pivot_offset = _faith_boost_glow_label.size * 0.5
	_faith_boost_glow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faith_boost_glow_label.visible = false
	_faith_boost_glow_label.add_theme_font_size_override("font_size", FAITH_COUNTER_VALUE_FONT_MAX)
	_faith_boost_glow_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.28, 0.42))
	_faith_boost_glow_label.add_theme_color_override("font_outline_color", Color(0.44, 1.0, 0.12, 0.42))
	_faith_boost_glow_label.add_theme_constant_override("outline_size", 16)
	stage.add_child(_faith_boost_glow_label)
	_fit_font_to_text(_faith_boost_glow_label, _faith_boost_glow_label.text, FAITH_COUNTER_VALUE_FONT_MAX, FAITH_COUNTER_VALUE_FONT_MIN, 7)

	_faith_value_label = Label.new()
	_faith_value_label.name = "FaithValue"
	_faith_value_label.text = _format_number(_faith_count, false, true)
	_faith_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faith_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_faith_value_label.position = Vector2((DRAWER_CONTENT_WIDTH - 300.0) * 0.5, 282.0)
	_faith_value_label.size = Vector2(300.0, 72.0)
	_faith_value_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_faith_value_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_faith_value_label.add_theme_font_size_override("font_size", FAITH_COUNTER_VALUE_FONT_MAX)
	_faith_value_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	_faith_value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_faith_value_label.add_theme_constant_override("outline_size", 4)
	_faith_value_label.mouse_entered.connect(_on_interactive_control_hovered.bind(_faith_value_label, true))
	_faith_value_label.mouse_exited.connect(_on_interactive_control_hovered.bind(_faith_value_label, false))
	_faith_value_label.gui_input.connect(_on_faith_value_gui_input)
	stage.add_child(_faith_value_label)
	_fit_font_to_text(_faith_value_label, _faith_value_label.text, FAITH_COUNTER_VALUE_FONT_MAX, FAITH_COUNTER_VALUE_FONT_MIN, 7)

	_faith_title_label = Label.new()
	_faith_title_label.name = "FaithTitle"
	_faith_title_label.text = "信仰点数"
	_faith_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faith_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_faith_title_label.position = Vector2((DRAWER_CONTENT_WIDTH - 118.0) * 0.5, 256.0)
	_faith_title_label.size = Vector2(118.0, 22.0)
	_faith_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faith_title_label.add_theme_font_size_override("font_size", 17)
	_faith_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62, 1.0))
	_faith_title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_faith_title_label.add_theme_constant_override("outline_size", 3)
	stage.add_child(_faith_title_label)

	_faith_growth_value_label = Label.new()
	_faith_growth_value_label.name = "FaithGrowthValue"
	_faith_growth_value_label.text = "+%s%s" % [_format_number(_faith_growth_rate, true), RATE_SUFFIX]
	_faith_growth_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faith_growth_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_faith_growth_value_label.position = Vector2((DRAWER_CONTENT_WIDTH - 240.0) * 0.5, 360.0)
	_faith_growth_value_label.size = Vector2(240.0, 28.0)
	_faith_growth_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faith_growth_value_label.add_theme_font_size_override("font_size", 22)
	_faith_growth_value_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.7, 1.0))
	_faith_growth_value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_faith_growth_value_label.add_theme_constant_override("outline_size", 3)
	stage.add_child(_faith_growth_value_label)

	var coin_center := CenterContainer.new()
	coin_center.name = "GoldBalanceCenter"
	coin_center.position = Vector2(0.0, 430.0)
	coin_center.size = Vector2(DRAWER_CONTENT_WIDTH, 52.0)
	coin_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(coin_center)

	var coin_row := HBoxContainer.new()
	coin_row.name = "GoldBalanceRow"
	coin_row.add_theme_constant_override("separation", 8)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_center.add_child(coin_row)

	_coin_icon = TextureRect.new()
	_coin_icon.name = "GoldIcon"
	_coin_icon.texture = _make_coin_icon_texture()
	_coin_icon.custom_minimum_size = Vector2(36.0, 36.0)
	_coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_coin_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	_coin_icon.tooltip_text = CurrencyDisplay.get_conversion_tooltip(_coin_count, _language)
	coin_row.add_child(_coin_icon)

	_coin_value_label = Label.new()
	_coin_value_label.name = "GoldValue"
	_coin_value_label.text = CurrencyDisplay.format_compact(_coin_count)
	_coin_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coin_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_value_label.custom_minimum_size = Vector2(1.0, 44.0)
	_coin_value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coin_value_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_coin_value_label.tooltip_text = CurrencyDisplay.get_conversion_tooltip(_coin_count, _language)
	_coin_value_label.add_theme_font_size_override("font_size", 34)
	_coin_value_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38, 1.0))
	_coin_value_label.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.01, 1.0))
	_coin_value_label.add_theme_constant_override("outline_size", 4)
	coin_row.add_child(_coin_value_label)
	return stage


func _make_coin_icon_texture() -> Texture2D:
	return CurrencyDisplay.make_icon_texture(_coin_count)


func _make_faith_adder_button() -> TextureButton:
	var button := TextureButton.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_adder_button = button
	button.name = "FaithAdder"
	button.texture_normal = load(ADDER_TEXTURE) as Texture2D
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = ADDER_SIZE
	button.size = ADDER_SIZE
	button.pivot_offset = ADDER_SIZE * 0.5
	button.mouse_entered.connect(_on_interactive_control_hovered.bind(button, true))
	button.mouse_exited.connect(_on_interactive_control_hovered.bind(button, false))
	button.pressed.connect(_on_adder_pressed.bind(button))
	return button


func _make_upgrade_scroller() -> ScrollContainer:
	var scroller := ScrollContainer.new()
	_upgrade_scroller = scroller
	scroller.name = "UpgradeScroller"
	scroller.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, _get_upgrade_scroll_height())
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.clip_contents = true
	scroller.mouse_filter = Control.MOUSE_FILTER_STOP

	var content_margin := MarginContainer.new()
	content_margin.name = "UpgradeScrollInset"
	content_margin.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, 1)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_top", UPGRADE_SCROLL_TOP_PADDING)
	content_margin.add_theme_constant_override("margin_bottom", UPGRADE_SCROLL_BOTTOM_PADDING)
	content_margin.add_child(_make_upgrade_column())
	scroller.add_child(content_margin)
	return scroller


func _get_upgrade_scroll_height() -> float:
	var fixed_height := (
		DRAWER_CONTENT_TOP_MARGIN
		+ 20.0
		+ (_adder_stage.custom_minimum_size.y if _adder_stage != null else ADDER_STAGE_HEIGHT)
		+ ERA_LABEL_HEIGHT
		+ 4.0
		+ 28.0
		+ 40.0
	)
	var available := float(_drawer_screen_size.y) - fixed_height
	return clampf(available, UPGRADE_SCROLL_MIN_HEIGHT, UPGRADE_SCROLL_MAX_HEIGHT)


static func _get_responsive_adder_stage_height(window_height: float) -> float:
	return clampf(window_height * 0.5, 220.0, ADDER_STAGE_HEIGHT)


func _refresh_adder_stage_geometry() -> void:
	if _adder_stage == null:
		return
	var stage_height := _get_responsive_adder_stage_height(float(_drawer_screen_size.y))
	var stage_scale := stage_height / ADDER_STAGE_HEIGHT
	_adder_stage.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, stage_height)
	_adder_stage.pivot_offset = Vector2(DRAWER_CONTENT_WIDTH * 0.5, 0.0)
	_adder_stage.scale = Vector2.ONE * stage_scale


func _make_upgrade_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "UpgradeColumn"
	column.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, 1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UPGRADE_ROW_GAP)

	_upgrade_level_labels.clear()
	_upgrade_name_labels.clear()
	_upgrade_cost_labels.clear()
	_upgrade_bonus_labels.clear()
	_upgrade_buttons.clear()
	_upgrade_last_levels.clear()
	_upgrade_affordables.clear()
	_upgrade_recovery_rings.clear()
	_upgrade_icons.clear()
	_upgrade_boost_auras.clear()
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		column.add_child(_make_pet_upgrade_row(String(pet_id_value)))
	for index in UPGRADE_LOCKED_ROWS:
		column.add_child(_make_locked_upgrade_row(index + PetCatalog.ACTIVE_DESKTOP_PETS.size() + 1))

	return column


func _make_pet_upgrade_row(pet_id: String) -> TextureButton:
	var pet_data := PetCatalog.get_definition(pet_id)
	var button := TextureButton.new()
	button.name = "%sUpgrade" % pet_id
	_configure_upgrade_row_button(button, "点击升级宠物，提高信仰增速", true)
	_set_upgrade_row_affordable(button, false)
	button.mouse_entered.connect(_on_interactive_control_hovered.bind(button, true))
	button.mouse_exited.connect(_on_interactive_control_hovered.bind(button, false))
	button.mouse_entered.connect(_on_upgrade_row_hovered.bind(pet_id, button, true))
	button.mouse_exited.connect(_on_upgrade_row_hovered.bind(pet_id, button, false))
	button.pressed.connect(_on_pet_upgrade_pressed.bind(pet_id, button))
	_upgrade_buttons[pet_id] = button

	var boost_aura: Control = BoostAura.new()
	boost_aura.name = "%sBoostAura" % pet_id
	boost_aura.size = UPGRADE_ROW_SIZE
	boost_aura.call("setup", BoostAura.AuraMode.PET_ROW)
	button.add_child(boost_aura)
	_upgrade_boost_auras[pet_id] = boost_aura

	button.add_child(_make_upgrade_profile_box(pet_id, pet_data))

	var name_label := Label.new()
	name_label.text = _get_pet_display_name(pet_id, pet_data)
	name_label.position = Vector2(106, 15)
	name_label.size = Vector2(UPGRADE_ROW_SIZE.x - 246.0, 28)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.64, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03, 1.0))
	name_label.add_theme_constant_override("outline_size", 3)
	button.add_child(name_label)
	_upgrade_name_labels[pet_id] = name_label
	_fit_font_to_text(name_label, name_label.text, 19, 12, 12)

	var cost_label := Label.new()
	cost_label.text = "消耗 0"
	cost_label.position = Vector2(108, 50)
	cost_label.size = Vector2(UPGRADE_ROW_SIZE.x - 244.0, 24)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.add_theme_font_size_override("font_size", 19)
	cost_label.add_theme_color_override("font_color", Color(0.84, 0.76, 0.66, 1.0))
	button.add_child(cost_label)
	_upgrade_cost_labels[pet_id] = cost_label

	var bonus_label := Label.new()
	bonus_label.text = "增速 0.00/s"
	bonus_label.position = Vector2(108, 74)
	bonus_label.size = Vector2(UPGRADE_ROW_SIZE.x - 244.0, 30)
	bonus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bonus_label.add_theme_font_size_override("font_size", 17)
	bonus_label.add_theme_color_override("font_color", Color(0.64, 0.82, 0.74, 1.0))
	bonus_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	bonus_label.add_theme_constant_override("outline_size", 3)
	button.add_child(bonus_label)
	_upgrade_bonus_labels[pet_id] = bonus_label

	var level_label := Label.new()
	level_label.text = "等级\nLv.1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.position = Vector2(UPGRADE_ROW_SIZE.x - 140.0, 28)
	level_label.size = Vector2(118, 60)
	level_label.pivot_offset = level_label.size * 0.5
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.add_theme_font_size_override("font_size", 25)
	level_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	level_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	level_label.add_theme_constant_override("outline_size", 4)
	button.add_child(level_label)
	_upgrade_level_labels[pet_id] = level_label
	_set_upgrade_row_locked_state(pet_id, not _has_upgrade_entry(pet_id))

	return button


func _make_locked_upgrade_row(display_index: int) -> TextureButton:
	var button := TextureButton.new()
	button.name = "LockedUpgrade%d" % display_index
	_configure_upgrade_row_button(button, "未解锁", true)
	_set_upgrade_row_affordable(button, false)
	button.tooltip_text = LOCKED_PET_TEXT

	var slot := PanelContainer.new()
	slot.name = "LockedProfileBox"
	slot.position = Vector2(17, 28)
	slot.size = UPGRADE_PROFILE_BOX_SIZE
	slot.custom_minimum_size = UPGRADE_PROFILE_BOX_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _make_upgrade_profile_box_style())
	button.add_child(slot)

	var question := Label.new()
	question.text = "?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	question.add_theme_font_size_override("font_size", 36)
	question.add_theme_color_override("font_color", Color(0.76, 0.8, 0.77, 1.0))
	slot.add_child(question)

	var name_label := Label.new()
	name_label.text = LOCKED_PET_TEXT
	name_label.position = Vector2(106, 22)
	name_label.size = Vector2(UPGRADE_ROW_SIZE.x - 242.0, 30)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.79, 1.0))
	button.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = LOCKED_PET_TEXT
	desc_label.position = Vector2(108, 61)
	desc_label.size = Vector2(UPGRADE_ROW_SIZE.x - 244.0, 24)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.69, 1.0))
	button.add_child(desc_label)

	var level_label := Label.new()
	level_label.text = LOCKED_PET_LEVEL_TEXT
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.position = Vector2(UPGRADE_ROW_SIZE.x - 140.0, 28)
	level_label.size = Vector2(118, 60)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.add_theme_font_size_override("font_size", 22)
	level_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.75, 1.0))
	button.add_child(level_label)

	return button


func _make_upgrade_profile_box(pet_id: String, pet_data: Dictionary) -> Control:
	var slot := PanelContainer.new()
	slot.name = "UpgradeProfileBox"
	slot.position = Vector2(17, 28)
	slot.size = UPGRADE_PROFILE_BOX_SIZE
	slot.custom_minimum_size = UPGRADE_PROFILE_BOX_SIZE
	slot.clip_contents = false
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _make_upgrade_profile_box_style())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(center)

	var icon := TextureRect.new()
	icon.texture = PetCatalog.make_icon_texture(String(pet_data.get("icon", "")), 12)
	icon.custom_minimum_size = UPGRADE_ICON_SIZE
	icon.size = UPGRADE_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	_upgrade_icons[pet_id] = icon

	var recovery_ring: Control = RecoveryProgressRing.new()
	recovery_ring.name = "%sRecoveryRing" % pet_id
	recovery_ring.position = Vector2(3.0, 3.0)
	recovery_ring.size = Vector2(62.0, 62.0)
	recovery_ring.z_index = 5
	recovery_ring.visible = false
	slot.add_child(recovery_ring)
	_upgrade_recovery_rings[pet_id] = recovery_ring

	return slot


func _make_upgrade_profile_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(6)
	return style


func _set_fitted_label_text(
	label: Label,
	next_text: String,
	max_size: int,
	min_size: int,
	comfortable_chars: int
) -> bool:
	if label == null or label.text == next_text:
		return false
	label.text = next_text
	_fit_font_to_text(label, next_text, max_size, min_size, comfortable_chars)
	return true


func _fit_font_to_text(control: Control, text: String, max_size: int, min_size: int, comfortable_chars: int) -> void:
	if control == null:
		return

	var font_size := max_size
	var font := _get_ui_font()
	var available_width := control.size.x - 8.0
	if control == _coin_value_label:
		# The account uses one exact, comma-separated number.  The HBox reports
		# its old intrinsic width during a balance refresh, so cap the measuring
		# width to the actual drawer space left beside the coin icon.
		available_width = minf(available_width, DRAWER_CONTENT_WIDTH - 60.0)
	if font != null and available_width > 0.0:
		while font_size > min_size:
			var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			if text_width <= available_width:
				break
			font_size -= 1
	else:
		var extra_chars := maxi(0, text.length() - comfortable_chars)
		font_size = maxi(min_size, max_size - int(ceil(float(extra_chars) * 2.5)))

	control.add_theme_font_size_override("font_size", font_size)


func _refresh_playtime_label() -> void:
	if _playtime_label == null:
		return
	var prefix := "PLAY" if _language == "en" else "时长"
	var next_text := "%s %s" % [prefix, _format_playtime(_playtime_seconds)]
	if _playtime_label.text == next_text:
		return
	_playtime_label.text = next_text
	_fit_font_to_text(_playtime_label, next_text, 13, 10, 16)


static func _format_playtime(seconds: float) -> String:
	var total := maxi(0, int(floor(maxf(0.0, seconds))))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var remaining_seconds := total % 60
	return "%02d:%02d:%02d" % [hours, minutes, remaining_seconds]


func _format_number(value: float, keep_fraction := false, whole_units := false) -> String:
	if whole_units:
		value = floor(value)
	var abs_value := absf(value)
	if whole_units and abs_value < 1000.0:
		return "%d" % int(value)
	if not keep_fraction and is_equal_approx(value, roundf(value)) and abs_value < 1000.0:
		return "%d" % int(roundf(value))

	var units := [
		{"threshold": 1.0e15, "suffix": "Qa"},
		{"threshold": 1.0e12, "suffix": "T"},
		{"threshold": 1.0e9, "suffix": "B"},
		{"threshold": 1.0e6, "suffix": "M"},
		{"threshold": 1.0e3, "suffix": "K"}
	]
	for unit in units:
		var threshold := float(unit.get("threshold", 1.0))
		if abs_value >= threshold:
			var scaled := value / threshold
			if absf(scaled) >= 100.0:
				return "%.0f%s" % [scaled, String(unit.get("suffix", ""))]
			if absf(scaled) >= 10.0:
				return "%.1f%s" % [scaled, String(unit.get("suffix", ""))]
			return "%.2f%s" % [scaled, String(unit.get("suffix", ""))]

	if keep_fraction:
		if abs_value >= 100.0:
			return "%.1f" % value
		return "%.2f" % value
	if abs_value >= 100.0:
		return "%.0f" % value
	if abs_value >= 10.0:
		return "%.1f" % value
	return "%.2f" % value


func _get_ui_theme() -> Theme:
	if _ui_theme != null:
		return _ui_theme

	_ui_theme = Theme.new()
	var font := _get_ui_font()
	if font != null:
		for theme_type in ["Label", "RichTextLabel", "LineEdit", "Button"]:
			_ui_theme.set_font("font", theme_type, font)
	return _ui_theme


func _get_ui_font() -> Font:
	if _ui_font != null:
		return _ui_font

	_ui_font = LanguageSettings.get_ui_font(_language)
	return _ui_font


func _apply_language_theme() -> void:
	_ui_font = null
	_ui_theme = null
	var language_theme := _get_ui_theme()
	if _menu_window != null:
		var menu_root := _menu_window.get_node_or_null("MenuHandleRoot") as Control
		if menu_root != null:
			menu_root.theme = language_theme
	if _drawer_root != null:
		_drawer_root.theme = language_theme
	if _upgrade_detail_window != null:
		_upgrade_detail_window.theme = language_theme
	var display_font := LanguageSettings.get_display_font(_language)
	var numeric_display_font := LanguageSettings.get_numeric_display_font()
	for display_label in [_menu_hint, _era_label]:
		if display_label != null:
			display_label.add_theme_font_override("font", display_font)
	for numeric_label in [_faith_value_label, _faith_boost_glow_label, _faith_growth_value_label, _coin_value_label]:
		if numeric_label != null:
			numeric_label.add_theme_font_override("font", numeric_display_font)


func _make_line_edit_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.028, 0.026, 0.58)
	style.border_color = Color(0.66, 0.78, 0.58, 0.82) if focused else Color(0.42, 0.54, 0.45, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _make_upgrade_detail_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.021, 0.025, 0.022, 0.96)
	style.border_color = Color(0.56, 0.54, 0.36, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	return style


func _make_bookmark_button(label_text: String, callback: Callable, bookmark_id := "") -> TextureButton:
	var button := TextureButton.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.name = "%sBookmark" % label_text
	button.texture_normal = load(BOOKMARK_TEXTURE) as Texture2D
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	_apply_texture_click_mask(button)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = BOOKMARK_SIZE
	button.size = button.custom_minimum_size
	button.pivot_offset = Vector2((DRAWER_BOOKMARK_WIDTH - 10.0) * 0.5, BOOKMARK_SIZE.y * 0.5)
	button.mouse_entered.connect(_animate_control_hover.bind(button, true))
	button.mouse_exited.connect(_animate_control_hover.bind(button, false))
	button.pressed.connect(_animate_control_press.bind(button))
	button.pressed.connect(callback)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = BOOKMARK_LABEL_POSITION
	label.size = BOOKMARK_LABEL_SIZE
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	button.add_child(label)
	if not bookmark_id.is_empty():
		_bookmark_labels[bookmark_id] = label

	return button


func _configure_upgrade_row_button(button: TextureButton, _tooltip_text: String, shrink_center: bool) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_normal = _get_upgrade_row_texture()
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = UPGRADE_ROW_SIZE
	button.size = UPGRADE_ROW_SIZE
	button.pivot_offset = UPGRADE_ROW_SIZE * 0.5
	if shrink_center:
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _set_upgrade_row_affordable(button: TextureButton, affordable: bool) -> void:
	button.disabled = not affordable
	button.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.74, 0.74, 0.74, 0.92)


func _has_upgrade_entry(pet_id: String) -> bool:
	if pet_id.is_empty():
		return false
	for entry_value in _upgrade_entries:
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == pet_id:
			return true
	return false


func _set_upgrade_row_locked_state(pet_id: String, locked: bool) -> void:
	var button := _upgrade_buttons.get(pet_id) as TextureButton
	if button != null:
		button.set_meta("pet_unlocked", not locked)
		if locked:
			_set_upgrade_row_affordable(button, false)
			button.tooltip_text = LOCKED_PET_TEXT

	var icon := _upgrade_icons.get(pet_id) as TextureRect
	if icon != null:
		icon.modulate = LOCKED_PET_SILHOUETTE_COLOR if locked else Color.WHITE
		if locked:
			var base_icon_path := String(PetCatalog.get_definition(pet_id).get("icon", ""))
			if String(icon.get_meta("source_path", "")) != base_icon_path:
				icon.texture = PetCatalog.make_icon_texture(base_icon_path, 12)
				icon.set_meta("source_path", base_icon_path)

	if not locked:
		return

	var name_label := _upgrade_name_labels.get(pet_id) as Label
	if name_label != null:
		_set_fitted_label_text(name_label, LOCKED_PET_TEXT, 19, 12, 12)
	var level_label := _upgrade_level_labels.get(pet_id) as Label
	if level_label != null:
		_set_fitted_label_text(level_label, LOCKED_PET_LEVEL_TEXT, 25, 18, 6)
	var cost_label := _upgrade_cost_labels.get(pet_id) as Label
	if cost_label != null:
		_set_fitted_label_text(cost_label, LOCKED_PET_TEXT, 19, 14, 6)
	var bonus_label := _upgrade_bonus_labels.get(pet_id) as Label
	if bonus_label != null:
		_set_fitted_label_text(bonus_label, LOCKED_PET_TEXT, 17, 11, 18)
	var recovery_ring := _upgrade_recovery_rings.get(pet_id) as Control
	if recovery_ring != null:
		recovery_ring.visible = false
	var boost_aura := _upgrade_boost_auras.get(pet_id) as Control
	if boost_aura != null:
		boost_aura.call("set_boost", false, 1.0)
	_upgrade_last_levels.erase(pet_id)
	_upgrade_affordables[pet_id] = false


func _set_any_boost_visual(active: bool, strongest_multiplier: float) -> void:
	var visual_state_changed := _faith_boost_active != active
	_faith_boost_active = active
	if _faith_boost_aura != null:
		_faith_boost_aura.call("set_boost", active, strongest_multiplier)
	# Multipliers can change while a boost remains active, but the labels only
	# need theme invalidation when that active/inactive state actually changes.
	if not visual_state_changed:
		return
	if _faith_boost_glow_label != null:
		_faith_boost_glow_label.visible = active
	if _faith_value_label != null:
		_faith_value_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.94, 0.52, 1.0) if active else Color(0.88, 1.0, 0.78, 1.0)
		)
		_faith_value_label.add_theme_color_override(
			"font_outline_color",
			Color(0.30, 0.82, 0.10, 0.96) if active else Color(0.02, 0.03, 0.02, 1.0)
		)
		_faith_value_label.add_theme_color_override(
			"font_shadow_color",
			Color(0.48, 1.0, 0.16, 0.72) if active else Color(0.0, 0.0, 0.0, 0.0)
		)
		_faith_value_label.add_theme_constant_override("outline_size", 10 if active else 4)
		_faith_value_label.add_theme_constant_override("shadow_outline_size", 12 if active else 0)
	if _faith_growth_value_label != null:
		_faith_growth_value_label.add_theme_color_override(
			"font_color",
			Color(0.90, 1.0, 0.52, 1.0) if active else Color(0.78, 1.0, 0.7, 1.0)
		)


func _play_boosted_faith_growth_pulse() -> void:
	if _faith_boost_glow_label == null or not _faith_boost_active:
		return
	# The counter stays steady; the rune spray carries the boost motion.
	_faith_boost_glow_label.scale = Vector2.ONE
	_faith_boost_glow_label.modulate = Color(1.0, 1.0, 0.76, 0.64)
	if _faith_value_label != null:
		_faith_value_label.scale = Vector2.ONE
	if _faith_boost_aura != null:
		_faith_boost_aura.call("notify_growth")


func _on_upgrade_row_hovered(pet_id: String, button: Control, hovered: bool) -> void:
	if not _has_upgrade_entry(pet_id):
		if _hovered_upgrade_pet_id == pet_id:
			_hovered_upgrade_pet_id = ""
			_hovered_upgrade_button = null
		return
	if hovered:
		_hovered_upgrade_pet_id = pet_id
		_hovered_upgrade_button = button
		_upgrade_detail_hover_time = 0.0
		_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE
	else:
		if _hovered_upgrade_pet_id == pet_id:
			_hovered_upgrade_pet_id = ""
			_hovered_upgrade_button = null
			_upgrade_detail_hover_time = 0.0
		_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE


func _update_upgrade_detail_hover(delta: float) -> void:
	if _upgrade_detail_window != null and _upgrade_detail_window.visible:
		if not _drawer_open or _drawer_window == null or not _drawer_window.visible:
			_hide_upgrade_detail_panel()
			return
		if _upgrade_detail_source_button == null or not is_instance_valid(_upgrade_detail_source_button):
			_hide_upgrade_detail_panel()
			return

		_position_upgrade_detail_window()
		var source_still_hovered := _hovered_upgrade_pet_id == _upgrade_detail_pet_id
		var editing_name := _upgrade_detail_name_edit != null and _upgrade_detail_name_edit.has_focus()
		var still_near_detail := source_still_hovered or editing_name or _upgrade_detail_panel_hovered or _is_mouse_in_upgrade_detail_safe_zone()
		if still_near_detail:
			_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE
		else:
			_upgrade_detail_hide_timer -= delta
			if _upgrade_detail_hide_timer <= 0.0:
				_hide_upgrade_detail_panel()

	if _hovered_upgrade_pet_id.is_empty() or _hovered_upgrade_button == null:
		return
	if not is_instance_valid(_hovered_upgrade_button):
		_hovered_upgrade_pet_id = ""
		_hovered_upgrade_button = null
		return
	if _upgrade_detail_window != null and _upgrade_detail_window.visible and _upgrade_detail_pet_id == _hovered_upgrade_pet_id:
		return

	_upgrade_detail_hover_time += delta
	if _upgrade_detail_hover_time >= UPGRADE_DETAIL_HOVER_DELAY:
		_show_upgrade_detail_panel(_hovered_upgrade_pet_id, _hovered_upgrade_button)


func _on_upgrade_detail_panel_hovered(hovered: bool) -> void:
	_upgrade_detail_panel_hovered = hovered
	if hovered:
		_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE


func _on_upgrade_detail_name_submitted(_submitted_text: String) -> void:
	_commit_upgrade_detail_name()


func _on_upgrade_detail_name_focus_exited() -> void:
	_commit_upgrade_detail_name()


func _commit_upgrade_detail_name() -> void:
	if _updating_upgrade_detail_name or _upgrade_detail_name_edit == null:
		return
	if _upgrade_detail_pet_id.is_empty():
		return

	var custom_name := _upgrade_detail_name_edit.text.strip_edges().left(40)
	if _upgrade_detail_name_edit.text != custom_name:
		_updating_upgrade_detail_name = true
		_upgrade_detail_name_edit.text = custom_name
		_updating_upgrade_detail_name = false
	if custom_name == _upgrade_detail_last_committed_name:
		return

	_upgrade_detail_last_committed_name = custom_name
	pet_rename_requested.emit(_upgrade_detail_pet_id, custom_name)


func _is_mouse_in_upgrade_detail_safe_zone() -> bool:
	if _upgrade_detail_window == null or not _upgrade_detail_window.visible:
		return false

	var mouse_position := Vector2(DisplayServer.mouse_get_position())
	var detail_rect := Rect2(
		Vector2(_upgrade_detail_window.position),
		Vector2(_upgrade_detail_window.size)
	).grow(UPGRADE_DETAIL_SAFE_PADDING)
	if detail_rect.has_point(mouse_position):
		return true

	var source_rect := _get_upgrade_detail_source_screen_rect()
	if source_rect.size == Vector2.ZERO:
		return false

	# Keep the card alive while the pointer crosses the bookmark strip between
	# the upgrade row and its separate native detail window.
	return detail_rect.merge(source_rect.grow(UPGRADE_DETAIL_SAFE_PADDING)).has_point(mouse_position)


func _get_upgrade_detail_source_screen_rect() -> Rect2:
	if _drawer_window == null or _upgrade_detail_source_button == null:
		return Rect2()
	if not is_instance_valid(_upgrade_detail_source_button):
		return Rect2()

	var source_position := Vector2(_drawer_window.position) + _upgrade_detail_source_button.global_position
	return Rect2(source_position, _upgrade_detail_source_button.size)


func _get_upgrade_level(entry: Dictionary) -> int:
	return maxi(1, int(entry.get("level", entry.get("upgrade_level", 1))))


func _get_upgrade_level_text(entry: Dictionary) -> String:
	return "Lv.%s" % _format_number(float(_get_upgrade_level(entry)), false)


func _get_current_growth_rate(entry: Dictionary) -> float:
	return maxf(0.0, float(entry.get(
		"current_fps",
		entry.get("current_growth_rate", entry.get("current_rate", 0.0))
	)))


func _get_next_growth_rate(entry: Dictionary) -> float:
	var current_rate := _get_current_growth_rate(entry)
	var fallback_rate := current_rate + maxf(0.0, float(entry.get("next_growth_bonus", 0.0)))
	return maxf(current_rate, float(entry.get(
		"next_fps",
		entry.get("next_growth_rate", entry.get("next_rate", fallback_rate))
	)))


func _get_upgrade_growth_text(entry: Dictionary) -> String:
	return ("RATE %s%s" if _language == "en" else "增速 %s%s") % [
		_format_number(_get_current_growth_rate(entry), true),
		RATE_SUFFIX
	]


func _get_upgrade_gain(entry: Dictionary) -> float:
	if entry.has("next_growth_bonus"):
		return maxf(0.0, float(entry.get("next_growth_bonus", 0.0)))
	return maxf(0.0, _get_next_growth_rate(entry) - _get_current_growth_rate(entry))


func _get_upgrade_gain_text(entry: Dictionary) -> String:
	return ("RATE GAIN +%s%s" if _language == "en" else "提升增速 +%s%s") % [
		_format_number(_get_upgrade_gain(entry), true),
		RATE_SUFFIX
	]


func _get_money_rate_text(entry: Dictionary) -> String:
	if bool(entry.get("recovering", false)):
		return (
			"RECOVERING  %s remaining"
			if _language == "en"
			else "休整中  剩余 %s"
		) % _format_duration(float(entry.get("recovery_seconds_remaining", 0.0)))
	var current_rate := maxf(0.0, float(entry.get("current_money_rate", 0.0)))
	return (
		"MONEY PRODUCTION  $%s/min"
		if _language == "en"
		else "金钱产出  $%s/分钟"
	) % _format_number(current_rate, true)


func _format_duration(seconds: float) -> String:
	var safe_seconds := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [int(safe_seconds / 60), safe_seconds % 60]


func _get_rarity_stars(entry: Dictionary, pet_data: Dictionary) -> int:
	return clampi(int(entry.get(
		"rarity_stars",
		pet_data.get("rarity_stars", pet_data.get("stars", 1))
	)), 1, 5)


func _get_rarity_stars_text(entry: Dictionary, pet_data := {}) -> String:
	var stars := ""
	for _index in _get_rarity_stars(entry, pet_data):
		stars += "★"
	return stars


func _get_pet_profile_text(entry: Dictionary, pet_data: Dictionary) -> String:
	var pet_id := String(entry.get("id", pet_data.get("id", "")))
	var fallback_age := (
		String(pet_data.get("age_text", pet_data.get("age", "不详")))
		if _language == "zh"
		else "Unknown"
	)
	var fallback_personality := PetCatalog.get_localized_field(pet_id, "personality", _language)
	if fallback_personality.is_empty():
		fallback_personality = "Still under observation" if _language == "en" else "尚待观察"
	var age_text := String(entry.get(
		"age_text",
		entry.get("age", fallback_age)
	)).strip_edges()
	var personality := String(entry.get(
		"personality",
		fallback_personality
	)).strip_edges()
	if age_text.is_empty():
		age_text = "Unknown" if _language == "en" else "不详"
	if personality.is_empty():
		personality = "Still under observation" if _language == "en" else "尚待观察"
	return ("Age: %s\nPersonality: %s" if _language == "en" else "年龄：%s\n性格：%s") % [age_text, personality]


func _get_upgrade_tooltip_text(entry: Dictionary) -> String:
	if bool(entry.get("recovering", false)):
		return ("Recovering · %s remaining" if _language == "en" else "休整中 · 剩余 %s") % _format_duration(float(entry.get("recovery_seconds_remaining", 0.0)))
	if bool(entry.get("is_max_level", false)):
		return "Maximum level" if _language == "en" else "宠物已满级"
	return "Upgrade faith and dropped-money production" if _language == "en" else "点击升级宠物，提高信仰与金钱掉落"


func _get_upgrade_cost_text(entry: Dictionary) -> String:
	if bool(entry.get("is_max_level", false)):
		return "MAX LEVEL" if _language == "en" else "已满级"
	return ("COST %s" if _language == "en" else "消耗 %s") % _format_number(float(entry.get("cost", 0.0)))


func _get_upgrade_evolution_text(entry: Dictionary, pet_id: String) -> String:
	if bool(entry.get("evolved", false)):
		var evolved_name := String(entry.get("evolution_name", "")).strip_edges()
		if evolved_name.is_empty():
			evolved_name = String(entry.get("name", pet_id))
		return ("EVOLUTION COMPLETE\n%s" if _language == "en" else "进化完成\n%s") % evolved_name
	var level := maxi(1, int(entry.get("level", 1)))
	return (
		"EVOLUTION AT LV.100\nCurrent Lv.%d" if _language == "en" else "Lv.100 进化\n当前 Lv.%d"
	) % level


func _get_pet_display_name(pet_id: String, pet_data: Dictionary) -> String:
	var localized_default := PetCatalog.get_localized_name(pet_id, _language)
	for entry_value in _upgrade_entries:
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == pet_id:
			return String(entry.get("name", localized_default))
	return localized_default if not localized_default.is_empty() else String(pet_data.get("name", pet_id))


func _show_upgrade_detail_panel(pet_id: String, button: Control) -> void:
	if _upgrade_detail_panel == null:
		return
	if not _has_upgrade_entry(pet_id):
		_hide_upgrade_detail_panel()
		return

	var pet_data := PetCatalog.get_definition(pet_id)
	var entry: Dictionary = {}
	for entry_value in _upgrade_entries:
		var entry_candidate: Dictionary = entry_value
		if String(entry_candidate.get("id", "")) == pet_id:
			entry = entry_candidate
			break

	var display_name := String(entry.get("name", _get_pet_display_name(pet_id, pet_data)))
	var switching_pet := _upgrade_detail_pet_id != pet_id
	if _upgrade_detail_name_edit != null and (switching_pet or not _upgrade_detail_name_edit.has_focus()):
		_updating_upgrade_detail_name = true
		_upgrade_detail_name_edit.text = display_name.left(40)
		_upgrade_detail_last_committed_name = _upgrade_detail_name_edit.text
		_updating_upgrade_detail_name = false
	if _upgrade_detail_rarity_label != null:
		_upgrade_detail_rarity_label.text = _get_rarity_stars_text(entry, pet_data)
	if _upgrade_detail_profile_label != null:
		_upgrade_detail_profile_label.text = _get_pet_profile_text(entry, pet_data)
	if _upgrade_detail_evolution_icon != null:
		var evolution_icon_path := String(entry.get("evolution_icon", pet_data.get("icon", "")))
		_upgrade_detail_evolution_icon.texture = PetCatalog.make_icon_texture(evolution_icon_path, 8)
		_upgrade_detail_evolution_icon.modulate = Color.WHITE if bool(entry.get("evolved", false)) else Color(0.24, 0.18, 0.22, 0.92)
	if _upgrade_detail_evolution_label != null:
		_upgrade_detail_evolution_label.text = _get_upgrade_evolution_text(entry, pet_id)
	if _upgrade_detail_stats_label != null:
		_upgrade_detail_stats_label.text = "[color=#b9dc8a]%s[/color]" % _get_money_rate_text(entry)

	_upgrade_detail_pet_id = pet_id
	_upgrade_detail_source_button = button
	_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE
	_position_upgrade_detail_window()
	_upgrade_detail_window.visible = true


func _position_upgrade_detail_window() -> void:
	if _upgrade_detail_window == null or _drawer_window == null or _upgrade_detail_source_button == null:
		return
	if not is_instance_valid(_upgrade_detail_source_button):
		return
	var screen_rect := _get_current_screen_usable_rect()
	var screen_left := screen_rect.position.x + 8
	var x := _drawer_window.position.x - _upgrade_detail_window.size.x - UPGRADE_DETAIL_GAP
	x = maxi(screen_left, x)
	var source_y := _drawer_window.position.y + int(round(_upgrade_detail_source_button.global_position.y)) - 16
	var min_y := screen_rect.position.y + UPGRADE_DETAIL_SCREEN_MARGIN
	var max_y := screen_rect.position.y + screen_rect.size.y - _upgrade_detail_window.size.y - UPGRADE_DETAIL_SCREEN_MARGIN
	var next_position := Vector2i(x, clampi(source_y, min_y, maxi(min_y, max_y)))
	if _upgrade_detail_window.position != next_position:
		_upgrade_detail_window.position = next_position


func _hide_upgrade_detail_panel(pet_id := "") -> void:
	if _upgrade_detail_panel == null or _upgrade_detail_window == null:
		return
	if not pet_id.is_empty() and (_hovered_upgrade_pet_id == pet_id or _upgrade_detail_panel_hovered):
		return
	_commit_upgrade_detail_name()
	_upgrade_detail_window.visible = false
	_upgrade_detail_pet_id = ""
	_upgrade_detail_source_button = null
	_hovered_upgrade_pet_id = ""
	_hovered_upgrade_button = null
	_upgrade_detail_hover_time = 0.0
	_upgrade_detail_panel_hovered = false
	_updating_upgrade_detail_name = false
	_upgrade_detail_last_committed_name = ""
	_upgrade_detail_hide_timer = 0.0


func _get_upgrade_row_texture() -> Texture2D:
	if _upgrade_row_texture != null:
		return _upgrade_row_texture

	_upgrade_row_texture = load(UPGRADE_TEXTURE) as Texture2D
	return _upgrade_row_texture


func _make_quit_button() -> Button:
	var button := _make_text_button("QUIT" if _language == "en" else "退出", _on_quit_pressed)
	button.name = "Quit"
	button.custom_minimum_size = Vector2(196.0, 36.0)
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.92, 0.84, 0.58, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.82, 0.72, 0.46, 1.0))
	button.add_theme_stylebox_override(
		"normal",
		_make_footer_button_style(Color(0.025, 0.052, 0.038, 0.92), Color(0.42, 0.40, 0.22, 0.88))
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_footer_button_style(Color(0.045, 0.082, 0.055, 0.98), Color(0.66, 0.60, 0.30, 1.0))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_make_footer_button_style(Color(0.018, 0.036, 0.027, 1.0), Color(0.76, 0.64, 0.30, 1.0))
	)
	return button


func _make_footer_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _make_text_button(button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = button_text
	button.custom_minimum_size = Vector2(92, 28)
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.mouse_entered.connect(_animate_control_hover.bind(button, true))
	button.mouse_exited.connect(_animate_control_hover.bind(button, false))
	button.pressed.connect(_animate_control_press.bind(button))
	button.pressed.connect(callback)
	return button


func _animate_control_hover(control: Control, hovered: bool) -> void:
	if control == null:
		return

	var target := Vector2.ONE * (1.05 if hovered else 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, 0.1)


func _animate_control_press(control: Control) -> void:
	if control == null:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE * 0.94, 0.05)
	tween.tween_property(control, "scale", Vector2.ONE * 1.03, 0.08)
	tween.tween_property(control, "scale", Vector2.ONE, 0.08)


func _on_interactive_control_hovered(control: Control, hovered: bool) -> void:
	_animate_control_hover(control, hovered)


func _pulse_count_label(label: Label) -> void:
	if label == null:
		return

	var previous_tween: Tween
	if label.has_meta("count_pulse_tween"):
		previous_tween = label.get_meta("count_pulse_tween") as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	label.scale = Vector2.ONE
	var tween := create_tween()
	label.set_meta("count_pulse_tween", tween)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.22, 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14)


func _play_adder_symbol_effect(button: Control) -> void:
	if button == null:
		return
	if _adder_symbol_burst_cooldown > 0.0:
		return

	var parent := button.get_parent() as Control
	if parent == null:
		return
	_adder_symbol_burst_cooldown = SYMBOL_BURST_COOLDOWN_SECONDS

	var source_center := button.position + (button.size * 0.5)
	var source_size := Vector2(
		minf(SYMBOL_SOURCE_SPREAD.x, button.size.x * 0.76),
		minf(SYMBOL_SOURCE_SPREAD.y, button.size.y * 0.72)
	)
	var source_top_left := source_center - (source_size * 0.5)

	for _index in SYMBOL_BURST_COUNT:
		var start_alpha := _rng.randf_range(0.34, 0.58)
		var symbol := _make_symbol_effect_rect(SYMBOL_EFFECT_SIZE, start_alpha)
		if symbol == null:
			continue

		var source_position := source_top_left + Vector2(
			_rng.randf_range(0.0, source_size.x),
			_rng.randf_range(0.0, source_size.y)
		)
		var start_offset := Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
		var start_position := source_position + start_offset - (SYMBOL_EFFECT_SIZE * 0.5)
		symbol.position = start_position
		var start_rotation := _rng.randf_range(-0.35, 0.35)
		symbol.rotation = start_rotation
		var start_scale := _rng.randf_range(0.66, 0.96)
		symbol.scale = Vector2.ONE * start_scale
		parent.add_child(symbol)

		var life_time := _rng.randf_range(0.62, 0.84)
		var velocity := Vector2(
			_rng.randf_range(-58.0, 58.0),
			_rng.randf_range(-38.0, 24.0)
		)
		var gravity := _rng.randf_range(760.0, 980.0)
		var spin := _rng.randf_range(-2.4, 2.4)
		var fade_start := _rng.randf_range(0.38, 0.5)

		var tween := create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.tween_method(
			Callable(self, "_update_adder_symbol_particle").bind(
				symbol,
				start_position,
				velocity,
				gravity,
				start_rotation,
				spin,
				start_scale,
				start_alpha,
				fade_start,
				life_time
			),
			0.0,
			life_time,
			life_time
		)
		tween.tween_callback(Callable(symbol, "queue_free"))


func _update_adder_symbol_particle(
	age: float,
	symbol: TextureRect,
	start_position: Vector2,
	velocity: Vector2,
	gravity: float,
	start_rotation: float,
	spin: float,
	start_scale: float,
	start_alpha: float,
	fade_start: float,
	life_time: float
) -> void:
	if symbol == null or not is_instance_valid(symbol):
		return

	symbol.position = start_position + (velocity * age) + Vector2(0.0, 0.5 * gravity * age * age)
	symbol.rotation = start_rotation + (spin * age)
	symbol.scale = Vector2.ONE * start_scale

	var fade_progress := 0.0
	if age > fade_start:
		fade_progress = clampf((age - fade_start) / maxf(0.001, life_time - fade_start), 0.0, 1.0)
	symbol.modulate = Color(1.0, 1.0, 1.0, start_alpha * (1.0 - fade_progress))


func _make_symbol_effect_rect(size: Vector2, alpha: float) -> TextureRect:
	_load_symbol_effect_textures()
	if _symbol_effect_textures.is_empty():
		return null
	var texture := _symbol_effect_textures[_rng.randi_range(0, _symbol_effect_textures.size() - 1)]
	if texture == null:
		return null

	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = size
	rect.pivot_offset = size * 0.5
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 60
	rect.modulate = Color(1.0, 1.0, 1.0, alpha)
	return rect


func _load_symbol_effect_textures() -> void:
	if not _symbol_effect_textures.is_empty():
		return
	for texture_path in SYMBOL_EFFECT_TEXTURES:
		var texture := load(String(texture_path)) as Texture2D
		if texture != null:
			_symbol_effect_textures.append(texture)


func _play_upgrade_effect(button: Control) -> void:
	if button == null:
		return

	var texture := load(UPGRADE_EFFECT_TEXTURE) as Texture2D
	if texture == null:
		return

	var effect := TextureRect.new()
	effect.name = "UpgradeEffect"
	effect.texture = texture
	effect.size = UPGRADE_EFFECT_SIZE
	effect.position = (button.size - UPGRADE_EFFECT_SIZE) * 0.5
	effect.pivot_offset = UPGRADE_EFFECT_SIZE * 0.5
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.z_index = 60
	effect.scale = Vector2.ONE * 0.68
	effect.modulate = Color(1.0, 1.0, 1.0, 0.95)
	button.add_child(effect)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "scale", Vector2.ONE * 1.08, 0.18)
	tween.parallel().tween_property(effect, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	tween.tween_callback(Callable(effect, "queue_free"))


func _on_adder_pressed(button: Control) -> void:
	faith_add_requested.emit(1)
	if button != null:
		_animate_control_press(button)
		_play_adder_symbol_effect(button)
	if _faith_value_label != null:
		_pulse_count_label(_faith_value_label)


func _on_faith_value_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_adder_pressed(_adder_button)
			_faith_value_label.accept_event()


func _get_button_hit_image(button: TextureButton) -> Image:
	var key := button.name
	var cached_image := _menu_hit_images.get(key) as Image
	if cached_image != null:
		return cached_image

	var texture := button.texture_normal
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		return null

	image.convert(Image.FORMAT_RGBA8)
	_menu_hit_images[key] = image
	return image


func _apply_texture_click_mask(button: TextureButton) -> void:
	var image := _get_button_hit_image(button)
	if image == null or image.is_empty():
		return

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.08)
	button.texture_click_mask = bitmap


func _place_menu_window() -> void:
	if _menu_window == null:
		return

	var usable_rect := _get_current_screen_usable_rect()
	var screen_rect := _get_current_screen_rect()
	_menu_window.size = MENU_WINDOW_SIZE
	var anchor := (
		clampf(_menu_handle_anchor, 0.0, 1.0)
		if _menu_handle_anchor >= 0.0
		else _get_default_menu_anchor(screen_rect, usable_rect)
	)
	_menu_window.position = _get_menu_position_for_anchor(
		screen_rect,
		usable_rect,
		MENU_WINDOW_SIZE,
		anchor
	)
	if not _menu_window.visible:
		_menu_window.visible = true


func _refresh_drawer_geometry(keep_current_slide := true) -> void:
	if _drawer_window == null:
		return

	var screen_rect := _get_current_screen_usable_rect()
	var screen_right := screen_rect.position.x + screen_rect.size.x
	var open_x := screen_right - DRAWER_WIDTH
	open_x = maxi(screen_rect.position.x, open_x)
	var drawer_width := screen_right - open_x
	drawer_width = maxi(1, drawer_width)

	_drawer_screen_position = Vector2i(open_x, screen_rect.position.y)
	_drawer_closed_x = screen_right
	_drawer_screen_size = Vector2i(drawer_width, screen_rect.size.y)
	_drawer_window.size = _drawer_screen_size
	_refresh_adder_stage_geometry()
	var window_right := float(_drawer_screen_size.x)
	var window_bottom := float(_drawer_screen_size.y)
	var panel_left := minf(float(DRAWER_BOOKMARK_WIDTH - 10), window_right)
	var bookmark_left := minf(float(BOOKMARK_SAFE_INSET_X), panel_left)
	var bookmark_layout := _get_bookmark_layout(window_bottom)
	var bookmark_top := bookmark_layout.x
	var bookmark_scale := bookmark_layout.y
	var bookmark_bottom := minf(bookmark_top + (BOOKMARK_CONTAINER_HEIGHT * bookmark_scale), window_bottom)
	if _bookmark_container != null:
		_bookmark_container.position = Vector2(BOOKMARK_SAFE_INSET_X, bookmark_top)
		_bookmark_container.scale = Vector2.ONE * bookmark_scale
	_drawer_window.mouse_passthrough_polygon = PackedVector2Array([
		Vector2(panel_left, 0.0),
		Vector2(window_right, 0.0),
		Vector2(window_right, window_bottom),
		Vector2(panel_left, window_bottom),
		Vector2(panel_left, bookmark_bottom),
		Vector2(bookmark_left, bookmark_bottom),
		Vector2(bookmark_left, bookmark_top),
		Vector2(panel_left, bookmark_top)
	])
	if _drawer_background != null:
		_drawer_background.position = Vector2(DRAWER_BOOKMARK_WIDTH - 10, 0)
		_drawer_background.size = Vector2(DRAWER_PANEL_WIDTH + 10, _drawer_screen_size.y)
	if _drawer_panel != null:
		_drawer_panel.size = Vector2(DRAWER_PANEL_WIDTH + 10, _drawer_screen_size.y)
	if _drawer_symbol_layer != null:
		_drawer_symbol_layer.size = Vector2(DRAWER_PANEL_WIDTH + 10, _drawer_screen_size.y)
	if _upgrade_scroller != null:
		_upgrade_scroller.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, _get_upgrade_scroll_height())
	if _drawer_root != null:
		_drawer_root.position = Vector2.ZERO

	_place_menu_window()
	_drawer_target_x = _drawer_screen_position.x if _drawer_open else _drawer_closed_x
	if keep_current_slide:
		return

	var x := _drawer_screen_position.x if _drawer_open else _drawer_closed_x
	_drawer_window.position = Vector2i(x, _drawer_screen_position.y)


static func _get_bookmark_layout(window_height: float) -> Vector2:
	var safe_height := maxf(0.0, window_height)
	if safe_height <= 0.0:
		return Vector2.ZERO
	var margin := minf(BOOKMARK_SCREEN_MARGIN, safe_height * 0.5)
	var top := minf(
		BOOKMARK_CONTAINER_TOP,
		maxf(margin, safe_height - BOOKMARK_CONTAINER_HEIGHT - margin)
	)
	var scale := clampf((safe_height - top - margin) / BOOKMARK_CONTAINER_HEIGHT, 0.0, 1.0)
	return Vector2(top, scale)


func _update_drawer_slide(delta: float) -> void:
	if _drawer_window == null or not _drawer_window.visible:
		return

	var current := float(_drawer_window.position.x)
	var target := float(_drawer_target_x)
	if is_equal_approx(current, target):
		if not _drawer_open:
			_drawer_window.visible = false
		return

	var next_x := move_toward(current, target, DRAWER_SLIDE_SPEED * delta)
	_drawer_window.position = Vector2i(int(round(next_x)), _drawer_screen_position.y)
	if _upgrade_detail_window != null and _upgrade_detail_window.visible:
		_position_upgrade_detail_window()

	if is_equal_approx(next_x, target) and not _drawer_open:
		_drawer_window.visible = false


func _toggle_drawer() -> void:
	var opening := not _drawer_open
	if not opening:
		_hide_upgrade_detail_panel()
	_refresh_drawer_geometry()
	_drawer_open = opening
	_drawer_target_x = _drawer_screen_position.x if _drawer_open else _drawer_closed_x

	if _drawer_open:
		refresh_pet_upgrades(_upgrade_entries)
		if not _drawer_window.visible or _drawer_window.position.x < _drawer_screen_position.x or _drawer_window.position.x >= _drawer_closed_x:
			_drawer_window.position = Vector2i(_drawer_closed_x, _drawer_screen_position.y)
		_drawer_window.visible = true
		drawer_opened.emit()


func _get_menu_handle_x(screen_rect: Rect2i) -> int:
	var drawer_open_x := maxi(screen_rect.position.x, screen_rect.position.x + screen_rect.size.x - DRAWER_WIDTH)
	var target_x := drawer_open_x - MENU_TO_DRAWER_GAP - MENU_WINDOW_SIZE.x
	return maxi(screen_rect.position.x, target_x)


func _get_default_menu_anchor(screen_rect: Rect2i, usable_rect: Rect2i) -> float:
	var edge := _get_taskbar_edge(screen_rect, usable_rect)
	if edge == TaskbarEdge.LEFT or edge == TaskbarEdge.RIGHT:
		return 1.0
	var span := maxi(0, usable_rect.size.x - MENU_WINDOW_SIZE.x)
	if span <= 0:
		return 0.0
	return clampf(
		float(_get_menu_handle_x(screen_rect) - usable_rect.position.x) / float(span),
		0.0,
		1.0
	)


static func _get_taskbar_edge(screen_rect: Rect2i, usable_rect: Rect2i) -> int:
	var gaps := [
		maxi(0, screen_rect.end.y - usable_rect.end.y),
		maxi(0, usable_rect.position.y - screen_rect.position.y),
		maxi(0, usable_rect.position.x - screen_rect.position.x),
		maxi(0, screen_rect.end.x - usable_rect.end.x)
	]
	var edge := TaskbarEdge.BOTTOM
	var largest_gap := int(gaps[edge])
	for candidate in range(1, gaps.size()):
		if int(gaps[candidate]) > largest_gap:
			edge = candidate
			largest_gap = int(gaps[candidate])
	return edge


static func _get_menu_position_for_anchor(
	screen_rect: Rect2i,
	usable_rect: Rect2i,
	window_size: Vector2i,
	anchor: float
) -> Vector2i:
	var safe_anchor := clampf(anchor, 0.0, 1.0) if is_finite(anchor) else 0.0
	var edge := _get_taskbar_edge(screen_rect, usable_rect)
	if edge == TaskbarEdge.LEFT or edge == TaskbarEdge.RIGHT:
		var vertical_span := maxi(0, usable_rect.size.y - window_size.y)
		var y := usable_rect.position.y + int(round(float(vertical_span) * safe_anchor))
		var x := (
			usable_rect.position.x
			if edge == TaskbarEdge.LEFT
			else maxi(usable_rect.position.x, usable_rect.end.x - window_size.x)
		)
		return Vector2i(x, y)

	var horizontal_span := maxi(0, usable_rect.size.x - window_size.x)
	var x := usable_rect.position.x + int(round(float(horizontal_span) * safe_anchor))
	var y := (
		usable_rect.position.y
		if edge == TaskbarEdge.TOP
		else maxi(usable_rect.position.y, usable_rect.end.y - window_size.y)
	)
	return Vector2i(x, y)


func _on_menu_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_menu_drag_active = true
			_menu_drag_moved = false
			_menu_drag_suppress_click = false
			_menu_drag_start_pointer = Vector2(DisplayServer.mouse_get_position())
			_menu_drag_pointer_offset = _menu_drag_start_pointer - Vector2(_menu_window.position)
		else:
			_finish_menu_drag()
		return

	if not event is InputEventMouseMotion or not _menu_drag_active:
		return
	var pointer := Vector2(DisplayServer.mouse_get_position())
	if not _menu_drag_moved and pointer.distance_to(_menu_drag_start_pointer) >= MENU_DRAG_THRESHOLD:
		_menu_drag_moved = true
		_menu_drag_suppress_click = true
	if not _menu_drag_moved:
		return
	_update_menu_anchor_from_pointer(pointer)
	if _menu_button != null:
		_menu_button.accept_event()


func _update_menu_anchor_from_pointer(pointer: Vector2) -> void:
	if _menu_window == null:
		return
	var screen_rect := _get_current_screen_rect()
	var usable_rect := _get_current_screen_usable_rect()
	var desired_position := pointer - _menu_drag_pointer_offset
	var edge := _get_taskbar_edge(screen_rect, usable_rect)
	if edge == TaskbarEdge.LEFT or edge == TaskbarEdge.RIGHT:
		var span := maxi(0, usable_rect.size.y - MENU_WINDOW_SIZE.y)
		_menu_handle_anchor = (
			clampf((desired_position.y - usable_rect.position.y) / float(span), 0.0, 1.0)
			if span > 0
			else 0.0
		)
	else:
		var span := maxi(0, usable_rect.size.x - MENU_WINDOW_SIZE.x)
		_menu_handle_anchor = (
			clampf((desired_position.x - usable_rect.position.x) / float(span), 0.0, 1.0)
			if span > 0
			else 0.0
		)
	_place_menu_window()


func _finish_menu_drag() -> void:
	if not _menu_drag_active:
		return
	_menu_drag_active = false
	if not _menu_drag_moved:
		return
	menu_handle_moved.emit(get_menu_handle_anchor())
	call_deferred("_clear_menu_drag_suppression")


func _clear_menu_drag_suppression() -> void:
	_menu_drag_moved = false
	_menu_drag_suppress_click = false


func _get_current_screen_usable_rect() -> Rect2i:
	# Display backends can briefly report a zero-sized work area while a GPU,
	# monitor, or taskbar layout is being re-enumerated.  Never propagate that
	# transient value into the drawer window geometry.
	return DisplayLayout.sanitize_usable_rect(
		DisplayServer.screen_get_usable_rect(_get_current_screen())
	)


func _get_current_screen_rect() -> Rect2i:
	var screen := _get_current_screen()
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))


func _get_current_screen() -> int:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS if _menu_drag_active else -1
	if screen < 0 and DisplayLayout.can_query_window_screen(_menu_window):
		screen = DisplayServer.window_get_current_screen(_menu_window.get_window_id())
	if screen < 0 and DisplayLayout.can_query_window_screen(_drawer_window):
		screen = DisplayServer.window_get_current_screen(_drawer_window.get_window_id())
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	if screen < 0:
		screen = 0
	return screen


func _on_menu_button_hovered(hovered: bool) -> void:
	if _menu_button == null:
		return
	_animate_control_hover(_menu_button, hovered)
	if _menu_hint != null:
		_menu_hint.visible = hovered


func _on_pet_upgrade_pressed(pet_id: String, button: Control) -> void:
	var affordable: bool = _upgrade_affordables.get(pet_id, false) == true
	pet_upgrade_requested.emit(pet_id)
	if button != null:
		_animate_control_press(button)
		if affordable:
			_play_upgrade_effect(button)


func _on_inventory_bookmark_pressed() -> void:
	_hide_upgrade_detail_panel()
	inventory_requested.emit()


func _on_shop_bookmark_pressed() -> void:
	_hide_upgrade_detail_panel()
	shop_requested.emit()


func _on_gacha_bookmark_pressed() -> void:
	_hide_upgrade_detail_panel()
	gacha_requested.emit()


func _on_news_bookmark_pressed() -> void:
	_hide_upgrade_detail_panel()
	news_requested.emit()


func _on_settings_bookmark_pressed() -> void:
	_hide_upgrade_detail_panel()
	settings_requested.emit()


func _on_drawer_close_bookmark_pressed() -> void:
	_hide_upgrade_detail_panel()
	if _drawer_open:
		_toggle_drawer()


func _on_drawer_button_pressed() -> void:
	if _menu_drag_suppress_click:
		return
	_toggle_drawer()


func _on_quit_pressed() -> void:
	_hide_upgrade_detail_panel()
	quit_requested.emit()
