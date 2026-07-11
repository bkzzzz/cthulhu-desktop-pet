extends Node

signal inventory_requested
signal shop_requested
signal quit_requested
signal pet_count_upgrade_requested(pet_id: String)
signal pet_rename_requested(pet_id: String, custom_name: String)
signal faith_add_requested(amount: int)
signal offering_drop_requested(offering: Dictionary)

# Dependencies
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const WindowsClickthroughController = preload("res://scripts/windows_clickthrough_controller.gd")

# Window and drawer layout
const DESKTOP_MARGIN_X := 24
const DRAWER_BOOKMARK_WIDTH := 226
const DRAWER_PANEL_WIDTH := 548
const DRAWER_WIDTH := DRAWER_BOOKMARK_WIDTH + DRAWER_PANEL_WIDTH
const DRAWER_CONTENT_MARGIN_X := 34
const DRAWER_CONTENT_WIDTH := DRAWER_PANEL_WIDTH - (DRAWER_CONTENT_MARGIN_X * 2)
const DRAWER_SLIDE_SPEED := 1800.0
const DRAWER_CONTENT_TOP_MARGIN := 24
const MENU_WINDOW_SIZE := Vector2i(610, 220)
const MENU_TO_DRAWER_GAP := 24
const POSITION_RETRY_FRAMES := 90

# UI assets
const QUIT_BUTTON_TEXTURE := "res://assets/ui/testElements/Quit.png"
const MENU_ICON_TEXTURE := "res://assets/ui/newElements/菜单栏呼出.png"
const ALTAR_TEXTURE := "res://assets/ui/newElements/祭坛.png"
const DRAWER_BACKGROUND_TEXTURE := "res://assets/ui/newElements/菜单栏2.png"
const DRAWER_BACKGROUND_BOTTOM_CROP := 570.0
const ADDER_TEXTURE := "res://assets/ui/newElements/adder.png"
const GLOW_TEXTURE := "res://assets/ui/newElements/glow.png"
const UPGRADE_EFFECT_TEXTURE := "res://assets/ui/newElements/upgradeEffect.png"
const ALTAR_NOTICE_TEXTURE := "res://assets/ui/newElements/感叹号.png"
const INTERACTION_CURSOR_TEXTURE := "res://assets/ui/newElements/鼠标交互.png"
const UPGRADE_TEXTURE := "res://assets/ui/testElements/upgrade.png"
const BOOKMARK_TEXTURE := "res://assets/ui/newElements/书签.png"
const UI_FONT := "res://assets/ui/font/NormalFont.ttf"

# Core UI sizing
const MENU_ICON_SIZE := Vector2(218.0, 140.0)
const ALTAR_SIZE := Vector2(320.0, 160.0)
const CULT_WINDOW_SIZE := Vector2i(460, 500)
const ADDER_STAGE_HEIGHT := 392.0
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
const UPGRADE_SCROLL_MIN_HEIGHT := 320.0
const UPGRADE_SCROLL_MAX_HEIGHT := 760.0
const OFFERING_SPAWN_CHANCE := 0.9
const OFFERING_SLOT_SIZE := Vector2(174.0, 124.0)
const OFFERING_ICON_SIZE := Vector2(78.0, 78.0)
const OFFERING_FAITH_MIN := 2
const OFFERING_FAITH_MAX := 8
const OFFERING_GAIN_SECONDS := 20.0

# Offering and particle data
const OFFERING_ITEMS := [
	{"name": "红果", "texture": "res://assets/ui/foods/红果.png"},
	{"name": "华夫饼", "texture": "res://assets/ui/foods/华夫饼.png"},
	{"name": "鸡肉", "texture": "res://assets/ui/foods/鸡肉.png"},
	{"name": "九转大肠", "texture": "res://assets/ui/foods/九转大肠.png"},
	{"name": "米糊", "texture": "res://assets/ui/foods/米糊.png"},
	{"name": "浓汤", "texture": "res://assets/ui/foods/浓汤.png"},
	{"name": "起司", "texture": "res://assets/ui/foods/起司.png"},
	{"name": "血杯", "texture": "res://assets/ui/foods/血杯.png"},
	{"name": "眼球汤", "texture": "res://assets/ui/foods/眼球汤.png"},
	{"name": "鱼", "texture": "res://assets/ui/foods/鱼.png"}
]
const SYMBOL_EFFECT_TEXTURES := [
	"res://assets/ui/newElements/符号特效1.png",
	"res://assets/ui/newElements/符号特效2.png",
	"res://assets/ui/newElements/符号特效3.png",
	"res://assets/ui/newElements/符号特效4.png",
	"res://assets/ui/newElements/符号特效5.png"
]
const SYMBOL_BURST_COUNT := 14
const SYMBOL_EFFECT_SIZE := Vector2(6.0, 9.0)
const SYMBOL_SOURCE_SPREAD := Vector2(168.0, 196.0)
const DRAWER_SYMBOL_COUNT := 22
const DRAWER_SYMBOL_SIZE := Vector2(28.0, 40.0)
const DRAWER_SYMBOL_SPEED_MIN := 18.0
const DRAWER_SYMBOL_SPEED_MAX := 42.0
const UPGRADE_EFFECT_SIZE := Vector2(150.0, 142.0)
const ALTAR_NOTICE_SIZE := Vector2(54.0, 54.0)
const INTERACTION_CURSOR_SIZE := Vector2i(72, 92)
const INTERACTION_CURSOR_HOTSPOT := Vector2(10.0, 16.0)
const UPGRADE_DETAIL_HOVER_DELAY := 0.45
const UPGRADE_DETAIL_HIDE_GRACE := 0.22
const BOOKMARK_SIZE := Vector2(258.0, 82.0)
const BOOKMARK_SAFE_INSET_X := 8.0
const BOOKMARK_LABEL_POSITION := Vector2(84.0, 0.0)
const BOOKMARK_LABEL_SIZE := Vector2(124.0, 82.0)

# Window controls and drawer state
var _menu_window: Window
var _menu_button: TextureButton
var _menu_hint: Label
var _altar_button: TextureButton
var _altar_hint: Label
var _altar_notice: TextureRect
var _altar_notice_tween: Tween
var _altar_notice_base_position := Vector2.ZERO
var _altar_notice_jitter_timer := 0.0
var _cult_window: Window
var _cult_window_name_edit: LineEdit
var _cult_faith_label: Label
var _cult_growth_label: Label
var _drawer_window: Window
var _drawer_root: Control
var _drawer_background: TextureRect
var _drawer_panel: PanelContainer
var _drawer_symbol_layer: Control
var _drawer_symbols: Array[TextureRect] = []
var _upgrade_detail_panel: PanelContainer
var _upgrade_detail_name_edit: LineEdit
var _upgrade_detail_level_label: Label
var _upgrade_detail_desc_label: Label
var _upgrade_detail_stats_label: RichTextLabel
var _hovered_upgrade_pet_id := ""
var _hovered_upgrade_button: Control
var _upgrade_detail_hover_time := 0.0
var _upgrade_detail_hide_timer := 0.0
var _upgrade_detail_panel_hovered := false
var _upgrade_detail_pet_id := ""
var _upgrade_detail_source_button: Control
var _updating_upgrade_detail_name := false
var _adder_glow: Sprite2D
var _adder_button: TextureButton
var _upgrade_scroller: ScrollContainer
var _drawer_open := false
var _drawer_target_x := 0
var _drawer_closed_x := 0
var _drawer_screen_position := Vector2i.ZERO
var _drawer_screen_size := Vector2i(DRAWER_WIDTH, 720)
var _position_retry_frames := 0

# Faith, upgrades, and offerings state
var _faith_value_label: Label
var _faith_title_label: Label
var _faith_growth_value_label: Label
var _cult_name := "无名教派"
var _faith_count := 0.0
var _follower_count := 0
var _faith_growth_rate := 0.0
var _follower_growth_rate := 0.0
var _upgrade_entries := []
var _upgrade_buttons := {}
var _upgrade_name_labels := {}
var _upgrade_count_labels := {}
var _upgrade_cost_labels := {}
var _upgrade_bonus_labels := {}
var _upgrade_next_growth_bonuses := {}
var _upgrade_total_growth_bonuses := {}
var _upgrade_bonus_hovered := {}
var _upgrade_last_counts := {}
var _upgrade_affordables := {}
var _ui_theme: Theme
var _ui_font: Font
var _upgrade_row_texture: Texture2D
var _interaction_cursor_texture: Texture2D
var _interaction_cursor_depth := 0
var _menu_hit_images := {}
var _menu_window_mouse_passthrough := false
var _menu_clickthrough_controller: RefCounted
var _offering_grid: Control
var _offering_status_label: Label
var _offering_entries: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


# Lifecycle
func setup() -> void:
	_rng.randomize()
	_offering_entries.clear()
	_offering_entries.append(_make_random_offering())
	_create_toggle_button()
	_create_drawer_window()
	_position_retry_frames = POSITION_RETRY_FRAMES
	call_deferred("_place_menu_window")
	call_deferred("_refresh_drawer_geometry")


func _process(delta: float) -> void:
	if _position_retry_frames > 0:
		_position_retry_frames -= 1
		_place_menu_window()
		_refresh_drawer_geometry()

	_update_drawer_slide(delta)
	_update_menu_window_mouse_passthrough()
	_update_upgrade_detail_hover(delta)
	_update_drawer_background_symbols(delta)
	_refresh_interaction_cursor()
	if _adder_glow != null:
		_adder_glow.rotation += GLOW_ROTATION_SPEED * delta
	_update_altar_notice(delta)


# Public refresh API
func refresh_faith(faith_count: float, growth_rate: float) -> void:
	_faith_count = faith_count
	_faith_growth_rate = growth_rate

	if _faith_value_label != null:
		var next_faith_text := _format_number(faith_count, false, true)
		if _faith_value_label.text != next_faith_text:
			var needs_refit := _faith_value_label.text.length() != next_faith_text.length()
			_faith_value_label.text = next_faith_text
			if needs_refit:
				_fit_font_to_text(_faith_value_label, _faith_value_label.text, FAITH_COUNTER_VALUE_FONT_MAX, FAITH_COUNTER_VALUE_FONT_MIN, 7)

	if _faith_growth_value_label != null:
		var next_growth_text := "+%s / 秒" % _format_number(_faith_growth_rate, true)
		if _faith_growth_value_label.text != next_growth_text:
			var needs_refit := _faith_growth_value_label.text.length() != next_growth_text.length()
			_faith_growth_value_label.text = next_growth_text
			if needs_refit:
				_fit_font_to_text(_faith_growth_value_label, _faith_growth_value_label.text, 22, 14, 10)

func refresh_pet_upgrade_counts(entries: Array) -> void:
	var next_entries := []
	for entry_value in entries:
		var entry: Dictionary = entry_value
		next_entries.append(entry.duplicate(true))
		var pet_id := String(entry.get("id", ""))
		var count_label := _upgrade_count_labels.get(pet_id) as Label
		var name_label := _upgrade_name_labels.get(pet_id) as Label
		var count := int(entry.get("count", 1))
		if name_label != null:
			name_label.text = "领袖 · %s" % String(entry.get("name", _get_pet_display_name(pet_id, PetCatalog.get_definition(pet_id))))
			_fit_font_to_text(name_label, name_label.text, 19, 12, 12)
		if count_label != null:
			count_label.text = "种群数量\n%d" % count
			_fit_font_to_text(count_label, count_label.text, 25, 18, 6)
			if _upgrade_last_counts.has(pet_id) and count > int(_upgrade_last_counts.get(pet_id, count)):
				_pulse_count_label(count_label)
		_upgrade_last_counts[pet_id] = count

		var cost_label := _upgrade_cost_labels.get(pet_id) as Label
		var affordable: bool = entry.get("affordable", false) == true
		_upgrade_affordables[pet_id] = affordable
		var upgrade_button := _upgrade_buttons.get(pet_id) as TextureButton
		if upgrade_button != null:
			_set_upgrade_row_affordable(upgrade_button, affordable)

		if cost_label != null:
			var cost := float(entry.get("cost", 0))
			cost_label.text = "消耗 %s" % _format_number(cost)
			_fit_font_to_text(cost_label, cost_label.text, 19, 14, 6)
			cost_label.add_theme_color_override("font_color", Color(0.78, 0.96, 0.76, 1.0) if affordable else Color(0.84, 0.76, 0.66, 1.0))

		var bonus_label := _upgrade_bonus_labels.get(pet_id) as Label
		if bonus_label != null:
			var next_bonus := float(entry.get("next_growth_bonus", 0.0))
			var total_bonus := float(entry.get("total_growth_bonus", 0.0))
			_upgrade_next_growth_bonuses[pet_id] = next_bonus
			_upgrade_total_growth_bonuses[pet_id] = total_bonus
			_refresh_upgrade_bonus_label(pet_id)

	_upgrade_entries = next_entries
	if _upgrade_detail_panel != null and _upgrade_detail_panel.visible and not _upgrade_detail_pet_id.is_empty():
		var editing_name := _upgrade_detail_name_edit != null and _upgrade_detail_name_edit.has_focus()
		if not editing_name and _upgrade_detail_source_button != null and is_instance_valid(_upgrade_detail_source_button):
			_show_upgrade_detail_panel(_upgrade_detail_pet_id, _upgrade_detail_source_button)
	_refresh_cult_window()


func refresh_followers(follower_count: int, growth_rate: float) -> void:
	_follower_count = maxi(0, follower_count)
	_follower_growth_rate = maxf(0.0, growth_rate)
	_refresh_cult_summary()


# Menu and drawer windows
func _create_toggle_button() -> void:
	_menu_window = Window.new()
	_menu_window.name = "MenuHandleWindow"
	_menu_window.title = "菜单栏"
	_menu_window.size = MENU_WINDOW_SIZE
	_menu_window.borderless = true
	_menu_window.always_on_top = false
	_menu_window.unresizable = true
	_menu_window.transparent = true
	_menu_window.transparent_bg = true
	_menu_window.visible = false
	add_child(_menu_window)
	_menu_clickthrough_controller = WindowsClickthroughController.new()
	_menu_clickthrough_controller.setup(_menu_window, "menu_window")
	_set_menu_window_mouse_passthrough(true)

	var menu_root := Control.new()
	menu_root.name = "MenuHandleRoot"
	menu_root.theme = _get_ui_theme()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_window.add_child(menu_root)

	_altar_button = TextureButton.new()
	_altar_button.name = "CultAltar"
	_altar_button.texture_normal = load(ALTAR_TEXTURE) as Texture2D
	_altar_button.texture_hover = _altar_button.texture_normal
	_altar_button.texture_pressed = _altar_button.texture_normal
	_apply_texture_click_mask(_altar_button)
	_altar_button.ignore_texture_size = true
	_altar_button.stretch_mode = TextureButton.STRETCH_SCALE
	_altar_button.size = ALTAR_SIZE
	_altar_button.position = Vector2(4.0, MENU_WINDOW_SIZE.y - ALTAR_SIZE.y)
	_altar_button.pivot_offset = ALTAR_SIZE * 0.5
	_altar_button.mouse_entered.connect(_on_altar_hovered.bind(true))
	_altar_button.mouse_exited.connect(_on_altar_hovered.bind(false))
	_altar_button.pressed.connect(_on_altar_pressed)
	menu_root.add_child(_altar_button)

	_altar_hint = Label.new()
	_altar_hint.text = "祭坛"
	_altar_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_altar_hint.position = Vector2(_altar_button.position.x + 74.0, _altar_button.position.y - 26.0)
	_altar_hint.size = Vector2(172.0, 24.0)
	_altar_hint.visible = false
	_altar_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_altar_hint.z_index = 3
	_altar_hint.add_theme_font_size_override("font_size", 16)
	_altar_hint.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	_altar_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 1.0))
	_altar_hint.add_theme_constant_override("outline_size", 4)
	menu_root.add_child(_altar_hint)

	_altar_notice = TextureRect.new()
	_altar_notice.name = "OfferingNotice"
	_altar_notice.texture = load(ALTAR_NOTICE_TEXTURE) as Texture2D
	_altar_notice.size = ALTAR_NOTICE_SIZE
	_altar_notice.position = _altar_button.position + Vector2(248.0, -22.0)
	_altar_notice_base_position = _altar_notice.position
	_altar_notice.pivot_offset = ALTAR_NOTICE_SIZE * 0.5
	_altar_notice.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_altar_notice.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_altar_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_altar_notice.z_index = 5
	menu_root.add_child(_altar_notice)
	_refresh_altar_notice()

	_menu_button = TextureButton.new()
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
	_menu_button.pressed.connect(_on_drawer_button_pressed)
	menu_root.add_child(_menu_button)

	_menu_hint = Label.new()
	_menu_hint.text = "菜单栏"
	_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_hint.position = Vector2(_menu_button.position.x, 5)
	_menu_hint.size = Vector2(_menu_button.size.x, 24)
	_menu_hint.visible = false
	_menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_hint.z_index = 3
	_menu_hint.add_theme_font_size_override("font_size", 16)
	_menu_hint.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	_menu_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.03, 1.0))
	_menu_hint.add_theme_constant_override("outline_size", 4)
	menu_root.add_child(_menu_hint)


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

	var bookmarks := VBoxContainer.new()
	bookmarks.name = "DrawerBookmarks"
	bookmarks.position = Vector2(BOOKMARK_SAFE_INSET_X, 106)
	bookmarks.size = Vector2(BOOKMARK_SIZE.x, 340)
	bookmarks.z_index = 1
	bookmarks.add_theme_constant_override("separation", 12)
	_drawer_root.add_child(bookmarks)

	bookmarks.add_child(_make_bookmark_button("仓库", _on_inventory_bookmark_pressed))
	bookmarks.add_child(_make_bookmark_button("商店", _on_shop_bookmark_pressed))
	bookmarks.add_child(_make_bookmark_button("收起", _on_drawer_close_bookmark_pressed))
	var bookmark_spacer := Control.new()
	bookmark_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bookmarks.add_child(bookmark_spacer)

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
	var upgrade_offset := Control.new()
	upgrade_offset.custom_minimum_size = Vector2(1, 8)
	content.add_child(upgrade_offset)
	content.add_child(_make_upgrade_scroller())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	content.add_child(footer)
	footer.add_child(_make_text_button("收起菜单", _on_drawer_button_pressed))
	footer.add_child(_make_texture_button("Quit", QUIT_BUTTON_TEXTURE, _on_quit_pressed))

	_refresh_drawer_geometry(false)


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


# Upgrade panel UI
func _create_upgrade_detail_panel() -> void:
	_upgrade_detail_panel = PanelContainer.new()
	_upgrade_detail_panel.name = "UpgradeDetailPanel"
	_upgrade_detail_panel.visible = false
	_upgrade_detail_panel.position = Vector2(DRAWER_BOOKMARK_WIDTH + 24.0, 96.0)
	_upgrade_detail_panel.size = Vector2(396.0, 242.0)
	_upgrade_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_detail_panel.z_index = 20
	_upgrade_detail_panel.add_theme_stylebox_override("panel", _make_upgrade_detail_style())
	_upgrade_detail_panel.mouse_entered.connect(_on_upgrade_detail_panel_hovered.bind(true))
	_upgrade_detail_panel.mouse_exited.connect(_on_upgrade_detail_panel_hovered.bind(false))
	_drawer_root.add_child(_upgrade_detail_panel)

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
	_upgrade_detail_name_edit.placeholder_text = "领袖名字"
	_upgrade_detail_name_edit.custom_minimum_size = Vector2(232.0, 34.0)
	_upgrade_detail_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_detail_name_edit.add_theme_stylebox_override("normal", _make_upgrade_detail_name_style(false))
	_upgrade_detail_name_edit.add_theme_stylebox_override("focus", _make_upgrade_detail_name_style(true))
	_upgrade_detail_name_edit.add_theme_font_size_override("font_size", 18)
	_upgrade_detail_name_edit.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62, 1.0))
	_upgrade_detail_name_edit.add_theme_color_override("font_placeholder_color", Color(0.56, 0.54, 0.43, 0.86))
	_upgrade_detail_name_edit.add_theme_color_override("font_selected_color", Color(0.02, 0.03, 0.02, 1.0))
	_upgrade_detail_name_edit.add_theme_color_override("selection_color", Color(0.66, 0.72, 0.44, 0.82))
	_upgrade_detail_name_edit.add_theme_color_override("caret_color", Color(0.96, 0.88, 0.62, 1.0))
	_upgrade_detail_name_edit.text_changed.connect(_on_upgrade_detail_name_changed)
	header.add_child(_upgrade_detail_name_edit)

	_upgrade_detail_level_label = Label.new()
	_upgrade_detail_level_label.text = "种群数量 1"
	_upgrade_detail_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_upgrade_detail_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_detail_level_label.custom_minimum_size = Vector2(120.0, 34.0)
	_upgrade_detail_level_label.add_theme_font_size_override("font_size", 16)
	_upgrade_detail_level_label.add_theme_color_override("font_color", Color(0.82, 0.96, 0.66, 1.0))
	_upgrade_detail_level_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_upgrade_detail_level_label.add_theme_constant_override("outline_size", 3)
	header.add_child(_upgrade_detail_level_label)

	_upgrade_detail_desc_label = Label.new()
	_upgrade_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_detail_desc_label.custom_minimum_size = Vector2(358.0, 38.0)
	_upgrade_detail_desc_label.add_theme_font_size_override("font_size", 14)
	_upgrade_detail_desc_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.62, 1.0))
	content.add_child(_upgrade_detail_desc_label)

	_upgrade_detail_stats_label = RichTextLabel.new()
	_upgrade_detail_stats_label.bbcode_enabled = true
	_upgrade_detail_stats_label.fit_content = true
	_upgrade_detail_stats_label.scroll_active = false
	_upgrade_detail_stats_label.custom_minimum_size = Vector2(362.0, 116.0)
	_upgrade_detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_detail_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_detail_stats_label.add_theme_font_size_override("normal_font_size", 15)
	_upgrade_detail_stats_label.add_theme_color_override("default_color", Color(0.82, 0.86, 0.68, 1.0))
	_upgrade_detail_stats_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_upgrade_detail_stats_label.add_theme_constant_override("outline_size", 2)
	content.add_child(_upgrade_detail_stats_label)


func _make_faith_adder_stage() -> Control:
	var stage := Control.new()
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

	_faith_value_label = Label.new()
	_faith_value_label.name = "FaithValue"
	_faith_value_label.text = _format_number(_faith_count, false, true)
	_faith_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faith_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_faith_value_label.position = Vector2((DRAWER_CONTENT_WIDTH - 280.0) * 0.5, 286.0)
	_faith_value_label.size = Vector2(280.0, 58.0)
	_faith_value_label.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_faith_title_label.position = Vector2((DRAWER_CONTENT_WIDTH - 118.0) * 0.5, 263.0)
	_faith_title_label.size = Vector2(118.0, 22.0)
	_faith_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faith_title_label.add_theme_font_size_override("font_size", 17)
	_faith_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62, 1.0))
	_faith_title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_faith_title_label.add_theme_constant_override("outline_size", 3)
	stage.add_child(_faith_title_label)

	_faith_growth_value_label = Label.new()
	_faith_growth_value_label.name = "FaithGrowthValue"
	_faith_growth_value_label.text = "+%s / 秒" % _format_number(_faith_growth_rate, true)
	_faith_growth_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faith_growth_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_faith_growth_value_label.position = Vector2((DRAWER_CONTENT_WIDTH - 220.0) * 0.5, 365.0)
	_faith_growth_value_label.size = Vector2(220.0, 24.0)
	_faith_growth_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faith_growth_value_label.add_theme_font_size_override("font_size", 22)
	_faith_growth_value_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.7, 1.0))
	_faith_growth_value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	_faith_growth_value_label.add_theme_constant_override("outline_size", 3)
	stage.add_child(_faith_growth_value_label)
	return stage


func _make_faith_adder_button() -> TextureButton:
	var button := TextureButton.new()
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


# Upgrade list rows
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
	var fixed_height := DRAWER_CONTENT_TOP_MARGIN + 20.0 + ADDER_STAGE_HEIGHT + 8.0 + 34.0
	var available := float(_drawer_screen_size.y) - fixed_height
	return clampf(available, UPGRADE_SCROLL_MIN_HEIGHT, UPGRADE_SCROLL_MAX_HEIGHT)


func _make_upgrade_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "UpgradeColumn"
	column.custom_minimum_size = Vector2(DRAWER_CONTENT_WIDTH, 1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UPGRADE_ROW_GAP)

	_upgrade_count_labels.clear()
	_upgrade_name_labels.clear()
	_upgrade_cost_labels.clear()
	_upgrade_bonus_labels.clear()
	_upgrade_next_growth_bonuses.clear()
	_upgrade_total_growth_bonuses.clear()
	_upgrade_bonus_hovered.clear()
	_upgrade_buttons.clear()
	_upgrade_last_counts.clear()
	_upgrade_affordables.clear()
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		column.add_child(_make_pet_upgrade_row(String(pet_id_value)))
	for index in UPGRADE_LOCKED_ROWS:
		column.add_child(_make_locked_upgrade_row(index + PetCatalog.ACTIVE_DESKTOP_PETS.size() + 1))

	return column


func _make_pet_upgrade_row(pet_id: String) -> TextureButton:
	var pet_data := PetCatalog.get_definition(pet_id)
	var button := TextureButton.new()
	button.name = "%sUpgrade" % pet_id
	_configure_upgrade_row_button(button, "增加 %s 的种群数量" % String(pet_data.get("name", pet_id)), true)
	_set_upgrade_row_affordable(button, false)
	button.mouse_entered.connect(_on_interactive_control_hovered.bind(button, true))
	button.mouse_exited.connect(_on_interactive_control_hovered.bind(button, false))
	button.mouse_entered.connect(_on_upgrade_row_hovered.bind(pet_id, button, true))
	button.mouse_exited.connect(_on_upgrade_row_hovered.bind(pet_id, button, false))
	button.pressed.connect(_on_pet_upgrade_pressed.bind(pet_id, button))
	_upgrade_buttons[pet_id] = button

	button.add_child(_make_upgrade_profile_box(pet_data))

	var name_label := Label.new()
	name_label.text = "领袖 · %s" % _get_pet_display_name(pet_id, pet_data)
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
	bonus_label.text = "+0.00/s"
	bonus_label.position = Vector2(108, 74)
	bonus_label.size = Vector2(UPGRADE_ROW_SIZE.x - 244.0, 30)
	bonus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bonus_label.add_theme_font_size_override("font_size", 20)
	bonus_label.add_theme_color_override("font_color", Color(0.64, 0.82, 0.74, 1.0))
	bonus_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	bonus_label.add_theme_constant_override("outline_size", 3)
	button.add_child(bonus_label)
	_upgrade_bonus_labels[pet_id] = bonus_label

	var count_label := Label.new()
	count_label.text = "种群数量\n1"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.position = Vector2(UPGRADE_ROW_SIZE.x - 140.0, 28)
	count_label.size = Vector2(118, 60)
	count_label.pivot_offset = count_label.size * 0.5
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 25)
	count_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	count_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	count_label.add_theme_constant_override("outline_size", 4)
	button.add_child(count_label)
	_upgrade_count_labels[pet_id] = count_label

	return button


func _make_locked_upgrade_row(display_index: int) -> TextureButton:
	var button := TextureButton.new()
	button.name = "LockedUpgrade%d" % display_index
	_configure_upgrade_row_button(button, "未解锁", true)
	_set_upgrade_row_affordable(button, false)

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
	name_label.text = "未知领袖 %02d" % display_index
	name_label.position = Vector2(106, 22)
	name_label.size = Vector2(UPGRADE_ROW_SIZE.x - 242.0, 30)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.79, 1.0))
	button.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = "未解锁"
	desc_label.position = Vector2(108, 61)
	desc_label.size = Vector2(UPGRADE_ROW_SIZE.x - 244.0, 24)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.69, 1.0))
	button.add_child(desc_label)

	var count_label := Label.new()
	count_label.text = "种群数量\n--"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.position = Vector2(UPGRADE_ROW_SIZE.x - 140.0, 28)
	count_label.size = Vector2(118, 60)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 22)
	count_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.75, 1.0))
	button.add_child(count_label)

	return button


func _make_upgrade_profile_box(pet_data: Dictionary) -> Control:
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

	return slot


func _make_upgrade_profile_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(6)
	return style


func _refresh_altar_notice() -> void:
	if _altar_notice == null:
		return

	var has_offering := not _offering_entries.is_empty()
	_altar_notice.visible = has_offering
	if has_offering and _altar_notice_jitter_timer <= 0.0:
		_altar_notice_jitter_timer = _rng.randf_range(0.4, 1.0)
	else:
		_altar_notice.position = _altar_notice_base_position
		_altar_notice.rotation = 0.0


func _update_altar_notice(delta: float) -> void:
	if _altar_notice == null or not _altar_notice.visible:
		return

	_altar_notice_jitter_timer -= delta
	if _altar_notice_jitter_timer > 0.0:
		return

	_play_altar_notice_jitter()
	_altar_notice_jitter_timer = _rng.randf_range(1.2, 2.6)


func _play_altar_notice_jitter() -> void:
	if _altar_notice == null:
		return

	if _altar_notice_tween != null and is_instance_valid(_altar_notice_tween):
		_altar_notice_tween.kill()

	_altar_notice.position = _altar_notice_base_position
	_altar_notice.rotation = 0.0
	_altar_notice_tween = create_tween()
	_altar_notice_tween.set_trans(Tween.TRANS_SINE)
	_altar_notice_tween.set_ease(Tween.EASE_IN_OUT)
	_altar_notice_tween.tween_property(_altar_notice, "position", _altar_notice_base_position + Vector2(-3.0, -2.0), 0.05)
	_altar_notice_tween.parallel().tween_property(_altar_notice, "rotation", deg_to_rad(-8.0), 0.05)
	_altar_notice_tween.tween_property(_altar_notice, "position", _altar_notice_base_position + Vector2(4.0, 1.0), 0.06)
	_altar_notice_tween.parallel().tween_property(_altar_notice, "rotation", deg_to_rad(9.0), 0.06)
	_altar_notice_tween.tween_property(_altar_notice, "position", _altar_notice_base_position, 0.08)
	_altar_notice_tween.parallel().tween_property(_altar_notice, "rotation", 0.0, 0.08)


# Cult and offering window
func _create_cult_window() -> void:
	_cult_window = Window.new()
	_cult_window.name = "CultCompositionWindow"
	_cult_window.title = "祭坛"
	_cult_window.size = CULT_WINDOW_SIZE
	_cult_window.borderless = true
	_cult_window.always_on_top = false
	_cult_window.unresizable = true
	_cult_window.transparent = true
	_cult_window.transparent_bg = true
	_cult_window.visible = false
	_cult_window.close_requested.connect(_close_cult_window)
	add_child(_cult_window)

	var root := Control.new()
	root.name = "CultCompositionRoot"
	root.theme = _get_ui_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cult_window.add_child(root)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _make_cult_window_style())
	root.add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	frame.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	var title := Label.new()
	title.text = "祭坛"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(34, 30)
	close_button.pressed.connect(_close_cult_window)
	header.add_child(close_button)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	content.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "教派"
	name_label.custom_minimum_size = Vector2(48, 30)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.64, 0.82, 0.74, 1.0))
	name_row.add_child(name_label)

	_cult_window_name_edit = LineEdit.new()
	_cult_window_name_edit.text = _cult_name
	_cult_window_name_edit.placeholder_text = "教派名字"
	_cult_window_name_edit.custom_minimum_size = Vector2(286, 30)
	_cult_window_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cult_window_name_edit.add_theme_stylebox_override("normal", _make_line_edit_style(false))
	_cult_window_name_edit.add_theme_stylebox_override("focus", _make_line_edit_style(true))
	_cult_window_name_edit.add_theme_color_override("font_color", Color(0.92, 0.88, 0.7, 1.0))
	_cult_window_name_edit.add_theme_color_override("caret_color", Color(0.96, 0.9, 0.68, 1.0))
	_cult_window_name_edit.add_theme_font_size_override("font_size", 16)
	_cult_window_name_edit.text_changed.connect(_on_cult_name_changed)
	name_row.add_child(_cult_window_name_edit)

	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 10)
	content.add_child(summary)

	_cult_faith_label = Label.new()
	_cult_faith_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cult_faith_label.add_theme_font_size_override("font_size", 16)
	_cult_faith_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	summary.add_child(_cult_faith_label)

	_cult_growth_label = Label.new()
	_cult_growth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cult_growth_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cult_growth_label.add_theme_font_size_override("font_size", 16)
	_cult_growth_label.add_theme_color_override("font_color", Color(0.64, 0.82, 0.74, 1.0))
	summary.add_child(_cult_growth_label)

	var section_label := Label.new()
	section_label.text = "教众数量"
	section_label.add_theme_font_size_override("font_size", 18)
	section_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66, 1.0))
	content.add_child(section_label)

	var count_note := Label.new()
	count_note.text = "教众会提高信仰增长，贡品可用于即时供奉。"
	count_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count_note.custom_minimum_size = Vector2(410, 42)
	count_note.add_theme_font_size_override("font_size", 14)
	count_note.add_theme_color_override("font_color", Color(0.64, 0.82, 0.74, 1.0))
	content.add_child(count_note)

	var offering_header := HBoxContainer.new()
	offering_header.add_theme_constant_override("separation", 10)
	content.add_child(offering_header)

	var offering_title := Label.new()
	offering_title.text = "贡品系统"
	offering_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offering_title.add_theme_font_size_override("font_size", 18)
	offering_title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66, 1.0))
	offering_header.add_child(offering_title)

	_offering_grid = CenterContainer.new()
	_offering_grid.custom_minimum_size = Vector2(410, 160)
	_offering_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_offering_grid)

	_fit_font_to_text(_cult_window_name_edit, _cult_window_name_edit.text, 16, 10, 10)
	_refresh_cult_summary()
	_refresh_cult_window(true)


func _make_cult_composition_row(entry: Dictionary) -> TextureButton:
	var pet_id := String(entry.get("id", ""))
	var pet_data := PetCatalog.get_definition(pet_id)
	var affordable: bool = entry.get("affordable", false) == true
	var row := TextureButton.new()
	row.name = "%sCultRow" % pet_id
	_configure_upgrade_row_button(row, "增加 %s 的种群数量" % String(pet_data.get("name", pet_id)), false)
	_set_upgrade_row_affordable(row, affordable)
	row.mouse_entered.connect(_animate_control_hover.bind(row, true))
	row.mouse_exited.connect(_animate_control_hover.bind(row, false))
	row.pressed.connect(_on_pet_upgrade_pressed.bind(pet_id, row))

	row.add_child(_make_upgrade_profile_box(pet_data))

	var name_label := Label.new()
	name_label.text = "领袖 · %s" % String(entry.get("name", pet_data.get("name", pet_id)))
	name_label.position = Vector2(106, 22)
	name_label.size = Vector2(UPGRADE_ROW_SIZE.x - 242.0, 30)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.64, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03, 1.0))
	name_label.add_theme_constant_override("outline_size", 3)
	row.add_child(name_label)
	_fit_font_to_text(name_label, name_label.text, 19, 12, 12)

	var count := int(entry.get("count", 1))
	var level_label := Label.new()
	level_label.text = "种群数量\n%d" % count
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.position = Vector2(UPGRADE_ROW_SIZE.x - 140.0, 28)
	level_label.size = Vector2(118, 60)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	level_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	level_label.add_theme_constant_override("outline_size", 4)
	row.add_child(level_label)
	_fit_font_to_text(level_label, level_label.text, 20, 14, 6)

	var cost := float(entry.get("cost", 0))
	var cost_label := Label.new()
	cost_label.text = "消耗 %s" % _format_number(cost)
	cost_label.position = Vector2(108, 66)
	cost_label.size = Vector2(UPGRADE_ROW_SIZE.x - 244.0, 24)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.add_theme_font_size_override("font_size", 14)
	_fit_font_to_text(cost_label, cost_label.text, 14, 10, 6)
	cost_label.add_theme_color_override("font_color", Color(0.78, 0.94, 0.76, 1.0) if affordable else Color(0.9, 0.48, 0.42, 1.0))
	row.add_child(cost_label)

	return row


func try_spawn_offering() -> bool:
	if not _offering_entries.is_empty():
		_refresh_cult_window(true)
		_refresh_altar_notice()
		return false
	if _rng.randf() > OFFERING_SPAWN_CHANCE:
		_refresh_cult_window(true)
		_refresh_altar_notice()
		return false

	_offering_entries.append(_make_random_offering())
	_refresh_cult_window(true)
	_refresh_altar_notice()
	return true


func _make_random_offering() -> Dictionary:
	var entry: Dictionary = OFFERING_ITEMS[_rng.randi_range(0, OFFERING_ITEMS.size() - 1)].duplicate(true)
	entry["faith"] = _rng.randi_range(OFFERING_FAITH_MIN, OFFERING_FAITH_MAX)
	return entry


func _get_offering_estimated_gain(entry: Dictionary) -> int:
	var base_gain := maxi(1, int(entry.get("faith", 1)))
	var scaled_gain := int(round(_faith_growth_rate * float(base_gain) * OFFERING_GAIN_SECONDS))
	return maxi(base_gain, scaled_gain)


func _refresh_offering_grid() -> void:
	if _offering_grid == null:
		return

	for child in _offering_grid.get_children():
		_offering_grid.remove_child(child)
		child.queue_free()

	if _offering_entries.is_empty():
		_offering_grid.add_child(_make_empty_offering_label())
		return

	_offering_grid.add_child(_make_offering_slot(_offering_entries[0]))


func _make_empty_offering_label() -> Label:
	var label := Label.new()
	_offering_status_label = label
	label.text = "暂无贡品\n放出宠物时有概率出现"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(260, 88)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.64, 0.82, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_offering_slot(entry: Dictionary) -> Control:
	var slot := PanelContainer.new()
	slot.name = "%sOffering" % String(entry.get("name", "Unknown"))
	slot.custom_minimum_size = OFFERING_SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _make_offering_slot_style())
	slot.gui_input.connect(_on_offering_slot_gui_input.bind(entry, slot))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(stack)

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(OFFERING_SLOT_SIZE.x, OFFERING_ICON_SIZE.y)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)

	var icon := TextureRect.new()
	icon.texture = load(String(entry.get("texture", ""))) as Texture2D
	icon.custom_minimum_size = OFFERING_ICON_SIZE
	icon.size = OFFERING_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)

	var label := Label.new()
	label.text = "%s  +%d" % [String(entry.get("name", "贡品")), _get_offering_estimated_gain(entry)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.78, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	stack.add_child(label)
	_fit_font_to_text(label, label.text, 13, 9, 8)

	return slot


func _make_offering_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.028, 0.026, 0.62)
	style.border_color = Color(0.54, 0.66, 0.48, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _on_offering_slot_gui_input(event: InputEvent, entry: Dictionary, slot: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		offering_drop_requested.emit(entry.duplicate(true))
		_animate_control_press(slot)
		slot.accept_event()
		_offering_entries.clear()
		_refresh_cult_window(true)
		_refresh_altar_notice()
		_close_cult_window()


func _open_cult_window() -> void:
	if _cult_window == null:
		_create_cult_window()

	_place_cult_window()
	_refresh_cult_summary()
	_cult_window.visible = true
	_refresh_cult_window(true)


func _close_cult_window() -> void:
	if _cult_window != null:
		_cult_window.visible = false


func _place_cult_window() -> void:
	if _cult_window == null or _menu_window == null:
		return

	var screen_rect := _get_current_screen_rect()
	var x := _menu_window.position.x - CULT_WINDOW_SIZE.x - 12
	var max_x := screen_rect.position.x + screen_rect.size.x - CULT_WINDOW_SIZE.x
	if x < screen_rect.position.x:
		x = _menu_window.position.x + 4
	x = maxi(screen_rect.position.x, mini(x, max_x))

	var y := _menu_window.position.y - CULT_WINDOW_SIZE.y - 8
	if y < screen_rect.position.y:
		y = screen_rect.position.y + 20

	_cult_window.position = Vector2i(x, y)


func _refresh_cult_window(force := false) -> void:
	if _cult_window == null or _offering_grid == null:
		return
	if not force and not _cult_window.visible:
		return

	if force or _offering_grid.get_child_count() == 0:
		_refresh_offering_grid()

	_refresh_cult_summary()


func _refresh_cult_summary() -> void:
	if _cult_faith_label != null:
		_cult_faith_label.text = "教众数量 %d" % _follower_count
		_fit_font_to_text(_cult_faith_label, _cult_faith_label.text, 16, 11, 12)

	if _cult_growth_label != null:
		_cult_growth_label.text = "教众增长 +%.2f / 秒" % _follower_growth_rate
		_fit_font_to_text(_cult_growth_label, _cult_growth_label.text, 16, 11, 12)


func _on_cult_name_changed(new_text: String) -> void:
	_cult_name = new_text
	if _cult_window_name_edit != null and _cult_window_name_edit.text != new_text:
		_cult_window_name_edit.text = new_text

	if _cult_window_name_edit != null:
		_fit_font_to_text(_cult_window_name_edit, _cult_window_name_edit.text, 16, 10, 16)


# Formatting and style helpers
func _fit_font_to_text(control: Control, text: String, max_size: int, min_size: int, comfortable_chars: int) -> void:
	if control == null:
		return

	var font_size := max_size
	var font := _get_ui_font()
	var available_width := control.size.x - 8.0
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
		for theme_type in ["Label", "LineEdit", "Button"]:
			_ui_theme.set_font("font", theme_type, font)
	return _ui_theme


func _get_ui_font() -> Font:
	if _ui_font != null:
		return _ui_font

	_ui_font = load(UI_FONT) as Font
	return _ui_font


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


func _make_upgrade_detail_name_style(focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.034, 0.038, 0.032, 0.78)
	style.border_color = Color(0.72, 0.7, 0.46, 0.92) if focused else Color(0.42, 0.46, 0.32, 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _make_cult_window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.034, 0.035, 0.94)
	style.border_color = Color(0.46, 0.62, 0.52, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12
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


func _make_bookmark_button(label_text: String, callback: Callable) -> TextureButton:
	var button := TextureButton.new()
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

	return button


func _configure_upgrade_row_button(button: TextureButton, _tooltip_text: String, shrink_center: bool) -> void:
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


# Upgrade hover detail
func _on_upgrade_row_hovered(pet_id: String, button: Control, hovered: bool) -> void:
	_upgrade_bonus_hovered[pet_id] = hovered
	_refresh_upgrade_bonus_label(pet_id)
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
	if _upgrade_detail_panel != null and _upgrade_detail_panel.visible:
		var still_near_detail := _upgrade_detail_panel_hovered or _is_mouse_in_upgrade_detail_safe_zone()
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
	if _upgrade_detail_panel != null and _upgrade_detail_panel.visible and _upgrade_detail_pet_id == _hovered_upgrade_pet_id:
		return

	_upgrade_detail_hover_time += delta
	if _upgrade_detail_hover_time >= UPGRADE_DETAIL_HOVER_DELAY:
		_show_upgrade_detail_panel(_hovered_upgrade_pet_id, _hovered_upgrade_button)


func _on_upgrade_detail_panel_hovered(hovered: bool) -> void:
	_upgrade_detail_panel_hovered = hovered
	if hovered:
		_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE


func _on_upgrade_detail_name_changed(new_text: String) -> void:
	if _updating_upgrade_detail_name or _upgrade_detail_pet_id.is_empty():
		return
	pet_rename_requested.emit(_upgrade_detail_pet_id, new_text.strip_edges())


func _is_mouse_in_upgrade_detail_safe_zone() -> bool:
	if _upgrade_detail_panel == null or not _upgrade_detail_panel.visible:
		return false

	var mouse_position := _upgrade_detail_panel.get_global_mouse_position()
	var detail_rect := _upgrade_detail_panel.get_global_rect().grow(18.0)
	if detail_rect.has_point(mouse_position):
		return true

	return false


func _refresh_upgrade_bonus_label(pet_id: String) -> void:
	var label := _upgrade_bonus_labels.get(pet_id) as Label
	if label == null:
		return

	var total_bonus := float(_upgrade_total_growth_bonuses.get(pet_id, 0.0))
	label.text = "+%.2f/s" % total_bonus
	_fit_font_to_text(label, label.text, 20, 12, 7)


func _get_pet_display_name(pet_id: String, pet_data: Dictionary) -> String:
	for entry_value in _upgrade_entries:
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == pet_id:
			return String(entry.get("name", pet_data.get("name", pet_id)))
	return String(pet_data.get("name", pet_id))


func _show_upgrade_detail_panel(pet_id: String, button: Control) -> void:
	if _upgrade_detail_panel == null:
		return

	var pet_data := PetCatalog.get_definition(pet_id)
	var entry: Dictionary = {}
	for entry_value in _upgrade_entries:
		var entry_candidate: Dictionary = entry_value
		if String(entry_candidate.get("id", "")) == pet_id:
			entry = entry_candidate
			break

	var display_name := String(entry.get("name", _get_pet_display_name(pet_id, pet_data)))
	var count := 1
	if not entry.is_empty():
		count = int(entry.get("count", 1))

	var next_bonus := float(_upgrade_next_growth_bonuses.get(pet_id, 0.0))
	var cost := float(entry.get("cost", 0.0))
	var favor := int(entry.get("favor", 0))
	var discount := float(entry.get("upgrade_discount", 0.0))
	var affordable: bool = _upgrade_affordables.get(pet_id, false) == true
	var leader_age := int(entry.get("leader_age", 24))

	if _upgrade_detail_name_edit != null:
		_updating_upgrade_detail_name = true
		_upgrade_detail_name_edit.text = display_name
		_updating_upgrade_detail_name = false
	if _upgrade_detail_level_label != null:
		_upgrade_detail_level_label.text = "种群数量 %d" % count
	_upgrade_detail_desc_label.text = String(entry.get("description", pet_data.get("description", "")))
	_upgrade_detail_stats_label.text = "领袖年龄 %d 岁\n好感度 %d [color=#c8d878]（升级减免 %.0f%%）[/color]\n本次升级增长 +%s / 秒\n消耗 %s\n%s" % [
		leader_age,
		favor,
		discount * 100.0,
		_format_number(next_bonus),
		_format_number(cost),
		"[color=#c7d86b]可升级[/color]" if affordable else "[color=#e88a66]信仰不足[/color]"
	]

	var y := button.global_position.y - _drawer_window.position.y - 16.0
	var max_y := maxf(24.0, float(_drawer_screen_size.y) - _upgrade_detail_panel.size.y - 24.0)
	_upgrade_detail_panel.position = Vector2(DRAWER_BOOKMARK_WIDTH + 24.0, clampf(y, 24.0, max_y))
	_upgrade_detail_panel.visible = true
	_upgrade_detail_pet_id = pet_id
	_upgrade_detail_source_button = button
	_upgrade_detail_hide_timer = UPGRADE_DETAIL_HIDE_GRACE


func _hide_upgrade_detail_panel(pet_id := "") -> void:
	if _upgrade_detail_panel == null:
		return
	if not pet_id.is_empty() and (_hovered_upgrade_pet_id == pet_id or _upgrade_detail_panel_hovered):
		return
	_upgrade_detail_panel.visible = false
	_upgrade_detail_pet_id = ""
	_upgrade_detail_source_button = null
	_hovered_upgrade_pet_id = ""
	_hovered_upgrade_button = null
	_upgrade_detail_hover_time = 0.0
	_upgrade_detail_panel_hovered = false
	_updating_upgrade_detail_name = false
	_upgrade_detail_hide_timer = 0.0


func _get_upgrade_row_texture() -> Texture2D:
	if _upgrade_row_texture != null:
		return _upgrade_row_texture

	_upgrade_row_texture = load(UPGRADE_TEXTURE) as Texture2D
	return _upgrade_row_texture


func _make_texture_button(button_name: String, texture_path: String, callback: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.name = button_name
	button.texture_normal = load(texture_path) as Texture2D
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(86, 26)
	button.pressed.connect(callback)
	return button


func _make_text_button(button_text: String, callback: Callable) -> Button:
	var button := Button.new()
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


# Cursor, effects, and hit masks
func _on_interactive_control_hovered(control: Control, hovered: bool) -> void:
	_animate_control_hover(control, hovered)
	if hovered:
		_push_interaction_cursor()
	else:
		_pop_interaction_cursor()


func _push_interaction_cursor() -> void:
	_interaction_cursor_depth += 1
	var cursor_texture := _get_interaction_cursor_texture()
	if cursor_texture != null:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, INTERACTION_CURSOR_HOTSPOT)


func _pop_interaction_cursor() -> void:
	_interaction_cursor_depth = maxi(0, _interaction_cursor_depth - 1)
	if _interaction_cursor_depth == 0:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


func _refresh_interaction_cursor() -> void:
	if _interaction_cursor_depth <= 0:
		return

	var cursor_texture := _get_interaction_cursor_texture()
	if cursor_texture != null:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, INTERACTION_CURSOR_HOTSPOT)


func _get_interaction_cursor_texture() -> Texture2D:
	if _interaction_cursor_texture != null:
		return _interaction_cursor_texture

	var texture := load(INTERACTION_CURSOR_TEXTURE) as Texture2D
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		_interaction_cursor_texture = texture
		return _interaction_cursor_texture

	image.convert(Image.FORMAT_RGBA8)
	var used_rect := image.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		image = image.get_region(used_rect)
	image.resize(INTERACTION_CURSOR_SIZE.x, INTERACTION_CURSOR_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_interaction_cursor_texture = ImageTexture.create_from_image(image)
	return _interaction_cursor_texture


func _pulse_count_label(label: Label) -> void:
	if label == null:
		return

	label.scale = Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE * 1.22, 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14)


func _play_adder_symbol_effect(button: Control) -> void:
	if button == null:
		return

	var parent := button.get_parent() as Control
	if parent == null:
		return

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
	var texture := load(String(SYMBOL_EFFECT_TEXTURES[_rng.randi_range(0, SYMBOL_EFFECT_TEXTURES.size() - 1)])) as Texture2D
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


func _update_menu_window_mouse_passthrough() -> void:
	if _menu_window == null:
		return

	var mouse_position := _get_window_mouse_position(_menu_window)
	var hit_rect := _get_menu_button_hit_rect(mouse_position)
	if hit_rect.size == Vector2.ZERO:
		_set_menu_window_mouse_passthrough(true)
		return

	_set_menu_window_mouse_passthrough(false)


func _get_menu_button_hit_rect(mouse_position: Vector2) -> Rect2:
	for button in [_altar_button, _menu_button]:
		if button == null or not button.visible:
			continue

		var rect := Rect2(button.position, button.size)
		if not rect.has_point(mouse_position):
			continue

		if _is_texture_button_opaque_at(button, mouse_position - rect.position):
			return rect

	return Rect2()


func _is_texture_button_opaque_at(button: TextureButton, button_position: Vector2) -> bool:
	var image := _get_button_hit_image(button)
	if image == null or image.is_empty() or button.size.x <= 0.0 or button.size.y <= 0.0:
		return false

	var pixel_x := int(clampf(button_position.x / button.size.x, 0.0, 0.9999) * float(image.get_width()))
	var pixel_y := int(clampf(button_position.y / button.size.y, 0.0, 0.9999) * float(image.get_height()))
	return image.get_pixel(pixel_x, pixel_y).a > 0.08


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


func _set_menu_window_mouse_passthrough(enabled: bool, force := false) -> void:
	if _menu_window == null or (not force and _menu_window_mouse_passthrough == enabled):
		return

	_menu_window_mouse_passthrough = enabled
	if _menu_clickthrough_controller != null and _menu_clickthrough_controller.call("set_clickthrough", enabled, force):
		return

	var window_id := _menu_window.get_window_id()
	if window_id <= 0:
		return

	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,
		enabled,
		window_id
	)


# Window placement and drawer motion
func _exit_tree() -> void:
	if _menu_clickthrough_controller != null:
		_menu_clickthrough_controller.call("shutdown")


func _get_window_mouse_position(window: Window) -> Vector2:
	var global_mouse := DisplayServer.mouse_get_position()
	var window_position := window.position
	return Vector2(global_mouse.x - window_position.x, global_mouse.y - window_position.y)


func _place_menu_window() -> void:
	if _menu_window == null:
		return

	var usable_rect := _get_current_screen_usable_rect()
	var screen_rect := _get_current_screen_rect()
	_menu_window.size = MENU_WINDOW_SIZE
	_menu_window.position = Vector2i(
		_get_menu_handle_x(screen_rect),
		usable_rect.position.y + usable_rect.size.y - MENU_WINDOW_SIZE.y
	)
	_set_menu_window_mouse_passthrough(_menu_window_mouse_passthrough, true)
	if not _menu_window.visible:
		_menu_window.visible = true


func _refresh_drawer_geometry(keep_current_slide := true) -> void:
	if _drawer_window == null:
		return

	var screen_rect := _get_current_screen_rect()
	var screen_right := screen_rect.position.x + screen_rect.size.x
	var open_x := screen_right - DRAWER_WIDTH
	open_x = maxi(screen_rect.position.x, open_x)
	var drawer_width := screen_right - open_x
	drawer_width = maxi(1, drawer_width)

	_drawer_screen_position = Vector2i(open_x, screen_rect.position.y)
	_drawer_closed_x = screen_right
	_drawer_screen_size = Vector2i(drawer_width, screen_rect.size.y)
	_drawer_window.size = _drawer_screen_size
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
	if _cult_window != null and _cult_window.visible:
		_place_cult_window()

	_drawer_target_x = _drawer_screen_position.x if _drawer_open else _drawer_closed_x
	if keep_current_slide:
		return

	var x := _drawer_screen_position.x if _drawer_open else _drawer_closed_x
	_drawer_window.position = Vector2i(x, _drawer_screen_position.y)


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

	if is_equal_approx(next_x, target) and not _drawer_open:
		_drawer_window.visible = false


func _toggle_drawer() -> void:
	var opening := not _drawer_open
	_refresh_drawer_geometry()
	_drawer_open = opening
	_drawer_target_x = _drawer_screen_position.x if _drawer_open else _drawer_closed_x

	if _drawer_open:
		if not _drawer_window.visible or _drawer_window.position.x < _drawer_screen_position.x or _drawer_window.position.x >= _drawer_closed_x:
			_drawer_window.position = Vector2i(_drawer_closed_x, _drawer_screen_position.y)
		_drawer_window.visible = true


func _get_menu_handle_x(screen_rect: Rect2i) -> int:
	var drawer_open_x := maxi(screen_rect.position.x, screen_rect.position.x + screen_rect.size.x - DRAWER_WIDTH)
	var target_x := drawer_open_x - MENU_TO_DRAWER_GAP - MENU_WINDOW_SIZE.x
	return maxi(screen_rect.position.x, target_x)


func _get_current_screen_usable_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_get_current_screen())


func _get_current_screen_rect() -> Rect2i:
	var screen := _get_current_screen()
	return Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))


func _get_current_screen() -> int:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	return screen


func _on_menu_button_hovered(hovered: bool) -> void:
	if _menu_button == null:
		return
	_animate_control_hover(_menu_button, hovered)
	if _menu_hint != null:
		_menu_hint.visible = hovered


func _on_altar_hovered(hovered: bool) -> void:
	if _altar_button == null:
		return
	_animate_control_hover(_altar_button, hovered)
	if _altar_hint != null:
		_altar_hint.visible = hovered


func _on_altar_pressed() -> void:
	if _altar_button != null:
		_animate_control_press(_altar_button)

	if _cult_window != null and _cult_window.visible:
		_close_cult_window()
		return

	_open_cult_window()


# Button signal handlers
func _on_pet_upgrade_pressed(pet_id: String, button: Control) -> void:
	var affordable: bool = _upgrade_affordables.get(pet_id, false) == true
	pet_count_upgrade_requested.emit(pet_id)
	if button != null:
		_animate_control_press(button)
		if affordable:
			_play_upgrade_effect(button)


func _on_inventory_bookmark_pressed() -> void:
	inventory_requested.emit()


func _on_shop_bookmark_pressed() -> void:
	shop_requested.emit()


func _on_drawer_close_bookmark_pressed() -> void:
	if _drawer_open:
		_toggle_drawer()


func _on_drawer_button_pressed() -> void:
	_toggle_drawer()


func _on_quit_pressed() -> void:
	quit_requested.emit()
