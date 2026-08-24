extends "res://scripts/runtime/main_context.gd"

const DesktopController = preload("res://scripts/runtime/desktop_controller.gd")
const EventsController = preload("res://scripts/runtime/events_controller.gd")
const BattleController = preload("res://scripts/runtime/battle_controller.gd")
const CoinController = preload("res://scripts/runtime/coin_controller.gd")
const PresentationController = preload("res://scripts/runtime/presentation_controller.gd")
const PersistenceController = preload("res://scripts/runtime/persistence_controller.gd")
const ProgressionController = preload("res://scripts/runtime/progression_controller.gd")
const OfferingController = preload("res://scripts/runtime/offering_controller.gd")
const CampaignController = preload("res://scripts/runtime/campaign_controller.gd")
const SofaController = preload("res://scripts/runtime/sofa_controller.gd")
const DISPLAY_LAYOUT_POLL_SECONDS := 1.0

var _desktop_controller
var _events_controller
var _battle_controller
var _coin_controller
var _presentation_controller
var _persistence_controller
var _progression_controller
var _offering_controller
var _campaign_controller
var _sofa_controller
var _display_layout_poll_elapsed := 0.0

func _init() -> void:
	_host = self
	_desktop_controller = DesktopController.new()
	_desktop_controller.share_context(_state, self)
	add_child(_desktop_controller)
	_events_controller = EventsController.new()
	_events_controller.share_context(_state, self)
	add_child(_events_controller)
	_battle_controller = BattleController.new()
	_battle_controller.share_context(_state, self)
	add_child(_battle_controller)
	_coin_controller = CoinController.new()
	_coin_controller.share_context(_state, self)
	add_child(_coin_controller)
	_presentation_controller = PresentationController.new()
	_presentation_controller.share_context(_state, self)
	add_child(_presentation_controller)
	_persistence_controller = PersistenceController.new()
	_persistence_controller.share_context(_state, self)
	add_child(_persistence_controller)
	_progression_controller = ProgressionController.new()
	_progression_controller.share_context(_state, self)
	add_child(_progression_controller)
	_offering_controller = OfferingController.new()
	_offering_controller.share_context(_state, self)
	add_child(_offering_controller)
	_campaign_controller = CampaignController.new()
	_campaign_controller.share_context(_state, self)
	add_child(_campaign_controller)
	_sofa_controller = SofaController.new()
	_sofa_controller.share_context(_state, self)
	add_child(_sofa_controller)

func _ready() -> void:
	Input.use_accumulated_input = true
	_rng.randomize()
	_simulation_now_seconds = Time.get_unix_time_from_system()
	_persistence_enabled = (
		DisplayServer.get_name() != "headless"
		and not OS.get_cmdline_user_args().has(NO_SAVE_ARGUMENT)
	)
	_configure_pet_window()
	_place_pet_window()
	_load_game()
	_apply_automatic_evolution_thresholds()
	_apply_offline_progress()
	_initialize_news_feed()
	_create_desktop_pets()
	_create_desktop_items()
	_create_news_broadcast()
	_create_pilgrimage_broadcast()
	_create_offering_input_window()
	_create_side_drawer()
	_create_inventory_window()
	_create_evolution_window()
	_create_shop_window()
	_create_achievement_window()
	_create_news_window()
	_create_settings_window()
	_create_completion_window()
	if _news_feed.get_history().is_empty():
		_publish_news({
			"category": "公告",
			"headline": "《教团简报》开始播报：3名志愿者正在旧城区筹备首个聚会点，招募尚未形成规模。",
			"headline_en": "CULT BULLETIN: Three volunteers are preparing the first gathering place in the old district; recruitment remains limited."
		}, false, false)
	_next_news_at = _get_news_runtime_seconds() + NEWS_INITIAL_AMBIENT_DELAY
	_refresh_pet_stats(true)
	var now := _get_now_seconds()
	_spawn_believer(true)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)
	_schedule_next_pilgrimage(now, true)
	_schedule_next_battle(now, true)
	_schedule_next_ambient_coin_drop(now)
	_refresh_coin_display()
	_refresh_era_display(true)
	_apply_language()
	_check_campaign_completion()

	_position_retry_frames = POSITION_RETRY_FRAMES
	_place_pet_window()
	call_deferred("_place_pet_window")
	call_deferred("_update_offering_input_window")

func _process(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	_simulation_now_seconds += safe_delta
	_session_runtime_seconds += safe_delta
	_total_runtime_seconds += safe_delta
	_display_layout_poll_elapsed += safe_delta
	_update_battle_pet_formation(safe_delta)
	if _position_retry_frames > 0:
		_position_retry_frames -= 1
		_place_pet_window()
	elif _display_layout_poll_elapsed >= DISPLAY_LAYOUT_POLL_SECONDS:
		_display_layout_poll_elapsed = 0.0
		# Windows can change the usable work area at runtime when DPI, display,
		# taskbar placement, or the active monitor changes.
		_place_pet_window()

	_pointer_hover_time += safe_delta
	if _has_captured_pet_pointer() or _pointer_hover_time >= POINTER_HOVER_INTERVAL:
		_pointer_hover_time = 0.0
		_update_pet_hover()
	if not _carried_offering.is_empty():
		if (
			_offering_input_window == null
			or not _offering_input_window.visible
			or _offering_input_window.position != get_window().position
		):
			_update_offering_input_window()
		if not _offering_cursor_active:
			_update_offering_cursor_state()

	_background_logic_time += safe_delta
	if _background_logic_time < BACKGROUND_LOGIC_INTERVAL:
		return
	var logic_delta := _background_logic_time
	_background_logic_time = 0.0
	_update_sofa_interaction(logic_delta)
	_update_pet_offering_buffs()
	_update_recovery_states(logic_delta)
	_background_faith_growth_cache = _calculate_faith_growth_rate()
	_background_faith_growth_cache_active = true
	_update_faith(logic_delta)
	_update_followers(logic_delta)
	_update_news(logic_delta)
	_background_faith_growth_cache_active = false
	_update_pet_emotions()
	_update_event_invitations()
	_update_pilgrimage()
	_update_battle(logic_delta)
	_update_believers()
	_update_pending_offerings()
	_update_coin_drops()
	_update_ambient_coin_drops()
	_update_playtime_display(logic_delta)
	_update_autosave(logic_delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_all_pet_pointer_captures()
		call_deferred("_restore_desktop_input")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Engine.time_scale = 1.0
		_save_game()
		get_tree().quit()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _save_dirty:
		_save_game()
	_clear_offering_cursor()



func _configure_pet_window() -> void:
	_desktop_controller._configure_pet_window()

func _create_desktop_pets() -> void:
	_desktop_controller._create_desktop_pets()

func _create_desktop_items() -> void:
	_desktop_controller._create_desktop_items()

func _spawn_desktop_pet(pet_id: String, start_x := -1.0) -> Node2D:
	return _desktop_controller._spawn_desktop_pet(pet_id, start_x)

func _spawn_desktop_item(item_id: String, start_x := -1.0) -> Node2D:
	return _desktop_controller._spawn_desktop_item(item_id, start_x)

func _deploy_item(item_id: String) -> bool:
	return _desktop_controller._deploy_item(item_id)

func _recall_item(item_id: String) -> bool:
	return _desktop_controller._recall_item(item_id)

func _get_desktop_item(item_id: String) -> Node2D:
	return _desktop_controller._get_desktop_item(item_id)

func _update_sofa_interaction(delta: float) -> void:
	_sofa_controller._update_sofa_interaction(delta)

func _on_sofa_deployed() -> void:
	_sofa_controller._on_sofa_deployed()

func _release_sofa_interaction(pet_id := "", animate := true) -> void:
	_sofa_controller._release_sofa_interaction(pet_id, animate)

func _try_begin_manual_sofa_visit(actor: Node2D) -> bool:
	return _sofa_controller._try_begin_manual_sofa_visit(actor)

func _on_pet_sofa_reached(actor: Node2D) -> void:
	_sofa_controller._on_pet_sofa_reached(actor)

func _on_pet_sofa_departed(actor: Node2D) -> void:
	_sofa_controller._on_pet_sofa_departed(actor)

func _get_pet_sofa_multiplier(pet_id: String, now := -1.0) -> float:
	return _sofa_controller._get_pet_sofa_multiplier(pet_id, now)

func _get_pet_sofa_seconds_remaining(pet_id: String, now := -1.0) -> float:
	return _sofa_controller._get_pet_sofa_seconds_remaining(pet_id, now)

func _get_next_pet_start_x() -> float:
	return _desktop_controller._get_next_pet_start_x()

func _get_pet_stage_min_x() -> float:
	return _desktop_controller._get_pet_stage_min_x()

func _get_pet_stage_max_x() -> float:
	return _desktop_controller._get_pet_stage_max_x()

func _get_effective_pet_activity_range() -> String:
	return _desktop_controller._get_effective_pet_activity_range()

func _update_believers() -> void:
	_events_controller._update_believers()

func _schedule_next_believer_spawn(now: float) -> void:
	_events_controller._schedule_next_believer_spawn(now)

func _spawn_believer(visible_on_spawn := false) -> void:
	_events_controller._spawn_believer(visible_on_spawn)

func _cleanup_believers() -> void:
	_events_controller._cleanup_believers()

func _get_believer_threat_positions() -> Array[Vector2]:
	return _events_controller._get_believer_threat_positions()

func _schedule_next_pilgrimage(now: float, initial := false) -> void:
	_events_controller._schedule_next_pilgrimage(now, initial)

func _update_pilgrimage() -> void:
	_events_controller._update_pilgrimage()

func _schedule_next_battle(now: float, initial := false) -> void:
	_events_controller._schedule_next_battle(now, initial)

func _update_event_invitations() -> void:
	_events_controller._update_event_invitations()

func _spawn_event_invitation(event_type: String) -> void:
	_events_controller._spawn_event_invitation(event_type)

func _queue_final_boss_invitation() -> void:
	_events_controller._queue_final_boss_invitation()

func _get_base_battle_difficulty_scale() -> float:
	return _battle_controller._get_base_battle_difficulty_scale()

func _get_pet_roster_combat_power() -> float:
	return _battle_controller._get_pet_roster_combat_power()

func _get_enemy_schedule_combat_power() -> float:
	return _battle_controller._get_enemy_schedule_combat_power()

func _roll_battle_difficulty_scale() -> float:
	return _battle_controller._roll_battle_difficulty_scale()

func _warm_battle_assets(schedule: Array) -> void:
	_battle_controller._warm_battle_assets(schedule)

func _get_battle_difficulty_scale() -> float:
	return _battle_controller._get_battle_difficulty_scale()

func _get_battle_difficulty_text(difficulty_override := -1.0, language_override := "") -> String:
	return _battle_controller._get_battle_difficulty_text(difficulty_override, language_override)

func _get_enemy_display_name(enemy_id: String, language_override := "") -> String:
	return _battle_controller._get_enemy_display_name(enemy_id, language_override)

func _get_battle_reward_budget(difficulty: float) -> Dictionary:
	return _battle_controller._get_battle_reward_budget(difficulty)

func _on_event_invitation_accepted(event_type: String) -> void:
	_events_controller._on_event_invitation_accepted(event_type)

func _on_event_invitation_discarded(event_type: String) -> void:
	_events_controller._on_event_invitation_discarded(event_type)

func _on_event_invitation_expired(event_type: String) -> void:
	_events_controller._on_event_invitation_expired(event_type)

func _reschedule_declined_event(event_type: String) -> void:
	_events_controller._reschedule_declined_event(event_type)

func _start_pilgrimage() -> void:
	_events_controller._start_pilgrimage()

func _finish_pilgrimage(resolved_early: bool) -> void:
	_events_controller._finish_pilgrimage(resolved_early)

func _spawn_pilgrimage_believer(
	spawn_x: float,
	spawn_from_left := true,
	entrance_delay := 0.0
) -> void:
	_events_controller._spawn_pilgrimage_believer(spawn_x, spawn_from_left, entrance_delay)

func _get_pilgrimage_group_centers(group_count: int) -> Array[float]:
	return _events_controller._get_pilgrimage_group_centers(group_count)

func _get_nearest_pet_x_distance(candidate_x: float) -> float:
	return _events_controller._get_nearest_pet_x_distance(candidate_x)

func _has_valid_desktop_pet() -> bool:
	return _events_controller._has_valid_desktop_pet()

func _has_pending_pilgrims() -> bool:
	return _events_controller._has_pending_pilgrims()

func _get_pending_pilgrim_count() -> int:
	return _events_controller._get_pending_pilgrim_count()

func _update_pilgrimage_status(now: float) -> void:
	_events_controller._update_pilgrimage_status(now)

func _set_pet_autonomy_paused(paused: bool) -> void:
	_events_controller._set_pet_autonomy_paused(paused)

func _start_battle() -> void:
	_battle_controller._start_battle()

func _update_battle(delta: float) -> void:
	_battle_controller._update_battle(delta)

func _update_battle_pet_formation(delta: float) -> void:
	_battle_controller._update_battle_pet_formation(delta)

func _spawn_battle_wave(wave: Dictionary, wave_index: int) -> void:
	_battle_controller._spawn_battle_wave(wave, wave_index)

func _on_enemy_projectile_requested(
	enemy: Node2D,
	target: Node2D,
	damage: float,
	projectile_kind: String,
	power_scale: float
) -> void:
	_battle_controller._on_enemy_projectile_requested(enemy, target, damage, projectile_kind, power_scale)

func _on_enemy_projectile_impacted(
	_projectile: Node2D,
	target: Node2D,
	damage: float,
	splash_radius: float,
	knockback: float
) -> void:
	_battle_controller._on_enemy_projectile_impacted(_projectile, target, damage, splash_radius, knockback)

func _get_battle_visual_power(rarity: int, level: int) -> float:
	return _battle_controller._get_battle_visual_power(rarity, level)

func _spawn_pet_projectile(
	pet: Node2D,
	pet_id: String,
	target: Node2D,
	direction: float,
	damage: float,
	knockback: float,
	visual_power: float
) -> void:
	_battle_controller._spawn_pet_projectile(pet, pet_id, target, direction, damage, knockback, visual_power)

func _on_pet_projectile_impacted(
	_effect: Node2D,
	target: Node2D,
	damage: float,
	knockback: float,
	visual_power: float
) -> void:
	_battle_controller._on_pet_projectile_impacted(_effect, target, damage, knockback, visual_power)

func _spawn_battle_explosion(world_position: Vector2, visual_power: float) -> void:
	_battle_controller._spawn_battle_explosion(world_position, visual_power)

func _on_battle_effect_tree_exited(effect: Node2D) -> void:
	_battle_controller._on_battle_effect_tree_exited(effect)

func _cleanup_battle_enemies() -> void:
	_battle_controller._cleanup_battle_enemies()

func _get_alive_battle_pets() -> Array[Node2D]:
	return _battle_controller._get_alive_battle_pets()

func _attach_battle_health_bar(actor: Node2D, current_health: float, maximum_health: float) -> Node2D:
	return _battle_controller._attach_battle_health_bar(actor, current_health, maximum_health)

func _get_nearest_battle_pet(enemy: Node2D, candidates: Array[Node2D]) -> Node2D:
	return _battle_controller._get_nearest_battle_pet(enemy, candidates)

func _get_battle_target_for_enemy(enemy: Node2D, candidates: Array[Node2D]) -> Node2D:
	return _battle_controller._get_battle_target_for_enemy(enemy, candidates)

func _get_nearest_battle_enemy(pet: Node2D) -> Node2D:
	return _battle_controller._get_nearest_battle_enemy(pet)

func _get_battle_target_for_pet(pet: Node2D) -> Node2D:
	return _battle_controller._get_battle_target_for_pet(pet)

func _on_pet5_battle_roll_swept(actor: Node2D, from_x: float, to_x: float) -> void:
	_battle_controller._on_pet5_battle_roll_swept(actor, from_x, to_x)

func _on_pet5_battle_roll_finished(actor: Node2D) -> void:
	_battle_controller._on_pet5_battle_roll_finished(actor)

func _on_enemy_attack_landed(_enemy: Node2D, target: Node2D, damage: float) -> void:
	_battle_controller._on_enemy_attack_landed(_enemy, target, damage)

func _damage_battle_pet(target: Node2D, damage: float, knockback: float) -> void:
	_battle_controller._damage_battle_pet(target, damage, knockback)

func _on_enemy_defeated(enemy: Node2D, reward_count: int) -> void:
	_battle_controller._on_enemy_defeated(enemy, reward_count)

func _on_enemy_swallowed(enemy: Node2D, reward_count: int) -> void:
	_battle_controller._on_enemy_swallowed(enemy, reward_count)

func _clear_battle_target_locks_for_enemy(enemy: Node2D) -> void:
	_battle_controller._clear_battle_target_locks_for_enemy(enemy)

func _spawn_battle_reward(drop_position: Vector2, reward_count: int) -> void:
	_battle_controller._spawn_battle_reward(drop_position, reward_count)

func _defeat_battle_pet(actor: Node2D) -> void:
	_battle_controller._defeat_battle_pet(actor)

func _set_pet_recovery(pet_id: String) -> void:
	_battle_controller._set_pet_recovery(pet_id)

func _schedule_battle_asset_warmup(schedule: Array) -> void:
	_battle_controller._schedule_battle_asset_warmup(schedule)

func _cancel_battle_asset_warmup() -> void:
	_battle_controller._cancel_battle_asset_warmup()

func _cancel_battle_for_debug() -> void:
	_battle_controller._cancel_battle_for_debug()

func _finish_battle(victory: bool) -> void:
	_battle_controller._finish_battle(victory)

func _clear_battle_runtime_nodes() -> void:
	_battle_controller._clear_battle_runtime_nodes()

func _update_battle_status(now: float) -> void:
	_battle_controller._update_battle_status(now)

func _spawn_smoke_effect(effect_position: Vector2) -> void:
	_battle_controller._spawn_smoke_effect(effect_position)

func _get_smoke_frames() -> SpriteFrames:
	return _battle_controller._get_smoke_frames()

func _refresh_era_display(force := false) -> void:
	_presentation_controller._refresh_era_display(force)

func _schedule_next_ambient_coin_drop(now: float) -> void:
	_coin_controller._schedule_next_ambient_coin_drop(now)

func _schedule_pet_coin_drop(actor: Node2D, now: float) -> void:
	_coin_controller._schedule_pet_coin_drop(actor, now)

func _update_ambient_coin_drops() -> void:
	_coin_controller._update_ambient_coin_drops()

func _spawn_pet_coin_pile(actor: Node2D, interval_seconds: float) -> void:
	_coin_controller._spawn_pet_coin_pile(actor, interval_seconds)

func _update_coin_drops() -> void:
	_coin_controller._update_coin_drops()

func _spawn_pet_coin(actor: Node2D) -> Node2D:
	return _coin_controller._spawn_pet_coin(actor)

func _spawn_coin(coin_type: String, spawn_position: Vector2) -> Node2D:
	return _coin_controller._spawn_coin(coin_type, spawn_position)

func _make_desktop_coin_capacity(incoming_count: int) -> void:
	_coin_controller._make_desktop_coin_capacity(incoming_count)

func _on_coin_collected(actor: Node2D, coin_type: String, value: int) -> void:
	_coin_controller._on_coin_collected(actor, coin_type, value)

func _on_believer_scared_away(actor: Node2D, drop_position: Vector2) -> void:
	var reward_value: int = int(_events_controller._resolve_pilgrimage_encounter(
		actor,
		drop_position,
		false,
		0
	))
	_coin_controller._on_believer_scared_away(actor, drop_position, reward_value)

func _on_believer_prayed(actor: Node2D, drop_position: Vector2, reward_value: int) -> void:
	var adjusted_reward: int = int(_events_controller._resolve_pilgrimage_encounter(
		actor,
		drop_position,
		true,
		reward_value
	))
	_coin_controller._on_believer_prayed(actor, drop_position, adjusted_reward)

func _get_active_pilgrimage_faith_multiplier() -> float:
	return _events_controller._get_active_pilgrimage_faith_multiplier()

func _create_news_broadcast() -> void:
	_presentation_controller._create_news_broadcast()

func _make_news_broadcast_style() -> StyleBoxFlat:
	return _presentation_controller._make_news_broadcast_style()

func _create_pilgrimage_broadcast() -> void:
	_presentation_controller._create_pilgrimage_broadcast()

func _show_pilgrimage_broadcast(
	title_text: String,
	subtitle_text: String,
	localized_copy: Dictionary = {},
	victory_loot_gold := 0
) -> void:
	_presentation_controller._show_pilgrimage_broadcast(
		title_text,
		subtitle_text,
		localized_copy,
		victory_loot_gold
	)

func _spawn_victory_loot_burst(gold_amount: int) -> void:
	_presentation_controller._spawn_victory_loot_burst(gold_amount)

func _refresh_pilgrimage_broadcast_language() -> void:
	_presentation_controller._refresh_pilgrimage_broadcast_language()

func _hide_pilgrimage_broadcast() -> void:
	_presentation_controller._hide_pilgrimage_broadcast()

func _create_side_drawer() -> void:
	_presentation_controller._create_side_drawer()

func _create_inventory_window() -> void:
	_presentation_controller._create_inventory_window()

func _create_evolution_window() -> void:
	_presentation_controller._create_evolution_window()

func _sync_inventory_window() -> void:
	_presentation_controller._sync_inventory_window()

func _create_shop_window() -> void:
	_presentation_controller._create_shop_window()

func _create_achievement_window() -> void:
	_presentation_controller._create_achievement_window()

func _create_news_window() -> void:
	_presentation_controller._create_news_window()

func _create_settings_window() -> void:
	_presentation_controller._create_settings_window()

func _create_completion_window() -> void:
	_presentation_controller._create_completion_window()

func _place_pet_window() -> void:
	_desktop_controller._place_pet_window()

func _get_target_pet_window_size(usable_rect: Rect2i) -> Vector2i:
	return _desktop_controller._get_target_pet_window_size(usable_rect)

func _update_actor_window_bounds() -> void:
	_desktop_controller._update_actor_window_bounds()

func _update_pet_hover() -> void:
	_desktop_controller._update_pet_hover()

func _set_hovered_pet(next_pet: Node2D) -> void:
	_desktop_controller._set_hovered_pet(next_pet)

func _cancel_all_pet_pointer_captures() -> void:
	_desktop_controller._cancel_all_pet_pointer_captures()

func _restore_desktop_input() -> void:
	_desktop_controller._restore_desktop_input()

func _is_offering_drop_zone(window_position: Vector2) -> bool:
	return _desktop_controller._is_offering_drop_zone(window_position)

func _has_captured_pet_pointer() -> bool:
	return _desktop_controller._has_captured_pet_pointer()

func _get_pet_at_position(window_position: Vector2) -> Node2D:
	return _desktop_controller._get_pet_at_position(window_position)

func _get_pet_input_rect(pet: Node2D) -> Rect2:
	return _desktop_controller._get_pet_input_rect(pet)

func _is_pet_pixel_hit(pet: Node2D, window_position: Vector2) -> bool:
	return _desktop_controller._is_pet_pixel_hit(pet, window_position)

func _get_window_mouse_position(window: Window) -> Vector2:
	return _desktop_controller._get_window_mouse_position(window)

func _update_offering_cursor_state() -> void:
	_offering_controller._update_offering_cursor_state()

func _create_offering_input_window() -> void:
	_offering_controller._create_offering_input_window()

func _update_offering_input_window() -> void:
	_offering_controller._update_offering_input_window()

func _on_offering_input(event: InputEvent) -> void:
	_offering_controller._on_offering_input(event)

func _pet_the_pet(actor: Node2D) -> void:
	_desktop_controller._pet_the_pet(actor)

func _choose_petting_emotion(pet_id: String) -> String:
	return _desktop_controller._choose_petting_emotion(pet_id)

func _set_offering_cursor(texture_path: String) -> void:
	_offering_controller._set_offering_cursor(texture_path)

func _refresh_offering_cursor() -> void:
	_offering_controller._refresh_offering_cursor()

func _clear_offering_cursor() -> void:
	_offering_controller._clear_offering_cursor()

func _make_cursor_texture(texture_path: String, target_size: Vector2i) -> Texture2D:
	return _offering_controller._make_cursor_texture(texture_path, target_size)

func _get_scaled_cursor_size(texture_path: String, sprite_scale: float, fallback_size: Vector2i) -> Vector2i:
	return _offering_controller._get_scaled_cursor_size(texture_path, sprite_scale, fallback_size)

func _spawn_emotion(actor: Node2D, emotion_name: String, offset: Vector2, effect_scale: float, delay := 0.0, primary := false) -> bool:
	return _desktop_controller._spawn_emotion(actor, emotion_name, offset, effect_scale, delay, primary)

func _get_safe_emotion_position(actor: Node2D, offset: Vector2, texture: Texture2D, sprite_scale: float) -> Vector2:
	return _desktop_controller._get_safe_emotion_position(actor, offset, texture, sprite_scale)

func _get_safe_sprite_position(raw_position: Vector2, texture: Texture2D, sprite_scale: float, margin: float) -> Vector2:
	return _desktop_controller._get_safe_sprite_position(raw_position, texture, sprite_scale, margin)

func _pulse_active_emotion(actor: Node2D, pet_id: String) -> void:
	_desktop_controller._pulse_active_emotion(actor, pet_id)

func _clear_active_emotion(pet_id: String, sprite: Sprite2D) -> void:
	_desktop_controller._clear_active_emotion(pet_id, sprite)

func _clear_pet_runtime_effects(pet_id: String) -> void:
	_desktop_controller._clear_pet_runtime_effects(pet_id)

func _get_emotion_texture_path(emotion_name: String) -> String:
	return _desktop_controller._get_emotion_texture_path(emotion_name)

func _refresh_pet_stats(force := false) -> void:
	_presentation_controller._refresh_pet_stats(force)

func _on_drawer_opened() -> void:
	_presentation_controller._on_drawer_opened()

func _refresh_faith_display() -> void:
	_presentation_controller._refresh_faith_display()

func _refresh_coin_display() -> void:
	_presentation_controller._refresh_coin_display()

func _refresh_follower_display() -> void:
	_presentation_controller._refresh_follower_display()

func _sync_shop_state() -> void:
	_presentation_controller._sync_shop_state()

func _sync_achievement_state() -> void:
	_presentation_controller._sync_achievement_state()

func _update_playtime_display(delta: float) -> void:
	_presentation_controller._update_playtime_display(delta)

func _initialize_news_feed() -> void:
	_presentation_controller._initialize_news_feed()

func _update_news(delta: float) -> void:
	_presentation_controller._update_news(delta)

func _schedule_next_ambient_news(now: float) -> void:
	_presentation_controller._schedule_next_ambient_news(now)

func _queue_news_candidate(article: Dictionary) -> void:
	_presentation_controller._queue_news_candidate(article)

func _make_news_context(extra := {}) -> Dictionary:
	return _presentation_controller._make_news_context(extra)

func _try_queue_news_event(
	event_type: String,
	extra_context: Dictionary,
	event_key: String,
	cooldown_seconds: float,
	chance := 1.0
) -> void:
	_presentation_controller._try_queue_news_event(event_type, extra_context, event_key, cooldown_seconds, chance)

func _publish_news(article: Dictionary, high_priority := false, broadcast := true) -> Dictionary:
	return _presentation_controller._publish_news(article, high_priority, broadcast)

func _enqueue_news_broadcast(entry: Dictionary, high_priority := false) -> void:
	_presentation_controller._enqueue_news_broadcast(entry, high_priority)

func _show_next_news_broadcast() -> void:
	_presentation_controller._show_next_news_broadcast()

func _get_localized_news_category(category: String) -> String:
	return _presentation_controller._get_localized_news_category(category)

func _finish_news_broadcast() -> void:
	_presentation_controller._finish_news_broadcast()

func _load_game() -> void:
	_persistence_controller._load_game()

func _request_save() -> void:
	_persistence_controller._request_save()

func _save_game() -> Error:
	return _persistence_controller._save_game()

func _reset_game_progress() -> void:
	_persistence_controller._reset_game_progress()

func _get_save_slots() -> Array[Dictionary]:
	return _persistence_controller.get_save_slots()

func _get_active_save_slot_id() -> String:
	return _persistence_controller.get_active_save_slot_id()

func _create_save_slot(slot_id: String) -> Dictionary:
	return _persistence_controller.create_save_slot(slot_id)

func _switch_save_slot(slot_id: String) -> Dictionary:
	return _persistence_controller.switch_save_slot(slot_id)

func _rename_save_slot(slot_id: String, display_name: String) -> Dictionary:
	return _persistence_controller.rename_save_slot(slot_id, display_name)

func _delete_save_slot(slot_id: String) -> Dictionary:
	return _persistence_controller.delete_save_slot(slot_id)

func _apply_offline_progress() -> void:
	_persistence_controller._apply_offline_progress()

func _update_autosave(delta: float) -> void:
	_persistence_controller._update_autosave(delta)

func _sanitize_loaded_pet_states(raw_value: Variant) -> Dictionary:
	return _persistence_controller._sanitize_loaded_pet_states(raw_value)

func _sanitize_owned_counts(raw_value: Variant) -> Dictionary:
	return _persistence_controller._sanitize_owned_counts(raw_value)

func _sanitize_item_states(raw_value: Variant) -> Dictionary:
	return _persistence_controller._sanitize_item_states(raw_value)

func _sanitize_loaded_offering_buffs(raw_value: Variant) -> Dictionary:
	return _persistence_controller._sanitize_loaded_offering_buffs(raw_value)

func _is_pet_unlocked(pet_id: String) -> bool:
	return _progression_controller._is_pet_unlocked(pet_id)

func _get_inventory_pet_entries() -> Array[Dictionary]:
	return _progression_controller._get_inventory_pet_entries()

func _select_pet(actor: Node2D) -> void:
	_progression_controller._select_pet(actor)

func _ensure_pet_state(pet_id: String) -> void:
	_progression_controller._ensure_pet_state(pet_id)

func _get_pet_state(pet_id: String) -> Dictionary:
	return _progression_controller._get_pet_state(pet_id)

func _is_pet_recovering(pet_id: String, now := -1.0) -> bool:
	return _progression_controller._is_pet_recovering(pet_id, now)

func _get_pet_recovery_info(pet_id: String) -> Dictionary:
	return _progression_controller._get_pet_recovery_info(pet_id)

func _update_recovery_states(delta: float) -> void:
	_progression_controller._update_recovery_states(delta)

func _get_pet_upgrade_entries() -> Array[Dictionary]:
	return _progression_controller._get_pet_upgrade_entries()

func _get_pet_age_text(pet_data: Dictionary) -> String:
	return _progression_controller._get_pet_age_text(pet_data)

func _get_upgrade_cost(pet_id: String) -> int:
	return _progression_controller._get_upgrade_cost(pet_id)

func _get_faith_growth_rate() -> float:
	return _progression_controller._get_faith_growth_rate()

func _calculate_faith_growth_rate() -> float:
	return _progression_controller._calculate_faith_growth_rate()

func _get_baseline_faith_growth_rate() -> float:
	return _progression_controller._get_baseline_faith_growth_rate()

func _get_follower_growth_rate() -> float:
	return _progression_controller._get_follower_growth_rate()

func _get_achievement_metrics() -> Dictionary:
	return _progression_controller._get_achievement_metrics()

func _get_pet_faith_per_second(pet_id: String, level: int) -> float:
	return _progression_controller._get_pet_faith_per_second(pet_id, level)

func _get_pet_money_value_per_minute(pet_id: String, level: int) -> float:
	return _progression_controller._get_pet_money_value_per_minute(pet_id, level)

func _get_pet_offering_multiplier(pet_id: String, now := -1.0) -> float:
	return _progression_controller._get_pet_offering_multiplier(pet_id, now)

func _get_pet_offering_seconds_remaining(pet_id: String, now := -1.0) -> float:
	return _progression_controller._get_pet_offering_seconds_remaining(pet_id, now)

func _update_pet_offering_buffs() -> void:
	_progression_controller._update_pet_offering_buffs()

func _get_total_faith_multiplier() -> float:
	return _progression_controller._get_total_faith_multiplier()

func _get_pet_display_name(pet_id: String) -> String:
	return _progression_controller._get_pet_display_name(pet_id)

func _apply_pet_display_name(pet_id: String) -> void:
	_progression_controller._apply_pet_display_name(pet_id)

func _set_pet_custom_name(pet_id: String, custom_name: String) -> void:
	_progression_controller._set_pet_custom_name(pet_id, custom_name)

func _grant_faith(amount: float) -> void:
	_progression_controller._grant_faith(amount)

func _update_faith(delta: float) -> void:
	_progression_controller._update_faith(delta)

func _update_followers(delta: float) -> void:
	_progression_controller._update_followers(delta)

func _update_pet_emotions() -> void:
	_desktop_controller._update_pet_emotions()

func _schedule_next_ambient_emotion(pet_id: String, now := -1.0) -> void:
	_desktop_controller._schedule_next_ambient_emotion(pet_id, now)

func _get_actor_pet_id(actor: Node2D) -> String:
	return _desktop_controller._get_actor_pet_id(actor)

func _get_now_seconds() -> float:
	return _desktop_controller._get_now_seconds()

func _get_news_runtime_seconds() -> float:
	return _desktop_controller._get_news_runtime_seconds()

func _get_current_screen_usable_rect() -> Rect2i:
	return _desktop_controller._get_current_screen_usable_rect()

func _get_current_screen() -> int:
	return _desktop_controller._get_current_screen()

func _on_pet_petted(actor: Node2D) -> void:
	_desktop_controller._on_pet_petted(actor)

func _on_pet_grabbed_changed(actor: Node2D, grabbed: bool) -> void:
	_desktop_controller._on_pet_grabbed_changed(actor, grabbed)

func _on_pet_drag_released(actor: Node2D) -> void:
	_desktop_controller._on_pet_drag_released(actor)

func _on_pet_notable_action(actor: Node2D, action_id: String) -> void:
	_desktop_controller._on_pet_notable_action(actor, action_id)

func _on_pet_recall_requested(actor: Node2D) -> void:
	_desktop_controller._on_pet_recall_requested(actor)

func _finish_pending_offering_for_actor(actor: Node2D) -> void:
	_desktop_controller._finish_pending_offering_for_actor(actor)

func _on_believer_exited(actor: Node2D) -> void:
	_desktop_controller._on_believer_exited(actor)

func _get_first_desktop_pet_id() -> String:
	return _desktop_controller._get_first_desktop_pet_id()

func _on_inventory_requested() -> void:
	_presentation_controller._on_inventory_requested()

func _on_shop_requested() -> void:
	_presentation_controller._on_shop_requested()

func _on_achievements_requested() -> void:
	_presentation_controller._on_achievements_requested()

func _on_news_requested() -> void:
	_presentation_controller._on_news_requested()

func _on_settings_requested() -> void:
	_presentation_controller._on_settings_requested()

func _on_achievement_claim_requested(achievement_id: String) -> void:
	_progression_controller._on_achievement_claim_requested(achievement_id)

func _unlock_growth_eligible_pets() -> Array[String]:
	return _progression_controller._unlock_growth_eligible_pets()

func _on_shop_purchase_requested(good_id: String) -> void:
	_progression_controller._on_shop_purchase_requested(good_id)

func _on_inventory_pet_deploy_requested(pet_id: String) -> void:
	_progression_controller._on_inventory_pet_deploy_requested(pet_id)

func _on_inventory_pet_rename_requested(pet_id: String, custom_name: String) -> void:
	_progression_controller._on_inventory_pet_rename_requested(pet_id, custom_name)

func _on_inventory_pet_evolution_requested(pet_id: String) -> void:
	_progression_controller._on_inventory_pet_evolution_requested(pet_id)

func _apply_automatic_evolution_thresholds() -> bool:
	return _progression_controller._apply_automatic_evolution_thresholds()

func _show_next_evolution_notification() -> void:
	_progression_controller._show_next_evolution_notification()

func _on_evolution_notification_dismissed() -> void:
	_progression_controller._on_evolution_notification_dismissed()

func _replace_deployed_pet_form(pet_id: String) -> void:
	_progression_controller._replace_deployed_pet_form(pet_id)

func _sync_deployed_pet_level(pet_id: String) -> void:
	_progression_controller._sync_deployed_pet_level(pet_id)

func _on_pet_detail_rename_requested(pet_id: String, custom_name: String) -> void:
	_progression_controller._on_pet_detail_rename_requested(pet_id, custom_name)

func _cancel_carried_offering() -> void:
	_offering_controller._cancel_carried_offering()

func _drop_carried_offering(window_position: Vector2) -> void:
	_offering_controller._drop_carried_offering(window_position)

func _get_grounded_offering_position(click_x: float, texture: Texture2D, sprite_scale: float) -> Vector2:
	return _offering_controller._get_grounded_offering_position(click_x, texture, sprite_scale)

func _get_offering_target_pet(drop_x: float) -> Node2D:
	return _offering_controller._get_offering_target_pet(drop_x)

func _send_pet_to_offering(target: Node2D, target_key: String, target_x: float) -> void:
	_offering_controller._send_pet_to_offering(target, target_key, target_x)

func _update_pending_offerings() -> void:
	_offering_controller._update_pending_offerings()

func _mark_offering_landed(target_key: String) -> void:
	_offering_controller._mark_offering_landed(target_key)

func _on_pet_forced_target_reached(actor: Node2D) -> void:
	_offering_controller._on_pet_forced_target_reached(actor)

func _consume_pending_offering(target_key: String) -> void:
	_offering_controller._consume_pending_offering(target_key)

func _finish_offering_consumed(
	sprite: Sprite2D,
	offering: Dictionary,
	popup_position: Vector2,
	pet_id := ""
) -> void:
	_offering_controller._finish_offering_consumed(sprite, offering, popup_position, pet_id)

func _apply_pet_offering_buff(pet_id: String, offering: Dictionary) -> void:
	_offering_controller._apply_pet_offering_buff(pet_id, offering)

func _react_pet_to_offering(pet_id: String) -> void:
	_offering_controller._react_pet_to_offering(pet_id)

func _get_desktop_pet_by_id(pet_id: String) -> Node2D:
	return _offering_controller._get_desktop_pet_by_id(pet_id)

func _show_offering_buff_popup(anchor: Vector2, pet_id: String, offering: Dictionary) -> void:
	_offering_controller._show_offering_buff_popup(anchor, pet_id, offering)

func _show_faith_change_popup(anchor: Vector2, amount: float) -> void:
	_offering_controller._show_faith_change_popup(anchor, amount)

func _show_coin_change_popup(anchor: Vector2, amount: int, coin_type := "") -> void:
	_offering_controller._show_coin_change_popup(anchor, amount, coin_type)

func _show_status_popup(anchor: Vector2, text_value: String, color: Color) -> void:
	_offering_controller._show_status_popup(anchor, text_value, color)

func _get_safe_control_position(raw_position: Vector2, size: Vector2, margin: float) -> Vector2:
	return _offering_controller._get_safe_control_position(raw_position, size, margin)

func _on_pet_upgrade_requested(pet_id: String) -> void:
	_progression_controller._on_pet_upgrade_requested(pet_id)


func _on_faith_add_requested(amount: int) -> void:
	_progression_controller._on_faith_add_requested(amount)

func _on_menu_handle_moved(anchor: float) -> void:
	_progression_controller._on_menu_handle_moved(anchor)

func _on_activity_range_changed(range_mode: String) -> void:
	_progression_controller._on_activity_range_changed(range_mode)

func _on_debug_economy_requested(faith_points: float, gold_coins: int) -> void:
	_progression_controller._on_debug_economy_requested(faith_points, gold_coins)

func _on_debug_simulation_requested(enemy_power_scale: float, game_speed: float) -> void:
	_progression_controller._on_debug_simulation_requested(enemy_power_scale, game_speed)

func _on_debug_era_requested(era_index: int) -> void:
	_progression_controller._on_debug_era_requested(era_index)

func _get_debug_pet_levels() -> Dictionary:
	return _progression_controller._get_debug_pet_levels()

func _on_debug_pet_levels_requested(levels: Dictionary) -> void:
	_progression_controller._on_debug_pet_levels_requested(levels)

func _on_debug_event_requested(event_type: String) -> void:
	_progression_controller._on_debug_event_requested(event_type)

func _on_language_changed(language_code: String) -> void:
	_progression_controller._on_language_changed(language_code)

func _apply_language() -> void:
	_progression_controller._apply_language()

func _get_manual_faith_click_gain(base_amount := 1) -> float:
	return _progression_controller._get_manual_faith_click_gain(base_amount)

func _get_campaign_level_cap() -> int:
	return _campaign_controller._get_campaign_level_cap()

func _is_endless_mode() -> bool:
	return _campaign_controller._is_endless_mode()

func _should_offer_final_boss() -> bool:
	return _campaign_controller._should_offer_final_boss()

func _get_potential_coin_rate() -> float:
	return _campaign_controller._get_potential_coin_rate()

func _get_dynamic_shop_goods() -> Array[Dictionary]:
	return _campaign_controller._get_dynamic_shop_goods()

func _check_campaign_completion() -> bool:
	return _campaign_controller._check_campaign_completion()

func _on_final_boss_defeated() -> void:
	_campaign_controller._on_final_boss_defeated()

func _on_completion_continue_requested() -> void:
	_campaign_controller._on_completion_continue_requested()

func _on_endless_mode_requested() -> void:
	_campaign_controller._on_endless_mode_requested()

func _on_quit_requested() -> void:
	_progression_controller._on_quit_requested()
