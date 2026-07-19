extends "res://scripts/runtime/main_context.gd"

func _refresh_era_display(force := false) -> void:
	if _side_drawer == null or not _side_drawer.has_method("refresh_era"):
		return
	var display_text = EraProgression.get_display_text(_total_runtime_seconds, _language)
	if force or display_text != _last_era_display:
		var calendar_changed = display_text != _last_era_display
		_last_era_display = display_text
		_side_drawer.call("refresh_era", display_text)
		if calendar_changed:
			_pet_upgrade_stats_dirty = true
			_refresh_pet_stats(true)
			if _inventory_window != null and _inventory_window.visible:
				_sync_inventory_window()


func _create_news_broadcast() -> void:
	var layer = CanvasLayer.new()
	layer.name = "NewsBroadcastLayer"
	layer.layer = 400
	add_child(layer)

	var top_center = CenterContainer.new()
	top_center.name = "NewsBroadcastAnchor"
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 12.0
	top_center.offset_bottom = 92.0
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top_center)

	_news_broadcast_panel = PanelContainer.new()
	_news_broadcast_panel.name = "NewsBroadcastPanel"
	_news_broadcast_panel.custom_minimum_size = NEWS_BROADCAST_SIZE
	_news_broadcast_panel.pivot_offset = NEWS_BROADCAST_SIZE * 0.5
	_news_broadcast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_news_broadcast_panel.visible = false
	_news_broadcast_panel.add_theme_stylebox_override("panel", _make_news_broadcast_style())
	top_center.add_child(_news_broadcast_panel)

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	_news_broadcast_panel.add_child(margin)

	_news_broadcast_label = Label.new()
	_news_broadcast_label.name = "NewsBroadcastText"
	_news_broadcast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_news_broadcast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_news_broadcast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_broadcast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_news_broadcast_label.add_theme_font_size_override("font_size", NEWS_BROADCAST_FONT_SIZE)
	_news_broadcast_label.add_theme_color_override("font_color", Color(0.94, 0.98, 0.88, 1.0))
	_news_broadcast_label.add_theme_color_override("font_outline_color", Color(0.005, 0.018, 0.014, 0.96))
	_news_broadcast_label.add_theme_constant_override("outline_size", 2)
	var font = LanguageSettings.get_ui_font(_language)
	_news_broadcast_label.add_theme_font_override("font", font)
	margin.add_child(_news_broadcast_label)

func _make_news_broadcast_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.043, 0.034, 0.36)
	style.border_color = Color(0.46, 0.70, 0.42, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	return style

func _create_pilgrimage_broadcast() -> void:
	var layer = CanvasLayer.new()
	layer.name = "PilgrimageBroadcastLayer"
	layer.layer = 450
	add_child(layer)

	var top_center = CenterContainer.new()
	top_center.name = "PilgrimageBroadcastAnchor"
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 42.0
	top_center.offset_bottom = 190.0
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top_center)

	_pilgrimage_broadcast_panel = PanelContainer.new()
	_pilgrimage_broadcast_panel.name = "PilgrimageBroadcastPanel"
	_pilgrimage_broadcast_panel.custom_minimum_size = PILGRIMAGE_BROADCAST_SIZE
	_pilgrimage_broadcast_panel.pivot_offset = PILGRIMAGE_BROADCAST_SIZE * 0.5
	_pilgrimage_broadcast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilgrimage_broadcast_panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.035, 0.028, 0.94)
	style.border_color = Color(0.76, 0.84, 0.38, 0.94)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 12
	_pilgrimage_broadcast_panel.add_theme_stylebox_override("panel", style)
	top_center.add_child(_pilgrimage_broadcast_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilgrimage_broadcast_panel.add_child(margin)

	var text_stack = VBoxContainer.new()
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 2)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(text_stack)

	var font = LanguageSettings.get_ui_font(_language)

	var status_anchor = CenterContainer.new()
	status_anchor.name = "PilgrimageStatusAnchor"
	status_anchor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_anchor.offset_top = 8.0
	status_anchor.offset_bottom = 42.0
	status_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status_anchor)
	_pilgrimage_status_label = Label.new()
	_pilgrimage_status_label.name = "PilgrimageStatus"
	_pilgrimage_status_label.custom_minimum_size = Vector2(480.0, 32.0)
	_pilgrimage_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pilgrimage_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pilgrimage_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilgrimage_status_label.visible = false
	_pilgrimage_status_label.add_theme_font_override("font", font)
	_pilgrimage_status_label.add_theme_font_size_override("font_size", 19)
	_pilgrimage_status_label.add_theme_color_override("font_color", Color(0.98, 0.91, 0.46, 1.0))
	_pilgrimage_status_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.015, 1.0))
	_pilgrimage_status_label.add_theme_constant_override("outline_size", 5)
	status_anchor.add_child(_pilgrimage_status_label)

	_pilgrimage_broadcast_title = Label.new()
	_pilgrimage_broadcast_title.name = "PilgrimageBroadcastTitle"
	_pilgrimage_broadcast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pilgrimage_broadcast_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilgrimage_broadcast_title.add_theme_font_override("font", font)
	_pilgrimage_broadcast_title.add_theme_font_size_override("font_size", PILGRIMAGE_BROADCAST_FONT_SIZE)
	_pilgrimage_broadcast_title.add_theme_color_override("font_color", Color(0.98, 0.91, 0.46, 1.0))
	_pilgrimage_broadcast_title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.015, 1.0))
	_pilgrimage_broadcast_title.add_theme_constant_override("outline_size", 4)
	text_stack.add_child(_pilgrimage_broadcast_title)

	_pilgrimage_broadcast_subtitle = Label.new()
	_pilgrimage_broadcast_subtitle.name = "PilgrimageBroadcastSubtitle"
	_pilgrimage_broadcast_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pilgrimage_broadcast_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilgrimage_broadcast_subtitle.add_theme_font_override("font", font)
	_pilgrimage_broadcast_subtitle.add_theme_font_size_override("font_size", 20)
	_pilgrimage_broadcast_subtitle.add_theme_color_override("font_color", Color(0.88, 0.95, 0.81, 1.0))
	text_stack.add_child(_pilgrimage_broadcast_subtitle)

func _show_pilgrimage_broadcast(
	title_text: String,
	subtitle_text: String,
	localized_copy: Dictionary = {}
) -> void:
	if (
		_pilgrimage_broadcast_panel == null
		or _pilgrimage_broadcast_title == null
		or _pilgrimage_broadcast_subtitle == null
	):
		return
	if _pilgrimage_broadcast_tween != null and is_instance_valid(_pilgrimage_broadcast_tween):
		_pilgrimage_broadcast_tween.kill()
	_pilgrimage_broadcast_title.text = title_text
	_pilgrimage_broadcast_subtitle.text = subtitle_text
	if localized_copy.is_empty():
		_pilgrimage_broadcast_panel.remove_meta("localized_copy")
	else:
		_pilgrimage_broadcast_panel.set_meta("localized_copy", localized_copy.duplicate(true))
		_refresh_pilgrimage_broadcast_language()
	_pilgrimage_broadcast_panel.visible = true
	_pilgrimage_broadcast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_pilgrimage_broadcast_panel.scale = Vector2(0.82, 0.82)
	_pilgrimage_broadcast_tween = create_tween()
	_pilgrimage_broadcast_tween.set_trans(Tween.TRANS_BACK)
	_pilgrimage_broadcast_tween.set_ease(Tween.EASE_OUT)
	_pilgrimage_broadcast_tween.tween_property(_pilgrimage_broadcast_panel, "modulate", Color.WHITE, 0.24)
	_pilgrimage_broadcast_tween.parallel().tween_property(_pilgrimage_broadcast_panel, "scale", Vector2.ONE, 0.30)
	_pilgrimage_broadcast_tween.tween_interval(4.4)
	_pilgrimage_broadcast_tween.set_trans(Tween.TRANS_SINE)
	_pilgrimage_broadcast_tween.tween_property(
		_pilgrimage_broadcast_panel,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		0.48
	)
	_pilgrimage_broadcast_tween.tween_callback(_hide_pilgrimage_broadcast)


func _refresh_pilgrimage_broadcast_language() -> void:
	if (
		_pilgrimage_broadcast_panel == null
		or _pilgrimage_broadcast_title == null
		or _pilgrimage_broadcast_subtitle == null
		or not _pilgrimage_broadcast_panel.has_meta("localized_copy")
	):
		return
	var localized_copy: Dictionary = _pilgrimage_broadcast_panel.get_meta("localized_copy", {})
	var suffix := "en" if _language == "en" else "zh"
	var title_copy := String(localized_copy.get("title_%s" % suffix, ""))
	var subtitle_copy := String(localized_copy.get("subtitle_%s" % suffix, ""))
	if not title_copy.is_empty():
		_pilgrimage_broadcast_title.text = title_copy
	if not subtitle_copy.is_empty():
		_pilgrimage_broadcast_subtitle.text = subtitle_copy

func _hide_pilgrimage_broadcast() -> void:
	if _pilgrimage_broadcast_panel != null:
		_pilgrimage_broadcast_panel.visible = false
	_pilgrimage_broadcast_tween = null

func _create_side_drawer() -> void:
	_side_drawer = SideDrawerController.new()
	add_child(_side_drawer)
	_side_drawer.inventory_requested.connect(_on_inventory_requested)
	_side_drawer.shop_requested.connect(_on_shop_requested)
	_side_drawer.gacha_requested.connect(_on_gacha_requested)
	_side_drawer.news_requested.connect(_on_news_requested)
	_side_drawer.settings_requested.connect(_on_settings_requested)
	_side_drawer.quit_requested.connect(_host._on_quit_requested)
	_side_drawer.pet_upgrade_requested.connect(_host._on_pet_upgrade_requested)
	_side_drawer.pet_rename_requested.connect(_host._on_pet_detail_rename_requested)
	_side_drawer.faith_add_requested.connect(_host._on_faith_add_requested)
	_side_drawer.menu_handle_moved.connect(_host._on_menu_handle_moved)
	_side_drawer.drawer_opened.connect(_on_drawer_opened)
	if _loaded_menu_handle_anchor >= 0.0:
		_side_drawer.set_menu_handle_anchor(_loaded_menu_handle_anchor)
	_side_drawer.setup()
	if not _carried_offering.is_empty():
		_host._set_offering_cursor(String(_carried_offering.get("texture", "")))
		_host._update_offering_input_window()

func _create_inventory_window() -> void:
	_inventory_window = InventoryWindowScript.new()
	_inventory_window.visible = false
	add_child(_inventory_window)
	_inventory_window.connect("pet_deploy_requested", Callable(_host, "_on_inventory_pet_deploy_requested"))
	_inventory_window.connect("pet_rename_requested", Callable(_host, "_on_inventory_pet_rename_requested"))
	_inventory_window.connect("pet_evolution_requested", Callable(_host, "_on_inventory_pet_evolution_requested"))
	_inventory_window.setup(_host._get_inventory_pet_entries())

func _create_evolution_window() -> void:
	_evolution_window = EvolutionWindowScript.new()
	_evolution_window.visible = false
	add_child(_evolution_window)
	_evolution_window.dismissed.connect(_host._on_evolution_notification_dismissed)
	_evolution_window.setup(_language)
	_host._show_next_evolution_notification()

func _sync_inventory_window() -> void:
	if _inventory_window != null and _inventory_window.has_method("set_pets"):
		_inventory_window.call(
			"set_pets",
			_host._get_inventory_pet_entries(),
			_inventory_window.visible
		)

func _create_shop_window() -> void:
	_shop_window = ShopWindowScript.new()
	_shop_window.visible = false
	add_child(_shop_window)
	_shop_window.connect("purchase_requested", Callable(_host, "_on_shop_purchase_requested"))
	_shop_window.call("setup")
	_sync_shop_state()

func _create_gacha_window() -> void:
	_gacha_window = GachaWindowScript.new()
	_gacha_window.visible = false
	add_child(_gacha_window)
	_gacha_window.draw_requested.connect(_host._on_gacha_draw_requested)
	_gacha_window.setup()
	_sync_gacha_state()

func _create_news_window() -> void:
	_news_window = NewsWindowScript.new()
	_news_window.visible = false
	add_child(_news_window)
	_news_window.setup(_news_feed.get_history())

func _create_settings_window() -> void:
	_settings_window = SettingsWindowScript.new()
	_settings_window.visible = false
	add_child(_settings_window)
	_settings_window.activity_range_changed.connect(_host._on_activity_range_changed)
	_settings_window.language_changed.connect(_host._on_language_changed)
	_settings_window.debug_economy_requested.connect(_host._on_debug_economy_requested)
	_settings_window.debug_simulation_requested.connect(_host._on_debug_simulation_requested)
	_settings_window.debug_event_requested.connect(_host._on_debug_event_requested)
	_settings_window.debug_pet_levels_requested.connect(_host._on_debug_pet_levels_requested)
	_settings_window.reset_game_requested.connect(_host._reset_game_progress)
	_settings_window.quit_requested.connect(_host._on_quit_requested)
	_settings_window.setup(_pet_activity_range, _language)
	_settings_window.refresh_runtime(_session_runtime_seconds, _total_runtime_seconds)
	_settings_window.refresh_debug_values(_faith_points, _gold_coins, _debug_enemy_power_scale, _debug_game_speed, _host._get_debug_pet_levels())


func _create_completion_window() -> void:
	_completion_window = CompletionWindowScript.new()
	_completion_window.visible = false
	add_child(_completion_window)
	_completion_window.connect(
		"continue_requested",
		Callable(_host, "_on_completion_continue_requested")
	)
	_completion_window.connect(
		"endless_requested",
		Callable(_host, "_on_endless_mode_requested")
	)
	_completion_window.call("setup", _language)


func _refresh_pet_stats(force := false) -> void:
	if _side_drawer == null:
		return

	var faith_count = int(floor(_faith_points))
	var growth_rate = _host._get_faith_growth_rate()
	var faith_changed = faith_count != _last_reported_faith_count
	var growth_changed = not is_equal_approx(growth_rate, _last_reported_growth_rate)

	if force:
		_refresh_faith_display()
		_refresh_follower_display()
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate

	var upgrades_need_refresh = force or faith_changed or growth_changed or _pet_upgrade_stats_dirty
	if not upgrades_need_refresh or not _side_drawer.has_method("refresh_pet_upgrades"):
		return
	var upgrade_ui_visible = (
		not _side_drawer.has_method("is_upgrade_ui_visible")
		or bool(_side_drawer.call("is_upgrade_ui_visible"))
	)
	if not upgrade_ui_visible:
		_pet_upgrade_stats_dirty = true
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate
		return
	if upgrade_ui_visible:
		_side_drawer.call("refresh_pet_upgrades", _host._get_pet_upgrade_entries())
		_pet_upgrade_stats_dirty = false
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate
		if growth_changed:
			_refresh_follower_display()

func _on_drawer_opened() -> void:
	_refresh_pet_stats(true)

func _refresh_faith_display() -> void:
	if _side_drawer != null and _side_drawer.has_method("refresh_faith"):
		_side_drawer.refresh_faith(_faith_points, _host._get_faith_growth_rate())
	if _gacha_window != null and _gacha_window.visible:
		_sync_gacha_state()

func _refresh_coin_display() -> void:
	if _side_drawer != null and _side_drawer.has_method("refresh_coins"):
		_side_drawer.call("refresh_coins", _gold_coins)
	if _shop_window != null and _shop_window.has_method("set_coin_balance"):
		_shop_window.call("set_coin_balance", _gold_coins)
	if _gacha_window != null and _gacha_window.visible:
		_sync_gacha_state()

func _refresh_follower_display() -> void:
	if _side_drawer != null and _side_drawer.has_method("refresh_followers"):
		_side_drawer.call(
			"refresh_followers",
			int(floor(_follower_count)),
			_host._get_follower_growth_rate()
		)

func _sync_shop_state() -> void:
	if _shop_window == null:
		return
	if _shop_window.has_method("set_goods"):
		_shop_window.call("set_goods", _host._get_dynamic_shop_goods())
	if _shop_window.has_method("set_coin_balance"):
		_shop_window.call("set_coin_balance", _gold_coins)
	if _shop_window.has_method("set_owned_counts"):
		_shop_window.call("set_owned_counts", _shop_owned_counts)

func _sync_gacha_state() -> void:
	if _gacha_window == null:
		return
	var next_cost = GachaProgression.draw_cost(_gacha_draw_count)
	_gacha_window.refresh_state(
		float(_gold_coins),
		_gacha_draw_count,
		next_cost,
		_unlocked_pet_ids.duplicate(),
		_gacha_pity_count,
		_gacha_history
	)

func _update_settings_runtime(delta: float) -> void:
	if _settings_window == null:
		return
	_settings_refresh_timer += maxf(0.0, delta)
	if _settings_refresh_timer < 0.5:
		return
	_settings_refresh_timer = 0.0
	_settings_window.refresh_runtime(_session_runtime_seconds, _total_runtime_seconds)

func _initialize_news_feed() -> void:
	_news_feed.restore(_loaded_news_state, _host._get_faith_growth_rate(), _follower_count)
	_loaded_news_state.clear()

func _update_news(delta: float) -> void:
	var now = _host._get_news_runtime_seconds()
	_news_milestone_check_timer += maxf(0.0, delta)
	if _news_milestone_check_timer >= NEWS_MILESTONE_CHECK_INTERVAL:
		_news_milestone_check_timer = 0.0
		var milestones = _news_feed.collect_milestones(
			_host._get_faith_growth_rate(),
			_follower_count,
			_rng.randf()
		)
		for article in milestones:
			if String(article.get("category", "")) == "信仰":
				_publish_news(article, true)
				_schedule_next_ambient_news(now)
			else:
				_queue_news_candidate(article)

	if _next_news_at <= 0.0 or now < _next_news_at:
		return
	var article: Dictionary
	if _news_story_backlog.is_empty():
		article = _news_feed.make_ambient(
			_make_news_context(),
			_rng.randf(),
			_rng.randf(),
			_rng.randf()
		)
	else:
		article = _news_story_backlog.pop_front()
	_publish_news(article)
	_schedule_next_ambient_news(now)

func _schedule_next_ambient_news(now: float) -> void:
	_next_news_at = maxf(0.0, now) + NewsFeed.get_ambient_interval(_rng.randf())

func _queue_news_candidate(article: Dictionary) -> void:
	if article.is_empty():
		return
	if _news_story_backlog.size() >= NEWS_STORY_BACKLOG_LIMIT:
		_news_story_backlog.pop_front()
	_news_story_backlog.append(article.duplicate(true))

func _make_news_context(extra := {}) -> Dictionary:
	var context = {
		"faith_rate": _host._get_faith_growth_rate(),
		"followers": _follower_count,
		"spread_tier": NewsFeed.get_follower_tier(_follower_count)
	}
	if extra is Dictionary:
		context.merge(extra, true)
	return context

func _try_queue_news_event(
	event_type: String,
	extra_context: Dictionary,
	event_key: String,
	cooldown_seconds: float,
	chance := 1.0
) -> void:
	if chance < 1.0 and _rng.randf() >= clampf(chance, 0.0, 1.0):
		return
	var now = _host._get_news_runtime_seconds()
	if not _news_feed.is_event_ready(event_key, now, cooldown_seconds):
		return
	if event_type != "gacha":
		if not _news_feed.is_event_ready("event:global", now, NEWS_EVENT_GLOBAL_COOLDOWN):
			return
		_news_feed.mark_event("event:global", now)
	_news_feed.mark_event(event_key, now)
	var article = _news_feed.make_event(event_type, _make_news_context(extra_context), _rng.randf())
	_queue_news_candidate(article)

func _publish_news(article: Dictionary, high_priority := false, broadcast := true) -> Dictionary:
	if article.is_empty():
		return {}
	var clock_text = "%s %s" % [
		Time.get_date_string_from_system(),
		Time.get_time_string_from_system().left(5)
	]
	var entry = _news_feed.add_article(
		article,
		Time.get_unix_time_from_system(),
		clock_text
	)
	if entry.is_empty():
		return {}
	if _news_window != null and _news_window.has_method("add_entry"):
		_news_window.call("add_entry", entry)
	if broadcast:
		_enqueue_news_broadcast(entry, high_priority)
	return entry

func _enqueue_news_broadcast(entry: Dictionary, high_priority := false) -> void:
	if entry.is_empty() or _news_broadcast_panel == null:
		return
	if _news_broadcast_queue.size() >= NEWS_BROADCAST_QUEUE_LIMIT:
		_news_broadcast_queue.pop_back()
	if high_priority:
		_news_broadcast_queue.push_front(entry.duplicate(true))
	else:
		_news_broadcast_queue.append(entry.duplicate(true))
	_show_next_news_broadcast()

func _show_next_news_broadcast() -> void:
	if _news_broadcast_active or _news_broadcast_queue.is_empty():
		return
	if _news_broadcast_panel == null or _news_broadcast_label == null:
		return

	var entry: Dictionary = _news_broadcast_queue.pop_front()
	_news_broadcast_label.set_meta("news_entry", entry.duplicate(true))
	var headline = NewsFeed.get_localized_headline(entry, _language)
	_news_broadcast_label.text = "【%s】 %s" % [_get_localized_news_category(String(entry.get("category", "异闻"))), headline]
	_news_broadcast_panel.visible = true
	_news_broadcast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_news_broadcast_panel.scale = Vector2(0.96, 0.96)
	_news_broadcast_active = true
	if _news_broadcast_tween != null and is_instance_valid(_news_broadcast_tween):
		_news_broadcast_tween.kill()
	var hold_seconds = _get_news_broadcast_hold_seconds(headline)
	_news_broadcast_tween = create_tween()
	_news_broadcast_tween.set_trans(Tween.TRANS_SINE)
	_news_broadcast_tween.set_ease(Tween.EASE_OUT)
	_news_broadcast_tween.tween_property(_news_broadcast_panel, "modulate", Color.WHITE, 0.2)
	_news_broadcast_tween.parallel().tween_property(_news_broadcast_panel, "scale", Vector2.ONE, 0.2)
	_news_broadcast_tween.tween_interval(hold_seconds)
	_news_broadcast_tween.tween_property(_news_broadcast_panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.42)
	_news_broadcast_tween.tween_callback(_finish_news_broadcast)

func _get_localized_news_category(category: String) -> String:
	return NewsFeed.get_localized_category(category, _language)

func _finish_news_broadcast() -> void:
	if _news_broadcast_panel != null:
		_news_broadcast_panel.visible = false
	if _news_broadcast_label != null:
		_news_broadcast_label.remove_meta("news_entry")
	_news_broadcast_active = false
	_news_broadcast_tween = null
	call_deferred("_show_next_news_broadcast")

func _on_inventory_requested() -> void:
	if _inventory_window != null and _inventory_window.has_method("open_window"):
		_sync_inventory_window()
		_inventory_window.open_window()

func _on_shop_requested() -> void:
	if _shop_window == null:
		return

	_sync_shop_state()
	if _shop_window.has_method("open_window"):
		_shop_window.call("open_window")

func _on_gacha_requested() -> void:
	if _gacha_window == null:
		return
	_sync_gacha_state()
	_gacha_window.open_window()

func _on_news_requested() -> void:
	if _news_window == null:
		return
	if _news_window.has_method("set_entries"):
		_news_window.call("set_entries", _news_feed.get_history())
	if _news_window.has_method("open_window"):
		_news_window.call("open_window")

func _on_settings_requested() -> void:
	if _settings_window == null:
		return
	_settings_window.refresh_runtime(_session_runtime_seconds, _total_runtime_seconds)
	if _settings_window.has_method("refresh_debug_values"):
		_settings_window.call(
			"refresh_debug_values",
			_faith_points,
			_gold_coins,
			_debug_enemy_power_scale,
			_debug_game_speed,
			_host._get_debug_pet_levels()
		)
	_settings_window.open_window()
