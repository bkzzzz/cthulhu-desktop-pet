extends Node2D

# Dependencies
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const FollowerProgression = preload("res://scripts/domain/follower_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const NewsFeed = preload("res://scripts/domain/news_feed.gd")
const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const EnemyProjectileActor = preload("res://scripts/enemy_projectile_actor.gd")
const BattleEffectActor = preload("res://scripts/battle_effect_actor.gd")
const EventInvitation = preload("res://scripts/event_invitation.gd")
const InventoryWindowScript = preload("res://scripts/inventory_window.gd")
const ShopWindowScript = preload("res://scripts/shop_window.gd")
const GachaWindowScript = preload("res://scripts/gacha_window.gd")
const NewsWindowScript = preload("res://scripts/news_window.gd")
const SettingsWindowScript = preload("res://scripts/settings_window.gd")
const SideDrawerController = preload("res://scripts/side_drawer_controller.gd")
const NativeVisualClickthrough = preload("res://scripts/native_visual_clickthrough.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")

# Window and actor layout
const PET_WINDOW_BASE_SIZE := Vector2i(820, 420)
const PET_TASKBAR_OVERLAP_PIXELS := 16
const PET_STAGE_MARGIN_X := 0.0
const PET_STAGE_RIGHT_MARGIN := 0.0
const PET_STAGE_START_SPACING := 132.0
const POSITION_RETRY_FRAMES := 12
const BACKGROUND_LOGIC_INTERVAL := 0.10
const POINTER_HOVER_INTERVAL := 1.0 / 15.0

# Pet interaction and offering tuning
const OFFERING_CURSOR_SIZE := Vector2i(52, 52)
const OFFERING_DROP_SCALE := 0.36
const OFFERING_FEED_TIMEOUT_SECONDS := 12.0
const OFFERING_GROUND_MARGIN := 2.0
const SAFE_CANVAS_MARGIN := 12.0
const EMOTION_CONFUSED_TEXTURE := "res://assets/ui/emotions/confused.png"
const EMOTION_HAPPY_TEXTURE := "res://assets/ui/emotions/happy.png"
const EMOTION_LIKE_TEXTURE := "res://assets/ui/emotions/like.png"
const EMOTION_SLEEPY_TEXTURE := "res://assets/ui/emotions/sleepy.png"
const EMOTION_SUPRISED_TEXTURE := "res://assets/ui/emotions/suprised.png"
const EMOTION_SCALE := 0.28

# Simulation and refresh cadence
const EMOTION_MIN_INTERVAL_SECONDS := 2.8
const EMOTION_HOLD_SECONDS := 3.2
const GLOBAL_FAITH_MULTIPLIER := 1.0
const BUFF_FAITH_MULTIPLIER := 1.0
const BELIEVER_MIN_ACTIVE := 0
const BELIEVER_MAX_ACTIVE := 2
const BELIEVER_SPAWN_MIN_SECONDS := 18.0
const BELIEVER_SPAWN_MAX_SECONDS := 36.0
const BELIEVER_FORCE_SPAWN_SECONDS := 60.0
const BELIEVER_SECOND_SPAWN_CHANCE := 0.30
const PILGRIMAGE_UNLOCK_RUNTIME_SECONDS := 180.0
const PILGRIMAGE_INITIAL_DELAY_MIN_SECONDS := 120.0
const PILGRIMAGE_INITIAL_DELAY_MAX_SECONDS := 240.0
const PILGRIMAGE_INTERVAL_MIN_SECONDS := 420.0
const PILGRIMAGE_INTERVAL_MAX_SECONDS := 720.0
const PILGRIMAGE_DURATION_SECONDS := 32.0
const PILGRIMAGE_GROUP_MIN := 2
const PILGRIMAGE_GROUP_MAX := 4
const PILGRIMAGE_GROUP_MEMBER_MIN := 3
const PILGRIMAGE_GROUP_MEMBER_MAX := 5
const PILGRIMAGE_GROUP_SPACING := 54.0
const PILGRIMAGE_GROUP_EDGE_MARGIN := 190.0
const PILGRIMAGE_PET_CLEARANCE := 240.0
const PET_P_COIN_CHANCE := 0.18
const PET_AUTO_COIN_INTERVAL_MIN := 12.0
const PET_AUTO_COIN_INTERVAL_MAX := 62.0
const PET_AUTO_COIN_PILE_MIN := 4
const PET_AUTO_COIN_PILE_MAX := 10
const DESKTOP_COIN_LIMIT := 96
const CRYSTAL_UNLOCK_SCORES := {"C": 80, "S": 180, "G": 320}
const CRYSTAL_RARITY_BONUSES := {1: 0, 2: 15, 3: 35, 4: 65, 5: 100}
const PET11_ABSORB_INITIAL_MIN_SECONDS := 24.0
const PET11_ABSORB_INITIAL_MAX_SECONDS := 42.0
const PET11_ABSORB_COOLDOWN_MIN_SECONDS := 70.0
const PET11_ABSORB_COOLDOWN_MAX_SECONDS := 115.0
const PET11_ABSORB_HOLD_MIN_SECONDS := 4.0
const PET11_ABSORB_HOLD_MAX_SECONDS := 7.0
const PET11_BATTLE_ABSORB_MIN_SECONDS := 5.5
const PET11_BATTLE_ABSORB_MAX_SECONDS := 7.5
const PET11_BATTLE_FIRST_ABSORB_MIN_SECONDS := 0.65
const PET11_BATTLE_FIRST_ABSORB_MAX_SECONDS := 1.15
const UI_REFRESH_INTERVAL := 0.25
const MANUAL_CLICK_RATE_SECONDS := 0.25
const SAVE_PATH := "user://cthulu_save.cfg"
const SAVE_VERSION := 10
const PET_UNLOCK_SAVE_VERSION := 8
const NEWS_RATE_MODEL_SAVE_VERSION := 5
const AUTOSAVE_INTERVAL_SECONDS := 30.0
const OFFLINE_PROGRESS_MAX_SECONDS := 12.0 * 60.0 * 60.0
const OFFLINE_PROGRESS_EFFICIENCY := 0.5
const NO_SAVE_ARGUMENT := "--no-save"
const NEWS_MILESTONE_CHECK_INTERVAL := 0.5
const NEWS_INITIAL_AMBIENT_DELAY := 45.0
const NEWS_EVENT_GLOBAL_COOLDOWN := 45.0
const NEWS_BROADCAST_QUEUE_LIMIT := 2
const NEWS_STORY_BACKLOG_LIMIT := 3
const NEWS_BROADCAST_SIZE := Vector2(700.0, 68.0)
const NEWS_BROADCAST_FONT_SIZE := 24
const PILGRIMAGE_BROADCAST_SIZE := Vector2(760.0, 132.0)
const PILGRIMAGE_BROADCAST_FONT_SIZE := 46
const PILGRIMAGE_INVITE_TEXTURE := "res://assets/ui/items/prayIcon.png"
const BATTLE_INVITE_TEXTURE := "res://assets/ui/items/fightIcon.png"
const BATTLE_UNLOCK_RUNTIME_SECONDS := 300.0
const BATTLE_INITIAL_DELAY_MIN_SECONDS := 150.0
const BATTLE_INITIAL_DELAY_MAX_SECONDS := 270.0
const BATTLE_INTERVAL_MIN_SECONDS := 360.0
const BATTLE_INTERVAL_MAX_SECONDS := 600.0
const BATTLE_DURATION_SECONDS := 42.0
const BATTLE_DIFFICULTY_VARIANCE_MIN := 0.82
const BATTLE_DIFFICULTY_VARIANCE_MAX := 1.18
const BATTLE_PET_RECOVERY_MIN_SECONDS := 75.0
const BATTLE_PET_RECOVERY_MAX_SECONDS := 180.0
const SMOKE_SHEET_TEXTURE := "res://assets/effects/smoke/smoke1_sheet.png"
const SMOKE_FRAME_COUNT := 10
const RANGED_BATTLE_PET_IDS := ["pet2", "pet7", "pet8", "pet9", "pet10", "pet11"]

# Runtime actors and input state
var _pets: Array[Node2D] = []
var _believers: Array[Node2D] = []
var _coin_drops: Array[Node2D] = []
var _hovered_pet: Node2D
var _active_emotions: Dictionary = {}
var _active_emotion_tweens: Dictionary = {}
var _next_emotion_allowed_at: Dictionary = {}
var _next_ambient_emotion_at: Dictionary = {}
var _carried_offering: Dictionary = {}
var _current_cursor_texture: Texture2D
var _offering_cursor_texture: Texture2D
var _offering_cursor_path := ""
var _offering_cursor_size := Vector2i.ZERO
var _offering_cursor_active := false
var _offering_input_window: Window
var _offering_input_area: Control
var _pending_offering_feeds: Dictionary = {}
var _pet_offering_buffs: Dictionary = {}
var _position_retry_frames := 0
var _pet_window_size := PET_WINDOW_BASE_SIZE
var _rng := RandomNumberGenerator.new()

# Economy and UI state
var _selected_pet_id := ""
var _pet_states: Dictionary = {}
var _unlocked_pet_ids: Array[String] = ["pet1"]
var _deployed_pet_ids: Array[String] = ["pet1"]
var _faith_points := 0.0
var _stats_refresh_timer := 0.0
var _last_reported_faith_count := -1
var _last_reported_growth_rate := -1.0
var _pet_upgrade_stats_dirty := true
var _next_believer_spawn_at := 0.0
var _last_believer_spawn_at := 0.0
var _pilgrimage_active := false
var _pilgrimage_ends_at := 0.0
var _next_pilgrimage_at := 0.0
var _event_invitation: Node2D
var _battle_active := false
var _battle_started_at := 0.0
var _battle_ends_at := 0.0
var _next_battle_at := 0.0
var _battle_enemies: Array[Node2D] = []
var _battle_effects: Array[Node2D] = []
var _battle_wave_schedule: Array[Dictionary] = []
var _battle_next_wave_index := 0
var _battle_pet_health := {}
var _battle_pet_max_health := {}
var _battle_pet_attack_at := {}
var _battle_pet_target_x := {}
var _battle_pet_formed := {}
var _battle_save_pending := false
var _pending_battle_difficulty_scale := -1.0
var _active_battle_difficulty_scale := -1.0
var _last_era_display := ""
var _recovery_ui_refresh_time := 0.0
var _smoke_frames: SpriteFrames
var _inventory_window: Window
var _shop_window: Window
var _gacha_window: Window
var _news_window: Window
var _settings_window: Window
var _follower_count := 0.0
var _last_reported_follower_count := -1
var _shop_owned_counts := {}
var _side_drawer: Node
var _lifetime_faith := 0.0
var _gold_coins := 0
var _gacha_draw_count := 0
var _gacha_pity_count := 0
var _gacha_history: Array[Dictionary] = []
var _autosave_timer := 0.0
var _loaded_save_unix := 0.0
var _loaded_menu_handle_anchor := -1.0
var _persistence_enabled := true
var _news_feed := NewsFeed.new()
var _loaded_news_state: Dictionary = {}
var _news_broadcast_panel: PanelContainer
var _news_broadcast_label: Label
var _news_broadcast_queue: Array[Dictionary] = []
var _news_broadcast_tween: Tween
var _news_broadcast_active := false
var _pilgrimage_broadcast_panel: PanelContainer
var _pilgrimage_broadcast_title: Label
var _pilgrimage_broadcast_subtitle: Label
var _pilgrimage_status_label: Label
var _pilgrimage_broadcast_tween: Tween
var _news_story_backlog: Array[Dictionary] = []
var _next_news_at := 0.0
var _news_milestone_check_timer := 0.0
var _next_pet_coin_drop_at := {}
var _pet_coin_drop_intervals := {}
var _next_pet11_absorb_at := 0.0
var _background_logic_time := 0.0
var _pointer_hover_time := 0.0
var _session_runtime_seconds := 0.0
var _total_runtime_seconds := 0.0
var _settings_refresh_timer := 0.0
var _pet_activity_range := "full"
var _language := "zh"
var _debug_enemy_power_scale := 1.0
var _debug_game_speed := 1.0
var _simulation_now_seconds := 0.0


# Lifecycle
func _ready() -> void:
	Input.use_accumulated_input = false
	_rng.randomize()
	_simulation_now_seconds = Time.get_unix_time_from_system()
	_persistence_enabled = (
		DisplayServer.get_name() != "headless"
		and not OS.get_cmdline_user_args().has(NO_SAVE_ARGUMENT)
	)
	if not _configure_pet_window():
		push_error("Desktop pets stopped because safe click-through setup failed.")
		get_tree().quit(2)
		return
	_place_pet_window()
	_load_game()
	_apply_offline_progress()
	_initialize_news_feed()
	_create_desktop_pets()
	_create_news_broadcast()
	_create_pilgrimage_broadcast()
	_create_offering_input_window()
	_create_side_drawer()
	_create_inventory_window()
	_create_shop_window()
	_create_gacha_window()
	_create_news_window()
	_create_settings_window()
	if _news_feed.get_history().is_empty():
		_publish_news({
			"category": "公告",
			"headline": "《教团简报》开始播报：3名志愿者正在旧城区筹备首个聚会点，招募尚未形成规模。"
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

	_position_retry_frames = POSITION_RETRY_FRAMES
	_place_pet_window()
	call_deferred("_place_pet_window")
	call_deferred("_update_offering_input_window")


func _process(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	_simulation_now_seconds += safe_delta
	_session_runtime_seconds += safe_delta
	_total_runtime_seconds += safe_delta
	# Formation is visual movement and must run at render cadence. It used to be
	# buried in the 10 Hz background simulation, making a healthy frame rate look
	# like severe stutter whenever several pets crossed the desktop together.
	_update_battle_pet_formation(safe_delta)
	if _position_retry_frames > 0:
		_position_retry_frames -= 1
		_place_pet_window()

	_pointer_hover_time += safe_delta
	if _has_captured_pet_pointer() or _pointer_hover_time >= POINTER_HOVER_INTERVAL:
		_pointer_hover_time = 0.0
		_update_pet_hover()
	if not _carried_offering.is_empty():
		_update_offering_input_window()
		_update_offering_cursor_state()

	_background_logic_time += safe_delta
	if _background_logic_time < BACKGROUND_LOGIC_INTERVAL:
		return
	var logic_delta := _background_logic_time
	_background_logic_time = 0.0
	_update_pet_offering_buffs()
	_update_recovery_states(logic_delta)
	_update_faith(logic_delta)
	_update_followers(logic_delta)
	_update_news(logic_delta)
	_update_pet_emotions()
	_update_pet11_absorb_ability()
	_update_pilgrimage()
	_update_event_invitations()
	_update_battle(logic_delta)
	_update_believers()
	_update_pending_offerings()
	_update_coin_drops()
	_update_ambient_coin_drops()
	_update_settings_runtime(logic_delta)
	_update_autosave(logic_delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_all_pet_pointer_captures()
		call_deferred("_restore_desktop_input")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Engine.time_scale = 1.0
		_save_game()
		get_tree().quit()
# Window setup
func _configure_pet_window() -> bool:
	var window := get_window()
	var usable_rect := _get_current_screen_usable_rect()
	_pet_window_size = _get_target_pet_window_size(usable_rect)
	window.title = "Cthulu Desktop Pets"
	window.min_size = Vector2i.ZERO
	window.size = _pet_window_size
	window.transparent_bg = true
	window.transparent = true
	window.borderless = true
	window.always_on_top = false
	window.unfocusable = true
	window.unresizable = true

	get_viewport().transparent_bg = true

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	if not NativeVisualClickthrough.apply(window):
		return false
	return true


# Desktop actors
func _create_desktop_pets() -> void:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()

	for index in _deployed_pet_ids.size():
		var pet_id := String(_deployed_pet_ids[index])
		if not _is_pet_unlocked(pet_id):
			continue
		var start_x := max_x - (float(index) * PET_STAGE_START_SPACING)
		if start_x < min_x:
			start_x = lerpf(min_x, max_x, float(index % 5) / 4.0)

		_spawn_desktop_pet(pet_id, start_x)


func _spawn_desktop_pet(pet_id: String, start_x := -1.0) -> Node2D:
	if pet_id.is_empty():
		return null

	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	var spawn_x := start_x
	if spawn_x < 0.0:
		spawn_x = _get_next_pet_start_x()

	var actor := DesktopPetActor.new()
	actor.setup(
		pet_id,
		_pet_window_size,
		min_x,
		max_x,
		spawn_x,
		float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
		_get_effective_pet_activity_range() != "full"
	)
	_ensure_pet_state(pet_id)
	if actor.has_method("set_display_name"):
		actor.call("set_display_name", _get_pet_display_name(pet_id))
	if actor.has_method("set_language"):
		actor.call("set_language", _language)
	actor.petted.connect(_on_pet_petted)
	actor.recall_requested.connect(_on_pet_recall_requested)
	actor.forced_target_reached.connect(_on_pet_forced_target_reached)
	actor.notable_action.connect(_on_pet_notable_action)
	actor.grabbed_changed.connect(_on_pet_grabbed_changed)
	add_child(actor)
	_pets.append(actor)
	_schedule_pet_coin_drop(actor, _get_now_seconds())
	if pet_id == "pet11" and _next_pet11_absorb_at <= 0.0:
		_schedule_next_pet11_absorb(_get_now_seconds(), true)
	if _pilgrimage_active and actor.has_method("set_autonomy_paused"):
		actor.call("set_autonomy_paused", true)
	elif _battle_active and actor.has_method("set_battle_mode"):
		actor.call("set_battle_mode", true)
	_schedule_next_ambient_emotion(pet_id)
	if _selected_pet_id.is_empty():
		_selected_pet_id = pet_id
	return actor


func _get_next_pet_start_x() -> float:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	var start_x := max_x - (float(_pets.size()) * PET_STAGE_START_SPACING)
	if start_x < min_x:
		start_x = _rng.randf_range(min_x, max_x)
	return start_x


func _get_pet_stage_min_x() -> float:
	if _get_effective_pet_activity_range() == "right":
		return maxf(PET_STAGE_MARGIN_X, float(_pet_window_size.x) * 0.5 + 24.0)
	return PET_STAGE_MARGIN_X


func _get_pet_stage_max_x() -> float:
	var full_max := float(_pet_window_size.x) - PET_STAGE_RIGHT_MARGIN
	if _get_effective_pet_activity_range() == "left":
		return maxf(_get_pet_stage_min_x() + 1.0, float(_pet_window_size.x) * 0.5 - 24.0)
	return maxf(_get_pet_stage_min_x() + 1.0, full_max)


func _get_effective_pet_activity_range() -> String:
	return "full" if _pilgrimage_active or _battle_active else _pet_activity_range


# Believers
func _update_believers() -> void:
	_cleanup_believers()
	var threat_positions := _get_believer_threat_positions()
	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_threat_positions"):
			believer.call("set_threat_positions", threat_positions)
	if _pilgrimage_active or _battle_active:
		return

	var now := _get_now_seconds()
	if now < _next_believer_spawn_at:
		return

	if _believers.size() >= BELIEVER_MAX_ACTIVE:
		_schedule_next_believer_spawn(now)
		return

	var available_slots := BELIEVER_MAX_ACTIVE - _believers.size()
	var spawn_count := 1
	if available_slots >= 2 and _rng.randf() < BELIEVER_SECOND_SPAWN_CHANCE:
		spawn_count = 2
	for _spawn_index in mini(spawn_count, available_slots):
		_spawn_believer(false)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)


func _schedule_next_believer_spawn(now: float) -> void:
	var random_delay := _rng.randf_range(BELIEVER_SPAWN_MIN_SECONDS, BELIEVER_SPAWN_MAX_SECONDS)
	var time_since_last_spawn := maxf(0.0, now - _last_believer_spawn_at)
	var force_delay := maxf(BELIEVER_SPAWN_MIN_SECONDS, BELIEVER_FORCE_SPAWN_SECONDS - time_since_last_spawn)
	_next_believer_spawn_at = now + minf(random_delay, force_delay)


func _spawn_believer(visible_on_spawn := false) -> void:
	var believer: Node2D = BelieverActor.new()
	var spawn_from_left: bool = _rng.randf() < 0.5
	var ground_contact_y := float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	if visible_on_spawn and believer.has_method("setup_visible"):
		believer.call("setup_visible", _pet_window_size, ground_contact_y)
	else:
		believer.call("setup", _pet_window_size, spawn_from_left, ground_contact_y)
	believer.connect("exited", Callable(self, "_on_believer_exited"))
	believer.connect("scared_away", Callable(self, "_on_believer_scared_away"))
	believer.connect("prayed", Callable(self, "_on_believer_prayed"))
	add_child(believer)
	_believers.append(believer)
	if believer.has_method("set_threat_positions"):
		believer.call("set_threat_positions", _get_believer_threat_positions())


func _cleanup_believers() -> void:
	for index in range(_believers.size() - 1, -1, -1):
		if not is_instance_valid(_believers[index]):
			_believers.remove_at(index)


func _get_believer_threat_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		positions.append(pet.position)
	return positions


func _schedule_next_pilgrimage(now: float, initial := false) -> void:
	var delay_min := PILGRIMAGE_INITIAL_DELAY_MIN_SECONDS if initial else PILGRIMAGE_INTERVAL_MIN_SECONDS
	var delay_max := PILGRIMAGE_INITIAL_DELAY_MAX_SECONDS if initial else PILGRIMAGE_INTERVAL_MAX_SECONDS
	_next_pilgrimage_at = now + _rng.randf_range(delay_min, delay_max)


func _update_pilgrimage() -> void:
	var now := _get_now_seconds()
	if _pilgrimage_active:
		_update_pilgrimage_status(now)
		if now >= _pilgrimage_ends_at:
			_finish_pilgrimage(false)
		elif not _has_pending_pilgrims():
			_finish_pilgrimage(true)
		return
	if _battle_active:
		return

	if _total_runtime_seconds < PILGRIMAGE_UNLOCK_RUNTIME_SECONDS:
		return
	if _next_pilgrimage_at <= 0.0:
		_schedule_next_pilgrimage(now, true)
		return
	if now >= _next_pilgrimage_at:
		if _has_valid_desktop_pet() and _event_invitation == null:
			_spawn_event_invitation("pilgrimage")
		else:
			_next_pilgrimage_at = now + 60.0


func _schedule_next_battle(now: float, initial := false) -> void:
	var delay_min := BATTLE_INITIAL_DELAY_MIN_SECONDS if initial else BATTLE_INTERVAL_MIN_SECONDS
	var delay_max := BATTLE_INITIAL_DELAY_MAX_SECONDS if initial else BATTLE_INTERVAL_MAX_SECONDS
	_next_battle_at = now + _rng.randf_range(delay_min, delay_max)


func _update_event_invitations() -> void:
	_refresh_era_display()
	if _battle_active or _pilgrimage_active:
		return
	if _event_invitation != null and not is_instance_valid(_event_invitation):
		_event_invitation = null
	if _event_invitation != null:
		return
	if _total_runtime_seconds < BATTLE_UNLOCK_RUNTIME_SECONDS:
		return
	var now := _get_now_seconds()
	if _next_battle_at <= 0.0:
		_schedule_next_battle(now, true)
	elif now >= _next_battle_at and _has_valid_desktop_pet():
		_spawn_event_invitation("battle")


func _spawn_event_invitation(event_type: String) -> void:
	if _event_invitation != null or _battle_active or _pilgrimage_active:
		return
	if event_type != "battle":
		_pending_battle_difficulty_scale = -1.0
	var invite: Node2D = EventInvitation.new()
	var texture_path := BATTLE_INVITE_TEXTURE if event_type == "battle" else PILGRIMAGE_INVITE_TEXTURE
	var difficulty_text := ""
	if event_type == "battle":
		# Roll once when the envelope appears. The text and the actual battle now
		# refer to the same locked value instead of recomputing a fixed scale later.
		_pending_battle_difficulty_scale = _roll_battle_difficulty_scale()
		difficulty_text = _get_battle_difficulty_text(_pending_battle_difficulty_scale)
	var safe_margin := 120.0
	var spawn_x := _rng.randf_range(
		minf(safe_margin, float(_pet_window_size.x) * 0.25),
		maxf(safe_margin + 1.0, float(_pet_window_size.x) - safe_margin)
	)
	invite.call(
		"setup",
		event_type,
		texture_path,
		_pet_window_size,
		float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
		spawn_x,
		_language,
		difficulty_text
	)
	invite.connect("accepted", Callable(self, "_on_event_invitation_accepted"))
	invite.connect("discarded", Callable(self, "_on_event_invitation_discarded"))
	invite.connect("expired", Callable(self, "_on_event_invitation_expired"))
	add_child(invite)
	_event_invitation = invite


func _get_base_battle_difficulty_scale() -> float:
	var era_scale := 1.0 + float(EraProgression.get_era_index(_total_runtime_seconds)) * 0.32
	return maxf(0.0, _debug_enemy_power_scale * era_scale)


func _roll_battle_difficulty_scale() -> float:
	var variance := _rng.randf_range(
		BATTLE_DIFFICULTY_VARIANCE_MIN,
		BATTLE_DIFFICULTY_VARIANCE_MAX
	)
	return _get_base_battle_difficulty_scale() * variance


func _get_battle_difficulty_scale() -> float:
	if _active_battle_difficulty_scale >= 0.0:
		return _active_battle_difficulty_scale
	return _get_base_battle_difficulty_scale()


func _get_battle_difficulty_text(difficulty_override := -1.0) -> String:
	var difficulty := (
		maxf(0.0, difficulty_override)
		if difficulty_override >= 0.0
		else _get_battle_difficulty_scale()
	)
	var tier := ""
	if difficulty <= 0.35:
		tier = "TRIVIAL" if _language == "en" else "微不足道"
	elif difficulty <= 0.75:
		tier = "EASY" if _language == "en" else "简单"
	elif difficulty <= 1.25:
		tier = "NORMAL" if _language == "en" else "普通"
	elif difficulty <= 2.0:
		tier = "HARD" if _language == "en" else "困难"
	elif difficulty <= 4.0:
		tier = "NIGHTMARE" if _language == "en" else "噩梦"
	else:
		tier = "APOCALYPSE" if _language == "en" else "末日"
	return (
		"DIFFICULTY: %s  ·  ENEMY ×%.2f"
		if _language == "en"
		else "难度：%s  ·  敌军 ×%.2f"
	) % [tier, difficulty]


func _on_event_invitation_accepted(event_type: String) -> void:
	_event_invitation = null
	if event_type == "battle":
		_active_battle_difficulty_scale = (
			_pending_battle_difficulty_scale
			if _pending_battle_difficulty_scale >= 0.0
			else _roll_battle_difficulty_scale()
		)
		_pending_battle_difficulty_scale = -1.0
		_start_battle()
	else:
		_start_pilgrimage()


func _on_event_invitation_discarded(event_type: String) -> void:
	_event_invitation = null
	if event_type == "battle":
		_pending_battle_difficulty_scale = -1.0
	_reschedule_declined_event(event_type)
	_publish_news({
		"category": "公告",
		"headline": "The invitation was discarded." if _language == "en" else "事件邀请已被丢弃。"
	}, false, false)


func _on_event_invitation_expired(event_type: String) -> void:
	_event_invitation = null
	if event_type == "battle":
		_pending_battle_difficulty_scale = -1.0
	_reschedule_declined_event(event_type)


func _reschedule_declined_event(event_type: String) -> void:
	var now := _get_now_seconds()
	if event_type == "battle":
		_schedule_next_battle(now)
	else:
		_schedule_next_pilgrimage(now)


func _start_pilgrimage() -> void:
	if _pilgrimage_active or _battle_active or not _has_valid_desktop_pet():
		return
	for believer in _believers:
		if is_instance_valid(believer):
			believer.queue_free()
	_believers.clear()

	_pilgrimage_active = true
	_pilgrimage_ends_at = _get_now_seconds() + PILGRIMAGE_DURATION_SECONDS
	_update_actor_window_bounds()
	_set_pet_autonomy_paused(true)

	var group_count := clampi(
		int(round(float(_pet_window_size.x) / 560.0)),
		PILGRIMAGE_GROUP_MIN,
		PILGRIMAGE_GROUP_MAX
	)
	var group_index := 0
	for group_center in _get_pilgrimage_group_centers(group_count):
		var member_count := _rng.randi_range(PILGRIMAGE_GROUP_MEMBER_MIN, PILGRIMAGE_GROUP_MEMBER_MAX)
		for member_index in member_count:
			var centered_index := float(member_index) - (float(member_count - 1) * 0.5)
			var spawn_x := group_center + (centered_index * PILGRIMAGE_GROUP_SPACING)
			spawn_x += _rng.randf_range(-4.0, 4.0)
			_spawn_pilgrimage_believer(
				spawn_x,
				group_center <= float(_pet_window_size.x) * 0.5,
				float(group_index) * 0.22 + float(member_index) * 0.08
			)
		group_index += 1

	var headline := (
		"PILGRIMAGE: Cultists are pouring in from the desktop edges. Drag a pet to confront them!"
		if _language == "en"
		else "朝圣事件：大批教徒正从桌面边缘涌入，拖动宠物靠近他们！"
	)
	_publish_news({"category": "公告", "headline": headline}, true, false)
	_update_pilgrimage_status(_get_now_seconds())
	_show_pilgrimage_broadcast(
		"PILGRIMAGE" if _language == "en" else "朝圣事件",
		"Drag pets to the cultists before they disperse"
		if _language == "en"
		else "拖动宠物接近教徒，在他们散去前完成遭遇"
	)


func _finish_pilgrimage(resolved_early: bool) -> void:
	if not _pilgrimage_active:
		return
	_pilgrimage_active = false
	_pilgrimage_ends_at = 0.0
	if _pilgrimage_status_label != null:
		_pilgrimage_status_label.visible = false
	for believer in _believers:
		if (
			is_instance_valid(believer)
			and believer.has_method("is_pilgrimage_member")
			and bool(believer.call("is_pilgrimage_member"))
			and believer.has_method("leave_quietly")
		):
			believer.call("leave_quietly")
	_set_pet_autonomy_paused(false)
	_update_actor_window_bounds()
	var now := _get_now_seconds()
	_schedule_next_pilgrimage(now)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)

	var title := (
		"PILGRIMAGE COMPLETE"
		if resolved_early and _language == "en"
		else "PILGRIMAGE ENDED"
		if _language == "en"
		else "朝圣结束"
	)
	var subtitle := (
		"Every group was confronted"
		if resolved_early and _language == "en"
		else "所有教徒小组均已完成遭遇"
		if resolved_early
		else "The remaining cultists dispersed"
		if _language == "en"
		else "剩余教徒已经散去"
	)
	_show_pilgrimage_broadcast(title, subtitle)
	_publish_news({
		"category": "公告",
		"headline": (
			"The pilgrimage ended after every cultist group was confronted."
			if resolved_early and _language == "en"
			else "朝圣结束：所有教徒小组均已完成遭遇。"
			if resolved_early
			else "The pilgrimage ended; the remaining cultists dispersed."
			if _language == "en"
			else "朝圣结束：剩余教徒已经散去。"
		)
	}, false, false)


func _spawn_pilgrimage_believer(
	spawn_x: float,
	spawn_from_left := true,
	entrance_delay := 0.0
) -> void:
	var believer: Node2D = BelieverActor.new()
	var ground_contact_y := float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	believer.call(
		"setup_pilgrim",
		_pet_window_size,
		spawn_x,
		ground_contact_y,
		spawn_from_left,
		entrance_delay
	)
	believer.connect("exited", Callable(self, "_on_believer_exited"))
	believer.connect("scared_away", Callable(self, "_on_believer_scared_away"))
	believer.connect("prayed", Callable(self, "_on_believer_prayed"))
	add_child(believer)
	_believers.append(believer)


func _get_pilgrimage_group_centers(group_count: int) -> Array[float]:
	var centers: Array[float] = []
	var safe_group_count := clampi(group_count, PILGRIMAGE_GROUP_MIN, PILGRIMAGE_GROUP_MAX)
	var window_width := float(_pet_window_size.x)
	var edge_margin := minf(PILGRIMAGE_GROUP_EDGE_MARGIN, window_width * 0.24)
	var min_x := edge_margin
	var max_x := maxf(min_x + 1.0, window_width - edge_margin)
	var candidate_count := maxi(12, safe_group_count * 8)
	var candidates: Array[float] = []
	for candidate_index in candidate_count:
		var weight := (float(candidate_index) + 0.5) / float(candidate_count)
		candidates.append(lerpf(min_x, max_x, weight))
	var distant_candidates: Array[float] = []
	for candidate_x in candidates:
		if _get_nearest_pet_x_distance(candidate_x) >= PILGRIMAGE_PET_CLEARANCE:
			distant_candidates.append(candidate_x)
	if distant_candidates.size() >= safe_group_count:
		candidates = distant_candidates

	for _group_index in safe_group_count:
		var best_index := 0
		var best_score := -1.0
		for candidate_index in candidates.size():
			var candidate_x := candidates[candidate_index]
			var score := _get_nearest_pet_x_distance(candidate_x)
			for selected_x in centers:
				score = minf(score, absf(candidate_x - selected_x) * 0.82)
			score += _rng.randf_range(-3.0, 3.0)
			if score > best_score:
				best_score = score
				best_index = candidate_index
		centers.append(candidates[best_index])
		candidates.remove_at(best_index)
	return centers


func _get_nearest_pet_x_distance(candidate_x: float) -> float:
	var nearest_distance := float(_pet_window_size.x)
	for pet in _pets:
		if is_instance_valid(pet):
			nearest_distance = minf(nearest_distance, absf(candidate_x - pet.position.x))
	return nearest_distance


func _has_valid_desktop_pet() -> bool:
	for pet in _pets:
		if is_instance_valid(pet):
			return true
	return false


func _has_pending_pilgrims() -> bool:
	for believer in _believers:
		if (
			is_instance_valid(believer)
			and believer.has_method("is_pilgrimage_pending")
			and bool(believer.call("is_pilgrimage_pending"))
		):
			return true
	return false


func _get_pending_pilgrim_count() -> int:
	var pending_count := 0
	for believer in _believers:
		if (
			is_instance_valid(believer)
			and believer.has_method("is_pilgrimage_pending")
			and bool(believer.call("is_pilgrimage_pending"))
		):
			pending_count += 1
	return pending_count


func _update_pilgrimage_status(now: float) -> void:
	if _pilgrimage_status_label == null:
		return
	var seconds_left := maxi(0, int(ceil(_pilgrimage_ends_at - now)))
	var pending_count := _get_pending_pilgrim_count()
	_pilgrimage_status_label.text = (
		"PILGRIMAGE  %02d:%02d  ·  %d REMAINING"
		if _language == "en"
		else "朝圣  %02d:%02d  ·  剩余 %d 人"
	) % [int(seconds_left / 60), seconds_left % 60, pending_count]
	_pilgrimage_status_label.visible = _pilgrimage_active


func _set_pet_autonomy_paused(paused: bool) -> void:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_autonomy_paused"):
			pet.call("set_autonomy_paused", paused)


# Battle event
func _start_battle() -> void:
	if _battle_active or _pilgrimage_active or not _has_valid_desktop_pet():
		_active_battle_difficulty_scale = -1.0
		_pending_battle_difficulty_scale = -1.0
		_schedule_next_battle(_get_now_seconds())
		return
	for believer in _believers:
		if is_instance_valid(believer):
			believer.queue_free()
	_believers.clear()

	_battle_active = true
	if _active_battle_difficulty_scale < 0.0:
		_active_battle_difficulty_scale = _roll_battle_difficulty_scale()
	_battle_started_at = _get_now_seconds()
	_battle_ends_at = _battle_started_at + BATTLE_DURATION_SECONDS
	_battle_wave_schedule = EraProgression.get_wave_schedule(_total_runtime_seconds)
	_battle_next_wave_index = 0
	_battle_pet_health.clear()
	_battle_pet_max_health.clear()
	_battle_pet_attack_at.clear()
	_battle_pet_target_x.clear()
	_battle_pet_formed.clear()
	_battle_save_pending = false
	_next_pet11_absorb_at = _battle_started_at + _rng.randf_range(
		PET11_BATTLE_FIRST_ABSORB_MIN_SECONDS,
		PET11_BATTLE_FIRST_ABSORB_MAX_SECONDS
	)
	_update_actor_window_bounds()

	var battle_pets: Array[Node2D] = []
	for pet in _pets:
		if is_instance_valid(pet):
			battle_pets.append(pet)
	for pet_index in battle_pets.size():
		var pet := battle_pets[pet_index]
		var pet_id := _get_actor_pet_id(pet)
		var level := PetProgression.progression_level(_get_pet_state(pet_id))
		var rarity := clampi(int(PetCatalog.get_definition(pet_id).get("rarity_stars", 1)), 1, 5)
		var max_health := 7.0 + float(rarity) * 1.8 + sqrt(float(level)) * 0.42
		var actor_key := str(pet.get_instance_id())
		var formation_weight := (
			0.5
			if battle_pets.size() <= 1
			else float(pet_index) / float(battle_pets.size() - 1)
		)
		_battle_pet_health[actor_key] = max_health
		_battle_pet_max_health[actor_key] = max_health
		_battle_pet_attack_at[actor_key] = _battle_started_at + _rng.randf_range(0.6, 1.2)
		_battle_pet_formed[actor_key] = false
		_battle_pet_target_x[actor_key] = lerpf(
			float(_pet_window_size.x) * 0.70,
			float(_pet_window_size.x) * 0.88,
			formation_weight
		)
		if pet.has_method("set_battle_mode"):
			pet.call("set_battle_mode", true)

	_show_pilgrimage_broadcast(
		"BATTLE EVENT" if _language == "en" else "战斗事件",
		"Enemies are advancing from the left" if _language == "en" else "敌军正从桌面左侧推进"
	)
	_publish_news({
		"category": "公告",
		"headline": (
			"BATTLE: The pets have formed a defensive line on the right side of the desktop."
			if _language == "en"
			else "战斗事件：宠物已在桌面右侧组成防线，敌军正在入场！"
		)
	}, true, false)
	_update_battle(0.0)


func _update_battle(delta: float) -> void:
	if not _battle_active:
		return
	_cleanup_battle_enemies()
	var now := _get_now_seconds()
	var elapsed := maxf(0.0, now - _battle_started_at)
	while _battle_next_wave_index < _battle_wave_schedule.size():
		var wave: Dictionary = _battle_wave_schedule[_battle_next_wave_index]
		if elapsed + 0.001 < float(wave.get("time", 0.0)):
			break
		_spawn_battle_wave(wave, _battle_next_wave_index)
		_battle_next_wave_index += 1

	var alive_pets := _get_alive_battle_pets()
	if alive_pets.is_empty():
		_finish_battle(false)
		return

	for enemy in _battle_enemies:
		if not is_instance_valid(enemy):
			continue
		var target := _get_nearest_battle_pet(enemy, alive_pets)
		if enemy.has_method("set_target"):
			enemy.call("set_target", target)

	for pet in alive_pets:
		var actor_key := str(pet.get_instance_id())
		if pet.has_method("is_pointer_captured") and bool(pet.call("is_pointer_captured")):
			continue
		if not bool(_battle_pet_formed.get(actor_key, false)):
			continue
		if pet.has_method("is_battle_ready") and not bool(pet.call("is_battle_ready")):
			continue
		if _battle_enemies.is_empty():
			continue
		if now < float(_battle_pet_attack_at.get(actor_key, now)):
			continue
		var enemy_target := _get_nearest_battle_enemy(pet)
		if enemy_target == null:
			continue
		var pet_id := _get_actor_pet_id(pet)
		var pet_data := PetCatalog.get_definition(pet_id)
		var rarity := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
		var level := PetProgression.progression_level(_get_pet_state(pet_id))
		var damage := 1.05 + float(rarity) * 0.24 + sqrt(float(level)) * 0.055
		var is_ranged_pet := pet_id in RANGED_BATTLE_PET_IDS
		if not is_ranged_pet and absf(pet.position.x - enemy_target.position.x) > 155.0:
			continue
		var attack_direction := signf(enemy_target.position.x - pet.position.x)
		if pet.has_method("play_battle_attack_toward"):
			pet.call("play_battle_attack_toward", attack_direction)
		elif pet.has_method("play_battle_attack"):
			pet.call("play_battle_attack")
		var knockback := 12.0 + float(rarity) * 1.5
		if is_ranged_pet:
			var visual_power := _get_battle_visual_power(rarity, level)
			_spawn_pet_projectile(pet, pet_id, enemy_target, attack_direction, damage, knockback, visual_power)
		elif enemy_target.has_method("take_damage"):
			var visual_power := _get_battle_visual_power(rarity, level)
			var current_health := float(enemy_target.call("get_health")) if enemy_target.has_method("get_health") else INF
			var launch_defeat := current_health <= damage and _roll_melee_launch(rarity, level)
			if launch_defeat:
				# Invaders always retreat toward the side they entered from, even when the
				# player drags a pet behind their line.
				var launch_direction := _get_enemy_launch_direction()
				var launch_velocity := Vector2(
					launch_direction * (720.0 + visual_power * 58.0),
					-190.0 - visual_power * 16.0
				)
				enemy_target.call("take_damage", damage, knockback, launch_velocity)
				_try_launch_enemy_group(pet, enemy_target, visual_power, launch_direction)
			else:
				enemy_target.call("take_damage", damage, knockback)
		var next_attack_delay := _rng.randf_range(0.95, 1.35)
		if pet.has_method("get_battle_attack_duration"):
			next_attack_delay = maxf(
				next_attack_delay,
				float(pet.call("get_battle_attack_duration")) + 0.05
			)
		_battle_pet_attack_at[actor_key] = now + next_attack_delay

	_update_battle_status(now)
	if _battle_next_wave_index >= _battle_wave_schedule.size() and _battle_enemies.is_empty():
		_finish_battle(true)
	elif now >= _battle_ends_at:
		_finish_battle(true)


func _update_battle_pet_formation(delta: float) -> void:
	if not _battle_active:
		return
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var actor_key := str(pet.get_instance_id())
		if not _battle_pet_health.has(actor_key) or bool(_battle_pet_formed.get(actor_key, false)):
			continue
		if pet.has_method("is_pointer_captured") and bool(pet.call("is_pointer_captured")):
			continue
		var target_x := float(_battle_pet_target_x.get(actor_key, float(_pet_window_size.x) * 0.78))
		var reached_formation := true
		if pet.has_method("battle_move_toward"):
			reached_formation = bool(pet.call("battle_move_toward", target_x, delta, 235.0))
		if reached_formation:
			_battle_pet_formed[actor_key] = true


func _spawn_battle_wave(wave: Dictionary, wave_index: int) -> void:
	var enemy_types: Array = wave.get("types", [])
	for enemy_index in enemy_types.size():
		var enemy_id := String(enemy_types[enemy_index])
		var spawn_position := Vector2(
			-82.0 - float(enemy_index) * 52.0,
			float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
		)
		var enemy: Node2D = EnemyActor.new()
		enemy.set_meta("battle_runtime", true)
		var era_scale := _get_battle_difficulty_scale()
		var wave_scale := 1.0 + float(wave_index) * 0.025
		var entry_x := (
			clampf(float(_pet_window_size.x) * 0.17 + float(enemy_index) * 32.0, 110.0, float(_pet_window_size.x) * 0.30)
			if enemy_id in ["soldier2", "victorian1"]
			else clampf(float(_pet_window_size.x) * 0.065 + float(enemy_index) * 18.0, 72.0, 150.0)
		)
		enemy.call(
			"setup",
			enemy_id,
			spawn_position,
			float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
			era_scale * wave_scale,
			entry_x
		)
		enemy.connect("attack_landed", Callable(self, "_on_enemy_attack_landed"))
		enemy.connect("projectile_requested", Callable(self, "_on_enemy_projectile_requested"))
		enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))
		enemy.connect("swallowed", Callable(self, "_on_enemy_swallowed"))
		add_child(enemy)
		_battle_enemies.append(enemy)


func _on_enemy_projectile_requested(
	enemy: Node2D,
	target: Node2D,
	damage: float,
	projectile_kind: String,
	power_scale: float
) -> void:
	if not _battle_active or enemy == null or not is_instance_valid(enemy):
		return
	if target == null or not is_instance_valid(target):
		return
	var start_position := enemy.position + Vector2(38.0, -68.0)
	if enemy.has_method("get_projectile_origin"):
		start_position = enemy.call("get_projectile_origin")
	var projectile: Node2D = EnemyProjectileActor.new()
	projectile.set_meta("battle_runtime", true)
	projectile.call("setup", projectile_kind, start_position, target, damage, power_scale)
	projectile.connect("impacted", Callable(self, "_on_enemy_projectile_impacted"))
	projectile.tree_exited.connect(_on_battle_effect_tree_exited.bind(projectile))
	add_child(projectile)
	_battle_effects.append(projectile)


func _on_enemy_projectile_impacted(
	_projectile: Node2D,
	target: Node2D,
	damage: float,
	splash_radius: float,
	knockback: float
) -> void:
	if not _battle_active or target == null or not is_instance_valid(target):
		return
	var impact_position := target.position + Vector2(0.0, -48.0)
	if target.has_method("get_battle_hit_position"):
		impact_position = target.call("get_battle_hit_position")
	if splash_radius <= 0.0:
		_damage_battle_pet(target, damage, knockback)
		return
	_spawn_battle_explosion(impact_position, clampf(splash_radius / 32.0, 3.0, 7.5))
	for pet in _get_alive_battle_pets():
		var hit_position := pet.position + Vector2(0.0, -48.0)
		if pet.has_method("get_battle_hit_position"):
			hit_position = pet.call("get_battle_hit_position")
		var distance := hit_position.distance_to(impact_position)
		if distance > splash_radius:
			continue
		var falloff := lerpf(1.0, 0.45, distance / maxf(1.0, splash_radius))
		_damage_battle_pet(pet, damage * falloff, knockback * falloff)


func _get_battle_visual_power(rarity: int, level: int) -> float:
	return clampf(float(rarity) + log(float(maxi(1, level))) / log(10.0) * 0.72, 1.0, 7.5)


func _roll_melee_launch(rarity: int, level: int) -> bool:
	var chance := clampf(
		0.07 + float(rarity) * 0.035 + log(float(maxi(1, level))) / log(10.0) * 0.045,
		0.10,
		0.42
	)
	return _rng.randf() < chance


static func _get_enemy_launch_direction() -> float:
	return -1.0


func _try_launch_enemy_group(
	_attacker: Node2D,
	primary: Node2D,
	visual_power: float,
	launch_direction: float
) -> void:
	if visual_power < 4.7 or _rng.randf() > clampf(0.20 + (visual_power - 4.7) * 0.12, 0.20, 0.58):
		return
	var remaining := clampi(1 + int(floor((visual_power - 4.7) * 0.72)), 1, 3)
	for enemy in _battle_enemies.duplicate():
		if remaining <= 0:
			break
		if not is_instance_valid(enemy) or enemy == primary:
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		if enemy.position.distance_to(primary.position) > 185.0:
			continue
		if not enemy.has_method("launch_offscreen"):
			continue
		var vertical_variation := _rng.randf_range(-245.0, -150.0)
		enemy.call(
			"launch_offscreen",
			Vector2(launch_direction * (680.0 + visual_power * 52.0), vertical_variation)
		)
		remaining -= 1


func _spawn_pet_projectile(
	pet: Node2D,
	pet_id: String,
	target: Node2D,
	direction: float,
	damage: float,
	knockback: float,
	visual_power: float
) -> void:
	if target == null or not is_instance_valid(target):
		return
	var start_position := pet.position + Vector2((-1.0 if direction < 0.0 else 1.0) * 42.0, -46.0)
	if pet.has_method("get_battle_attack_origin"):
		start_position = pet.call("get_battle_attack_origin", direction)
	var effect: Node2D = BattleEffectActor.new()
	effect.set_meta("battle_runtime", true)
	effect.call("setup_projectile", pet_id, start_position, target, visual_power)
	effect.connect(
		"projectile_impacted",
		Callable(self, "_on_pet_projectile_impacted").bind(damage, knockback, visual_power)
	)
	effect.tree_exited.connect(_on_battle_effect_tree_exited.bind(effect))
	add_child(effect)
	_battle_effects.append(effect)


func _on_pet_projectile_impacted(
	_effect: Node2D,
	target: Node2D,
	damage: float,
	knockback: float,
	visual_power: float
) -> void:
	if not _battle_active or target == null or not is_instance_valid(target):
		return
	var impact_position := target.position + Vector2(0.0, -52.0)
	if target.has_method("get_battle_hit_position"):
		impact_position = target.call("get_battle_hit_position")
	_spawn_battle_explosion(impact_position, visual_power)
	if target.has_method("take_damage"):
		target.call("take_damage", damage, knockback)


func _spawn_battle_explosion(world_position: Vector2, visual_power: float) -> void:
	var effect: Node2D = BattleEffectActor.new()
	effect.set_meta("battle_runtime", true)
	effect.call("setup_explosion", world_position, visual_power)
	effect.tree_exited.connect(_on_battle_effect_tree_exited.bind(effect))
	add_child(effect)
	_battle_effects.append(effect)


func _on_battle_effect_tree_exited(effect: Node2D) -> void:
	_battle_effects.erase(effect)


func _cleanup_battle_enemies() -> void:
	for index in range(_battle_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_battle_enemies[index]) or _battle_enemies[index].is_queued_for_deletion():
			_battle_enemies.remove_at(index)


func _get_alive_battle_pets() -> Array[Node2D]:
	var alive: Array[Node2D] = []
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _battle_pet_health.has(str(pet.get_instance_id())):
			alive.append(pet)
	return alive


func _get_nearest_battle_pet(enemy: Node2D, candidates: Array[Node2D]) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for pet in candidates:
		var distance := absf(pet.position.x - enemy.position.x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = pet
	return nearest


func _get_nearest_battle_enemy(pet: Node2D) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for enemy in _battle_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		var distance := absf(pet.position.x - enemy.position.x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _on_enemy_attack_landed(_enemy: Node2D, target: Node2D, damage: float) -> void:
	_damage_battle_pet(target, damage, 13.0)


func _damage_battle_pet(target: Node2D, damage: float, knockback: float) -> void:
	if not _battle_active or target == null or not is_instance_valid(target):
		return
	var actor_key := str(target.get_instance_id())
	if not _battle_pet_health.has(actor_key):
		return
	var next_health := float(_battle_pet_health[actor_key]) - maxf(0.0, damage)
	_battle_pet_health[actor_key] = next_health
	if target.has_method("receive_battle_hit"):
		target.call("receive_battle_hit", maxf(0.0, knockback))
	if next_health <= 0.0:
		_defeat_battle_pet(target)


func _on_enemy_defeated(enemy: Node2D, reward_count: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var defeat_position := enemy.position + Vector2(0.0, -62.0)
	_battle_enemies.erase(enemy)
	_spawn_battle_reward(defeat_position, reward_count)
	if enemy.has_method("is_launched") and bool(enemy.call("is_launched")):
		return
	_spawn_smoke_effect(defeat_position)
	enemy.queue_free()


func _on_enemy_swallowed(enemy: Node2D, reward_count: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var reward_position := enemy.position + Vector2(0.0, -18.0)
	_battle_enemies.erase(enemy)
	_spawn_battle_reward(reward_position, reward_count)
	enemy.queue_free()


func _spawn_battle_reward(drop_position: Vector2, reward_count: int) -> void:
	var safe_count := clampi(reward_count, 3, 24)
	for coin_index in safe_count:
		var coin_type := "D" if coin_index < 2 else "P" if coin_index % 3 == 0 else "R"
		var spread := float(coin_index) - float(safe_count - 1) * 0.5
		_spawn_coin(coin_type, drop_position + Vector2(
			spread * 12.0 + _rng.randf_range(-9.0, 9.0),
			_rng.randf_range(-18.0, 12.0)
		))


func _defeat_battle_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id := _get_actor_pet_id(actor)
	var actor_key := str(actor.get_instance_id())
	_battle_pet_health.erase(actor_key)
	_battle_pet_max_health.erase(actor_key)
	_battle_pet_attack_at.erase(actor_key)
	_battle_pet_target_x.erase(actor_key)
	_battle_pet_formed.erase(actor_key)
	_spawn_smoke_effect(actor.position + Vector2(0.0, -58.0))
	if actor.has_method("hide_for_battle_defeat"):
		actor.call("hide_for_battle_defeat")
	_set_pet_recovery(pet_id)
	_deployed_pet_ids.erase(pet_id)
	_pets.erase(actor)
	_next_pet_coin_drop_at.erase(actor_key)
	_pet_coin_drop_intervals.erase(actor_key)
	_clear_pet_runtime_effects(pet_id)
	_battle_save_pending = true
	if _hovered_pet == actor:
		_hovered_pet = null
	if _selected_pet_id == pet_id:
		_selected_pet_id = _get_first_desktop_pet_id()
	actor.queue_free()
	_pet_upgrade_stats_dirty = true


func _set_pet_recovery(pet_id: String) -> void:
	if pet_id.is_empty():
		return
	var state := _get_pet_state(pet_id)
	var rarity := clampi(int(PetCatalog.get_definition(pet_id).get("rarity_stars", 1)), 1, 5)
	var duration := clampf(
		BATTLE_PET_RECOVERY_MIN_SECONDS + float(rarity - 1) * 18.0,
		BATTLE_PET_RECOVERY_MIN_SECONDS,
		BATTLE_PET_RECOVERY_MAX_SECONDS
	)
	var now := _get_now_seconds()
	state["recovery_started_at"] = now
	state["recover_until"] = now + duration
	state["recovery_duration"] = duration
	_pet_states[pet_id] = state


func _finish_battle(victory: bool) -> void:
	if not _battle_active:
		return
	_battle_active = false
	_battle_started_at = 0.0
	_battle_ends_at = 0.0
	if _pilgrimage_status_label != null:
		_pilgrimage_status_label.visible = false
	for enemy in _battle_enemies:
		if is_instance_valid(enemy):
			_spawn_smoke_effect(enemy.position + Vector2(0.0, -62.0))
			enemy.queue_free()
	_battle_enemies.clear()
	for effect in _battle_effects.duplicate():
		if is_instance_valid(effect):
			effect.queue_free()
	_battle_effects.clear()
	_clear_battle_runtime_nodes()
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_battle_mode"):
			pet.call("set_battle_mode", false)
	_battle_pet_health.clear()
	_battle_pet_max_health.clear()
	_battle_pet_attack_at.clear()
	_battle_pet_target_x.clear()
	_battle_pet_formed.clear()
	_battle_wave_schedule.clear()
	_active_battle_difficulty_scale = -1.0
	_schedule_next_pet11_absorb(_get_now_seconds(), true)
	_update_actor_window_bounds()
	var now := _get_now_seconds()
	_schedule_next_battle(now)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)
	var title := "BATTLE WON" if victory and _language == "en" else "BATTLE ENDED" if _language == "en" else "战斗胜利" if victory else "防线失守"
	var subtitle := "The desktop is safe again" if victory and _language == "en" else "Surviving pets have left the field" if _language == "en" else "桌面重新恢复平静" if victory else "受伤宠物已返回仓库休整"
	_show_pilgrimage_broadcast(title, subtitle)
	_publish_news({
		"category": "公告",
		"headline": (
			"The battle ended. Defeated pets are recovering in storage."
			if _language == "en"
			else "战斗结束。被击倒的宠物已返回仓库休整。"
		)
	}, true, false)
	_sync_inventory_window()
	_refresh_pet_stats(true)
	if _battle_save_pending:
		_save_game()
	_battle_save_pending = false


func _clear_battle_runtime_nodes() -> void:
	for child in get_children():
		if is_instance_valid(child) and bool(child.get_meta("battle_runtime", false)):
			child.queue_free()


func _update_battle_status(now: float) -> void:
	if _pilgrimage_status_label == null:
		return
	var seconds_left := maxi(0, int(ceil(_battle_ends_at - now)))
	_pilgrimage_status_label.text = (
		"BATTLE  %02d:%02d  ·  %d ENEMIES"
		if _language == "en"
		else "战斗  %02d:%02d  ·  敌人 %d"
	) % [int(seconds_left / 60), seconds_left % 60, _battle_enemies.size()]
	_pilgrimage_status_label.visible = _battle_active


func _spawn_smoke_effect(effect_position: Vector2) -> void:
	var frames := _get_smoke_frames()
	if frames == null:
		return
	var smoke := AnimatedSprite2D.new()
	smoke.sprite_frames = frames
	smoke.position = effect_position
	smoke.scale = Vector2.ONE * 1.35
	smoke.z_index = 350
	add_child(smoke)
	smoke.animation_finished.connect(smoke.queue_free)
	smoke.play("smoke")


func _get_smoke_frames() -> SpriteFrames:
	if _smoke_frames != null:
		return _smoke_frames
	var sheet := load(SMOKE_SHEET_TEXTURE) as Texture2D
	if sheet == null:
		return null
	_smoke_frames = SpriteFrames.new()
	_smoke_frames.remove_animation("default")
	_smoke_frames.add_animation("smoke")
	_smoke_frames.set_animation_loop("smoke", false)
	_smoke_frames.set_animation_speed("smoke", 14.0)
	var frame_width := float(sheet.get_width()) / float(SMOKE_FRAME_COUNT)
	for frame_index in SMOKE_FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame_width * frame_index, 0.0, frame_width, float(sheet.get_height()))
		_smoke_frames.add_frame("smoke", atlas)
	return _smoke_frames


func _refresh_era_display(force := false) -> void:
	if _side_drawer == null or not _side_drawer.has_method("refresh_era"):
		return
	var display_text := EraProgression.get_display_text(_total_runtime_seconds, _language)
	if force or display_text != _last_era_display:
		var calendar_changed := display_text != _last_era_display
		_last_era_display = display_text
		_side_drawer.call("refresh_era", display_text)
		if calendar_changed:
			_pet_upgrade_stats_dirty = true
			_refresh_pet_stats(true)
			if _inventory_window != null and _inventory_window.visible:
				_sync_inventory_window()


func _schedule_next_pet11_absorb(now: float, initial := false) -> void:
	var delay_min := PET11_ABSORB_INITIAL_MIN_SECONDS if initial else PET11_ABSORB_COOLDOWN_MIN_SECONDS
	var delay_max := PET11_ABSORB_INITIAL_MAX_SECONDS if initial else PET11_ABSORB_COOLDOWN_MAX_SECONDS
	_next_pet11_absorb_at = now + _rng.randf_range(delay_min, delay_max)


func _update_pet11_absorb_ability() -> void:
	if _pilgrimage_active:
		return
	var pet11: Node2D
	for pet in _pets:
		if is_instance_valid(pet) and _get_actor_pet_id(pet) == "pet11":
			pet11 = pet
			break
	if pet11 == null:
		_next_pet11_absorb_at = 0.0
		return
	if pet11.has_method("is_pointer_captured") and bool(pet11.call("is_pointer_captured")):
		return
	if _battle_active:
		_update_pet11_battle_absorb(pet11)
		return
	if _has_swallowed_pet():
		return
	var now := _get_now_seconds()
	if _next_pet11_absorb_at <= 0.0:
		_schedule_next_pet11_absorb(now, true)
		return
	if now < _next_pet11_absorb_at:
		return

	var candidates: Array[Node2D] = []
	for pet in _pets:
		if not is_instance_valid(pet) or pet == pet11:
			continue
		if pet.has_method("can_be_swallowed") and bool(pet.call("can_be_swallowed")):
			candidates.append(pet)
	if candidates.is_empty():
		_next_pet11_absorb_at = now + 20.0
		return
	var target := candidates[_rng.randi_range(0, candidates.size() - 1)]
	var started := bool(target.call(
		"start_swallowed_by",
		pet11,
		_rng.randf_range(PET11_ABSORB_HOLD_MIN_SECONDS, PET11_ABSORB_HOLD_MAX_SECONDS)
	))
	if started:
		_spawn_emotion(pet11, "suprised", Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
	_schedule_next_pet11_absorb(now)


func _update_pet11_battle_absorb(pet11: Node2D) -> void:
	var actor_key := str(pet11.get_instance_id())
	if not _battle_pet_health.has(actor_key):
		return
	var now := _get_now_seconds()
	if now < _next_pet11_absorb_at:
		return
	var target: Node2D
	var nearest_distance := INF
	# Enemies are the signature target. Range is intentionally the whole desktop so
	# pet11 does not silently fail while it is holding the right-side battle line.
	for enemy in _battle_enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("can_be_swallowed"):
			continue
		if not bool(enemy.call("can_be_swallowed")):
			continue
		var distance := pet11.position.distance_to(enemy.position)
		if distance < nearest_distance:
			nearest_distance = distance
			target = enemy
	if target == null:
		for effect in _battle_effects:
			if not is_instance_valid(effect) or not effect.has_method("can_be_swallowed"):
				continue
			if not bool(effect.call("can_be_swallowed")):
				continue
			var distance := pet11.position.distance_to(effect.position)
			if distance < nearest_distance:
				nearest_distance = distance
				target = effect
	if target == null:
		_next_pet11_absorb_at = now + 0.75
		return
	if bool(target.call("start_swallowed_by", pet11)):
		if pet11.has_method("play_battle_attack_toward"):
			pet11.call("play_battle_attack_toward", signf(target.position.x - pet11.position.x))
		_spawn_emotion(pet11, "suprised", Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
	_next_pet11_absorb_at = now + _rng.randf_range(
		PET11_BATTLE_ABSORB_MIN_SECONDS,
		PET11_BATTLE_ABSORB_MAX_SECONDS
	)


func _has_swallowed_pet() -> bool:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("is_swallowed") and bool(pet.call("is_swallowed")):
			return true
	return false


# Coin drops
func _schedule_next_ambient_coin_drop(now: float) -> void:
	for pet in _pets:
		if is_instance_valid(pet):
			_schedule_pet_coin_drop(pet, now)


func _schedule_pet_coin_drop(actor: Node2D, now: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	var level := PetProgression.progression_level(_get_pet_state(pet_id))
	var current_rate := _get_pet_money_value_per_minute(pet_id, level)
	var base_rate := maxf(0.01, _get_pet_money_value_per_minute(pet_id, 1))
	var speed_scale := sqrt(maxf(1.0, current_rate / base_rate))
	var interval_min := clampf(34.0 / speed_scale, PET_AUTO_COIN_INTERVAL_MIN, 40.0)
	var interval_max := clampf(52.0 / speed_scale, interval_min + 4.0, PET_AUTO_COIN_INTERVAL_MAX)
	var interval := _rng.randf_range(interval_min, interval_max)
	var actor_key := str(actor.get_instance_id())
	_next_pet_coin_drop_at[actor_key] = now + interval
	_pet_coin_drop_intervals[actor_key] = interval


func _update_ambient_coin_drops() -> void:
	var now := _get_now_seconds()
	var active_keys := {}
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var actor_key := str(pet.get_instance_id())
		active_keys[actor_key] = true
		if not _next_pet_coin_drop_at.has(actor_key):
			_schedule_pet_coin_drop(pet, now)
			continue
		if now < float(_next_pet_coin_drop_at.get(actor_key, now)):
			continue
		var interval := float(_pet_coin_drop_intervals.get(actor_key, 40.0))
		_schedule_pet_coin_drop(pet, now)
		if _pilgrimage_active or _battle_active:
			continue
		if pet.has_method("is_swallowed") and bool(pet.call("is_swallowed")):
			continue
		_spawn_pet_coin_pile(pet, interval)
	for actor_key_value in _next_pet_coin_drop_at.keys().duplicate():
		var actor_key := String(actor_key_value)
		if active_keys.has(actor_key):
			continue
		_next_pet_coin_drop_at.erase(actor_key)
		_pet_coin_drop_intervals.erase(actor_key)


func _spawn_pet_coin_pile(actor: Node2D, interval_seconds: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	var level := PetProgression.progression_level(_get_pet_state(pet_id))
	var rate_per_minute := _get_pet_money_value_per_minute(pet_id, level)
	var target_value := maxf(
		float(PET_AUTO_COIN_PILE_MIN),
		rate_per_minute * maxf(1.0, interval_seconds) / 60.0
	)
	var pile_count := clampi(
		int(ceil(target_value / 8.0)),
		PET_AUTO_COIN_PILE_MIN,
		PET_AUTO_COIN_PILE_MAX
	)
	var drop_anchor := actor.position + Vector2(0.0, -64.0)
	if actor.has_method("get_emotion_anchor"):
		drop_anchor = actor.call("get_emotion_anchor")
	var remaining_value := target_value
	var crystal_budget := maxf(0.0, target_value - float(maxi(0, pile_count - 1)))
	var crystal_type := _choose_crystal_drop_type(
		PetCatalog.get_definition(pet_id),
		level,
		crystal_budget
	)
	for coin_index in pile_count:
		var slots_left := pile_count - coin_index
		var average_value := remaining_value / float(maxi(1, slots_left))
		var coin_type := "R"
		if coin_index == 0 and not crystal_type.is_empty():
			coin_type = crystal_type
		elif average_value >= 24.0:
			coin_type = "D"
		elif average_value >= 3.0:
			coin_type = "P"
		remaining_value = maxf(0.0, remaining_value - float(CoinDrop.get_coin_value(coin_type)))
		var spread_weight := float(coin_index) - float(pile_count - 1) * 0.5
		_spawn_coin(coin_type, drop_anchor + Vector2(
			spread_weight * 13.0 + _rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-14.0, 10.0)
		))


static func _choose_crystal_drop_type(
	pet_data: Dictionary,
	level: int,
	available_value: float
) -> String:
	var rarity := clampi(int(pet_data.get("rarity_stars", 1)), 1, 5)
	var progression_score := maxi(1, level) + int(CRYSTAL_RARITY_BONUSES.get(rarity, 0))
	for crystal_type in ["G", "S", "C"]:
		if progression_score < int(CRYSTAL_UNLOCK_SCORES[crystal_type]):
			continue
		if available_value + 0.001 >= float(CoinDrop.get_coin_value(crystal_type)):
			return crystal_type
	return ""


func _update_coin_drops() -> void:
	for index in range(_coin_drops.size() - 1, -1, -1):
		if not is_instance_valid(_coin_drops[index]) or _coin_drops[index].is_queued_for_deletion():
			_coin_drops.remove_at(index)


func _spawn_pet_coin(actor: Node2D) -> Node2D:
	if actor == null or not is_instance_valid(actor):
		return null
	var coin_type := "P" if _rng.randf() < PET_P_COIN_CHANCE else "R"
	var spawn_position := actor.position + Vector2(0.0, -72.0)
	if actor.has_method("get_emotion_anchor"):
		spawn_position = actor.call("get_emotion_anchor")
	return _spawn_coin(coin_type, spawn_position)


func _spawn_coin(coin_type: String, spawn_position: Vector2) -> Node2D:
	_make_desktop_coin_capacity(1)
	var coin: Node2D = CoinDrop.new()
	coin.setup(
		coin_type,
		spawn_position,
		_pet_window_size,
		float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	)
	coin.collected.connect(_on_coin_collected)
	add_child(coin)
	_coin_drops.append(coin)
	return coin


func _make_desktop_coin_capacity(incoming_count: int) -> void:
	_update_coin_drops()
	var required_slots := maxi(0, incoming_count)
	while _coin_drops.size() + required_slots > DESKTOP_COIN_LIMIT:
		var oldest_coin := _coin_drops.pop_front() as Node2D
		if oldest_coin == null or not is_instance_valid(oldest_coin):
			continue
		if oldest_coin.has_method("expire"):
			oldest_coin.call("expire")
		else:
			oldest_coin.queue_free()


func _on_coin_collected(actor: Node2D, coin_type: String, value: int) -> void:
	var popup_position := actor.position if actor != null and is_instance_valid(actor) else _get_window_mouse_position(get_window())
	if actor != null:
		_coin_drops.erase(actor)
	var safe_value := maxi(0, value)
	if safe_value <= 0:
		return
	_gold_coins += safe_value
	_refresh_coin_display()
	_show_coin_change_popup(popup_position, safe_value, coin_type)


func _on_believer_scared_away(_actor: Node2D, _drop_position: Vector2) -> void:
	# Flight is the no-reward outcome. Only a completed prayer creates coins.
	pass


func _on_believer_prayed(_actor: Node2D, drop_position: Vector2, coin_count: int) -> void:
	var safe_count := clampi(coin_count, 1, BelieverActor.PILGRIMAGE_PRAY_COIN_MAX)
	for coin_index in safe_count:
		var spread_weight := float(coin_index) - (float(safe_count - 1) * 0.5)
		var coin_position := drop_position + Vector2(
			spread_weight * 11.0 + _rng.randf_range(-7.0, 7.0),
			_rng.randf_range(-12.0, 8.0)
		)
		_spawn_coin("D", coin_position)


# UI windows
func _create_news_broadcast() -> void:
	var layer := CanvasLayer.new()
	layer.name = "NewsBroadcastLayer"
	layer.layer = 400
	add_child(layer)

	var top_center := CenterContainer.new()
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

	var margin := MarginContainer.new()
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
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"PingFang SC",
		"Noto Sans CJK SC",
		"Noto Sans SC"
	])
	font.font_weight = 600
	_news_broadcast_label.add_theme_font_override("font", font)
	margin.add_child(_news_broadcast_label)


func _make_news_broadcast_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.043, 0.034, 0.36)
	style.border_color = Color(0.46, 0.70, 0.42, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	return style


func _create_pilgrimage_broadcast() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PilgrimageBroadcastLayer"
	layer.layer = 450
	add_child(layer)

	var top_center := CenterContainer.new()
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.035, 0.028, 0.94)
	style.border_color = Color(0.76, 0.84, 0.38, 0.94)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 12
	_pilgrimage_broadcast_panel.add_theme_stylebox_override("panel", style)
	top_center.add_child(_pilgrimage_broadcast_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pilgrimage_broadcast_panel.add_child(margin)

	var text_stack := VBoxContainer.new()
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 2)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(text_stack)

	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"PingFang SC",
		"Noto Sans CJK SC",
		"Noto Sans SC"
	])
	font.font_weight = 800

	var status_anchor := CenterContainer.new()
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


func _show_pilgrimage_broadcast(title_text: String, subtitle_text: String) -> void:
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
	_side_drawer.quit_requested.connect(_on_quit_requested)
	_side_drawer.pet_upgrade_requested.connect(_on_pet_upgrade_requested)
	_side_drawer.pet_rename_requested.connect(_on_pet_detail_rename_requested)
	_side_drawer.faith_add_requested.connect(_on_faith_add_requested)
	_side_drawer.menu_handle_moved.connect(_on_menu_handle_moved)
	if _loaded_menu_handle_anchor >= 0.0:
		_side_drawer.set_menu_handle_anchor(_loaded_menu_handle_anchor)
	_side_drawer.setup()
	if not _carried_offering.is_empty():
		_set_offering_cursor(String(_carried_offering.get("texture", "")))
		_update_offering_input_window()


func _create_inventory_window() -> void:
	_inventory_window = InventoryWindowScript.new()
	_inventory_window.visible = false
	add_child(_inventory_window)
	_inventory_window.connect("pet_deploy_requested", Callable(self, "_on_inventory_pet_deploy_requested"))
	_inventory_window.connect("pet_rename_requested", Callable(self, "_on_inventory_pet_rename_requested"))
	_inventory_window.setup(_get_inventory_pet_entries())


func _sync_inventory_window() -> void:
	if _inventory_window != null and _inventory_window.has_method("set_pets"):
		_inventory_window.call(
			"set_pets",
			_get_inventory_pet_entries(),
			_inventory_window.visible
		)


func _create_shop_window() -> void:
	_shop_window = ShopWindowScript.new()
	_shop_window.visible = false
	add_child(_shop_window)
	_shop_window.connect("purchase_requested", Callable(self, "_on_shop_purchase_requested"))
	_shop_window.call("setup")
	_sync_shop_state()


func _create_gacha_window() -> void:
	_gacha_window = GachaWindowScript.new()
	_gacha_window.visible = false
	add_child(_gacha_window)
	_gacha_window.draw_requested.connect(_on_gacha_draw_requested)
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
	_settings_window.activity_range_changed.connect(_on_activity_range_changed)
	_settings_window.language_changed.connect(_on_language_changed)
	_settings_window.debug_economy_requested.connect(_on_debug_economy_requested)
	_settings_window.debug_simulation_requested.connect(_on_debug_simulation_requested)
	_settings_window.debug_event_requested.connect(_on_debug_event_requested)
	_settings_window.quit_requested.connect(_on_quit_requested)
	_settings_window.setup(_pet_activity_range, _language)
	_settings_window.refresh_runtime(_session_runtime_seconds, _total_runtime_seconds)
	_settings_window.refresh_debug_values(_faith_points, _gold_coins, _debug_enemy_power_scale, _debug_game_speed)


# Window clickthrough and hit testing
func _place_pet_window() -> void:
	var usable_rect := _get_current_screen_usable_rect()
	var window := get_window()
	var target_size := _get_target_pet_window_size(usable_rect)
	var target_x: int = usable_rect.position.x
	var target_y: int = usable_rect.position.y
	var target_position := Vector2i(target_x, target_y)
	var bounds_changed := window.size != target_size or window.position != target_position
	_pet_window_size = target_size
	if window.size != target_size:
		window.size = target_size
	if window.position != target_position:
		window.position = target_position
	if bounds_changed:
		_update_actor_window_bounds()
		_update_offering_input_window()


func _get_target_pet_window_size(usable_rect: Rect2i) -> Vector2i:
	return Vector2i(
		maxi(PET_WINDOW_BASE_SIZE.x, usable_rect.size.x),
		maxi(PET_WINDOW_BASE_SIZE.y, usable_rect.size.y + PET_TASKBAR_OVERLAP_PIXELS)
	)


func _update_actor_window_bounds() -> void:
	var min_x := _get_pet_stage_min_x()
	var max_x := _get_pet_stage_max_x()
	var restrict_activity := _get_effective_pet_activity_range() != "full"
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_window_bounds"):
			pet.call(
				"set_window_bounds",
				_pet_window_size,
				min_x,
				max_x,
				float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS),
				restrict_activity
			)

	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_window_size"):
			believer.call(
				"set_window_size",
				_pet_window_size,
				float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
			)

	for coin in _coin_drops:
		if is_instance_valid(coin) and coin.has_method("set_window_bounds"):
			coin.call(
				"set_window_bounds",
				_pet_window_size,
				float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
			)

	if _event_invitation != null and is_instance_valid(_event_invitation) and _event_invitation.has_method("set_window_bounds"):
		_event_invitation.call(
			"set_window_bounds",
			_pet_window_size,
			float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
		)


func _update_pet_hover() -> void:
	if _has_captured_pet_pointer():
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_cancel_all_pet_pointer_captures()
		return

	var mouse_position := _get_window_mouse_position(get_window())
	var hit_pet := _get_pet_at_position(mouse_position)
	_set_hovered_pet(hit_pet)


func _set_hovered_pet(next_pet: Node2D) -> void:
	if _hovered_pet == next_pet:
		return
	var previous_pet := _hovered_pet
	_hovered_pet = next_pet
	if previous_pet != null and is_instance_valid(previous_pet) and previous_pet.has_method("set_pointer_hovered"):
		previous_pet.call("set_pointer_hovered", false)
	if _hovered_pet != null and is_instance_valid(_hovered_pet) and _hovered_pet.has_method("set_pointer_hovered"):
		_hovered_pet.call("set_pointer_hovered", true)


func _cancel_all_pet_pointer_captures() -> void:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("cancel_pointer_capture"):
			pet.call("cancel_pointer_capture")


func _restore_desktop_input() -> void:
	if not is_inside_tree():
		return
	_set_hovered_pet(null)


func _is_offering_drop_zone(window_position: Vector2) -> bool:
	var usable_bottom := float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	return (
		window_position.x >= 0.0
		and window_position.x <= float(_pet_window_size.x)
		and window_position.y >= 0.0
		and window_position.y <= usable_bottom
	)


func _has_captured_pet_pointer() -> bool:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("is_pointer_captured"):
			if bool(pet.call("is_pointer_captured")):
				return true
	return false


func _get_pet_at_position(window_position: Vector2) -> Node2D:
	for index in range(_pets.size() - 1, -1, -1):
		var pet := _pets[index]
		if not is_instance_valid(pet):
			continue

		var rect := _get_pet_input_rect(pet)
		if rect.has_point(window_position) and _is_pet_pixel_hit(pet, window_position):
			return pet

	return null


func _get_pet_input_rect(pet: Node2D) -> Rect2:
	if pet.has_method("get_interaction_rect"):
		return pet.call("get_interaction_rect")
	if pet.has_method("get_draw_rect"):
		return pet.call("get_draw_rect")
	return Rect2()


func _is_pet_pixel_hit(pet: Node2D, window_position: Vector2) -> bool:
	if pet.has_method("is_point_over_opaque_pixel"):
		return bool(pet.call("is_point_over_opaque_pixel", window_position))
	return true


func _get_window_mouse_position(window: Window) -> Vector2:
	if window == null:
		return Vector2(_pet_window_size) * 0.5
	var global_mouse := DisplayServer.mouse_get_position()
	var window_position := window.position
	return Vector2(global_mouse.x - window_position.x, global_mouse.y - window_position.y)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_save_game()
	_clear_offering_cursor()


# Petting, cursors, and emotion effects
func _update_offering_cursor_state() -> void:
	if not _carried_offering.is_empty():
		_refresh_offering_cursor()
		return


func _create_offering_input_window() -> void:
	_offering_input_window = Window.new()
	_offering_input_window.name = "OfferingInputWindow"
	_offering_input_window.title = "Cthulu Offering Input"
	_offering_input_window.borderless = true
	_offering_input_window.transparent = true
	_offering_input_window.transparent_bg = true
	_offering_input_window.unfocusable = true
	_offering_input_window.unresizable = true
	_offering_input_window.always_on_top = false
	_offering_input_window.min_size = Vector2i.ZERO
	_offering_input_window.size = Vector2i(
		_pet_window_size.x,
		_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS
	)
	_offering_input_window.visible = false
	add_child(_offering_input_window)

	_offering_input_area = Control.new()
	_offering_input_area.name = "OfferingDropArea"
	_offering_input_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offering_input_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_offering_input_area.gui_input.connect(_on_offering_input)
	_offering_input_window.add_child(_offering_input_area)
	_update_offering_input_window()


func _update_offering_input_window() -> void:
	if _offering_input_window == null:
		return
	if _carried_offering.is_empty():
		if _offering_input_window.visible:
			_offering_input_window.visible = false
		return
	var usable_bottom := _pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS
	var target_position := get_window().position
	var target_size := Vector2i(_pet_window_size.x, usable_bottom)
	if _offering_input_window.position != target_position:
		_offering_input_window.position = target_position
	if _offering_input_window.size != target_size:
		_offering_input_window.size = target_size
	_offering_input_window.visible = true


func _on_offering_input(event: InputEvent) -> void:
	if _carried_offering.is_empty() or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_drop_carried_offering(_get_window_mouse_position(get_window()))
		_offering_input_area.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_carried_offering()
		_offering_input_area.accept_event()


func _pet_the_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	_select_pet(actor)

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	var emotion := _choose_petting_emotion(pet_id)
	_spawn_emotion(actor, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
	if actor.has_method("react_to_petting"):
		actor.call("react_to_petting", emotion)


func _choose_petting_emotion(pet_id: String) -> String:
	return PetCatalog.choose_weighted_emotion(pet_id, _rng.randf(), "petting_emotion_weights")


func _set_offering_cursor(texture_path: String) -> void:
	var cursor_size := _get_scaled_cursor_size(texture_path, OFFERING_DROP_SCALE, OFFERING_CURSOR_SIZE)
	if texture_path != _offering_cursor_path or cursor_size != _offering_cursor_size:
		_offering_cursor_texture = _make_cursor_texture(texture_path, cursor_size)
		_offering_cursor_path = texture_path
		_offering_cursor_size = cursor_size
	if _offering_cursor_texture == null:
		return
	if _current_cursor_texture == _offering_cursor_texture and _offering_cursor_active:
		return

	Input.set_custom_mouse_cursor(_offering_cursor_texture, Input.CURSOR_ARROW, Vector2(float(cursor_size.x), float(cursor_size.y)) * 0.5)
	_current_cursor_texture = _offering_cursor_texture
	_offering_cursor_active = true


func _refresh_offering_cursor() -> void:
	if _carried_offering.is_empty():
		return

	_set_offering_cursor(String(_carried_offering.get("texture", "")))


func _clear_offering_cursor() -> void:
	if not _offering_cursor_active:
		return

	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_current_cursor_texture = null
	_offering_cursor_active = false


func _make_cursor_texture(texture_path: String, target_size: Vector2i) -> Texture2D:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var used_rect := image.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		image = image.get_region(used_rect)
	image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _get_scaled_cursor_size(texture_path: String, sprite_scale: float, fallback_size: Vector2i) -> Vector2i:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return fallback_size

	var source_size := texture.get_size()
	var image := texture.get_image()
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		var used_rect := image.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			source_size = Vector2(used_rect.size)

	return Vector2i(
		maxi(1, int(round(source_size.x * sprite_scale))),
		maxi(1, int(round(source_size.y * sprite_scale)))
	)


func _spawn_emotion(actor: Node2D, emotion_name: String, offset: Vector2, effect_scale: float, delay := 0.0, primary := false) -> bool:
	var texture_path := _get_emotion_texture_path(emotion_name)
	if texture_path.is_empty():
		return false

	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false

	var now := _get_now_seconds()
	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		pet_id = str(actor.get_instance_id())

	if primary:
		var active_emotion := _active_emotions.get(pet_id) as Sprite2D
		var next_emotion_allowed_at := float(_next_emotion_allowed_at.get(pet_id, 0.0))
		if active_emotion != null and is_instance_valid(active_emotion) and now < next_emotion_allowed_at:
			_pulse_active_emotion(actor, pet_id)
			return false

		var active_emotion_tween := _active_emotion_tweens.get(pet_id) as Tween
		if active_emotion_tween != null and is_instance_valid(active_emotion_tween):
			active_emotion_tween.kill()

		if active_emotion != null and is_instance_valid(active_emotion):
			active_emotion.queue_free()

	var sprite := Sprite2D.new()
	sprite.name = "Emotion_%s" % emotion_name
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * effect_scale
	sprite.position = _get_safe_emotion_position(actor, offset, texture, effect_scale)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.z_index = 250
	add_child(sprite)

	if primary:
		_active_emotions[pet_id] = sprite
		_next_emotion_allowed_at[pet_id] = now + EMOTION_MIN_INTERVAL_SECONDS

	var start_position := sprite.position
	var end_position := _get_safe_sprite_position(start_position + Vector2(0.0, -24.0), texture, effect_scale * 1.08, SAFE_CANVAS_MARGIN)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * effect_scale * 1.08, 0.1)
	tween.tween_interval(EMOTION_HOLD_SECONDS if primary else 0.48)
	tween.tween_property(sprite, "position", end_position, 0.42)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.42)
	if primary:
		_active_emotion_tweens[pet_id] = tween
		tween.tween_callback(_clear_active_emotion.bind(pet_id, sprite))
	else:
		tween.tween_callback(Callable(sprite, "queue_free"))

	return true


func _get_safe_emotion_position(actor: Node2D, offset: Vector2, texture: Texture2D, sprite_scale: float) -> Vector2:
	var anchor: Vector2 = actor.position
	if actor.has_method("get_emotion_anchor"):
		anchor = actor.call("get_emotion_anchor")
	return _get_safe_sprite_position(anchor + offset, texture, sprite_scale, SAFE_CANVAS_MARGIN + 26.0)


func _get_safe_sprite_position(raw_position: Vector2, texture: Texture2D, sprite_scale: float, margin: float) -> Vector2:
	if texture == null:
		return raw_position

	var scaled_size := texture.get_size() * sprite_scale
	var half_size := scaled_size * 0.5
	var left := half_size.x + margin
	var right := float(_pet_window_size.x) - half_size.x - margin
	var top := half_size.y + margin
	var bottom := float(_pet_window_size.y) - half_size.y - margin

	if right < left:
		raw_position.x = float(_pet_window_size.x) * 0.5
	else:
		raw_position.x = clampf(raw_position.x, left, right)

	if bottom < top:
		raw_position.y = float(_pet_window_size.y) * 0.5
	else:
		raw_position.y = clampf(raw_position.y, top, bottom)

	return raw_position


func _pulse_active_emotion(actor: Node2D, pet_id: String) -> void:
	var active_emotion := _active_emotions.get(pet_id) as Sprite2D
	if active_emotion == null or not is_instance_valid(active_emotion):
		return

	var texture := active_emotion.texture
	if texture != null:
		active_emotion.position = _get_safe_emotion_position(actor, Vector2(-12.0, -18.0), texture, EMOTION_SCALE)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(active_emotion, "scale", Vector2.ONE * EMOTION_SCALE * 1.14, 0.08)
	tween.tween_property(active_emotion, "scale", Vector2.ONE * EMOTION_SCALE, 0.14)


func _clear_active_emotion(pet_id: String, sprite: Sprite2D) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

	if _active_emotions.get(pet_id) == sprite:
		_active_emotions.erase(pet_id)
		_active_emotion_tweens.erase(pet_id)


func _clear_pet_runtime_effects(pet_id: String) -> void:
	var active_emotion_tween := _active_emotion_tweens.get(pet_id) as Tween
	if active_emotion_tween != null and is_instance_valid(active_emotion_tween):
		active_emotion_tween.kill()

	var active_emotion := _active_emotions.get(pet_id) as Sprite2D
	if active_emotion != null and is_instance_valid(active_emotion):
		active_emotion.queue_free()

	_active_emotions.erase(pet_id)
	_active_emotion_tweens.erase(pet_id)
	_next_emotion_allowed_at.erase(pet_id)
	_next_ambient_emotion_at.erase(pet_id)


func _get_emotion_texture_path(emotion_name: String) -> String:
	match emotion_name:
		"confused":
			return EMOTION_CONFUSED_TEXTURE
		"happy":
			return EMOTION_HAPPY_TEXTURE
		"like":
			return EMOTION_LIKE_TEXTURE
		"sleepy":
			return EMOTION_SLEEPY_TEXTURE
		"suprised":
			return EMOTION_SUPRISED_TEXTURE
		_:
			return ""


# Economy and progression
func _refresh_pet_stats(force := false) -> void:
	if _side_drawer == null:
		return

	var faith_count := int(floor(_faith_points))
	var growth_rate := _get_faith_growth_rate()
	var faith_changed := faith_count != _last_reported_faith_count
	var growth_changed := not is_equal_approx(growth_rate, _last_reported_growth_rate)

	if force:
		_refresh_faith_display()
		_refresh_follower_display()
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate

	if _side_drawer.has_method("refresh_pet_upgrades") and (force or faith_changed or growth_changed or _pet_upgrade_stats_dirty):
		_side_drawer.call("refresh_pet_upgrades", _get_pet_upgrade_entries())
		_pet_upgrade_stats_dirty = false
		_last_reported_faith_count = faith_count
		_last_reported_growth_rate = growth_rate
		if growth_changed:
			_refresh_follower_display()


func _refresh_faith_display() -> void:
	if _side_drawer != null and _side_drawer.has_method("refresh_faith"):
		_side_drawer.refresh_faith(_faith_points, _get_faith_growth_rate())
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
			_get_follower_growth_rate()
		)


func _sync_shop_state() -> void:
	if _shop_window == null:
		return
	if _shop_window.has_method("set_coin_balance"):
		_shop_window.call("set_coin_balance", _gold_coins)
	if _shop_window.has_method("set_owned_counts"):
		_shop_window.call("set_owned_counts", _shop_owned_counts)


func _sync_gacha_state() -> void:
	if _gacha_window == null:
		return
	var next_cost := GachaProgression.draw_cost(_gacha_draw_count)
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
	_news_feed.restore(_loaded_news_state, _get_faith_growth_rate(), _follower_count)
	_loaded_news_state.clear()


func _update_news(delta: float) -> void:
	var now := _get_news_runtime_seconds()
	_news_milestone_check_timer += maxf(0.0, delta)
	if _news_milestone_check_timer >= NEWS_MILESTONE_CHECK_INTERVAL:
		_news_milestone_check_timer = 0.0
		var milestones := _news_feed.collect_milestones(
			_get_faith_growth_rate(),
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
	var context := {
		"faith_rate": _get_faith_growth_rate(),
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
	var now := _get_news_runtime_seconds()
	if not _news_feed.is_event_ready(event_key, now, cooldown_seconds):
		return
	if event_type != "gacha":
		if not _news_feed.is_event_ready("event:global", now, NEWS_EVENT_GLOBAL_COOLDOWN):
			return
		_news_feed.mark_event("event:global", now)
	_news_feed.mark_event(event_key, now)
	var article := _news_feed.make_event(event_type, _make_news_context(extra_context), _rng.randf())
	_queue_news_candidate(article)


func _publish_news(article: Dictionary, high_priority := false, broadcast := true) -> Dictionary:
	if article.is_empty():
		return {}
	var clock_text := "%s %s" % [
		Time.get_date_string_from_system(),
		Time.get_time_string_from_system().left(5)
	]
	var entry := _news_feed.add_article(
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
	var headline := String(entry.get("headline", ""))
	_news_broadcast_label.text = "【%s】 %s" % [String(entry.get("category", "异闻")), headline]
	_news_broadcast_panel.visible = true
	_news_broadcast_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_news_broadcast_panel.scale = Vector2(0.96, 0.96)
	_news_broadcast_active = true
	if _news_broadcast_tween != null and is_instance_valid(_news_broadcast_tween):
		_news_broadcast_tween.kill()
	var hold_seconds := _get_news_broadcast_hold_seconds(headline)
	_news_broadcast_tween = create_tween()
	_news_broadcast_tween.set_trans(Tween.TRANS_SINE)
	_news_broadcast_tween.set_ease(Tween.EASE_OUT)
	_news_broadcast_tween.tween_property(_news_broadcast_panel, "modulate", Color.WHITE, 0.2)
	_news_broadcast_tween.parallel().tween_property(_news_broadcast_panel, "scale", Vector2.ONE, 0.2)
	_news_broadcast_tween.tween_interval(hold_seconds)
	_news_broadcast_tween.tween_property(_news_broadcast_panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.42)
	_news_broadcast_tween.tween_callback(_finish_news_broadcast)


static func _get_news_broadcast_hold_seconds(headline: String) -> float:
	return clampf(5.5 + (float(headline.length()) * 0.04), 6.0, 9.0)


func _finish_news_broadcast() -> void:
	if _news_broadcast_panel != null:
		_news_broadcast_panel.visible = false
	_news_broadcast_active = false
	_news_broadcast_tween = null
	call_deferred("_show_next_news_broadcast")


func _load_game() -> void:
	if not _persistence_enabled:
		return
	var save := ConfigFile.new()
	var load_error := save.load(SAVE_PATH)
	if load_error == ERR_FILE_NOT_FOUND:
		return
	if load_error != OK:
		push_warning("Could not load save data: %s" % error_string(load_error))
		return
	var loaded_save_version := maxi(0, int(save.get_value("meta", "version", 0)))

	_faith_points = maxf(0.0, float(save.get_value("economy", "faith_points", 0.0)))
	_lifetime_faith = maxf(
		_faith_points,
		float(save.get_value("economy", "lifetime_faith", _faith_points))
	)
	_follower_count = maxf(0.0, float(save.get_value("economy", "followers", 0.0)))
	_gold_coins = maxi(0, int(save.get_value("economy", "gold_coins", 0)))
	_total_runtime_seconds = maxf(0.0, float(save.get_value("statistics", "total_runtime_seconds", 0.0)))
	_pet_activity_range = String(save.get_value("settings", "pet_activity_range", "full"))
	if _pet_activity_range not in ["full", "right", "left"]:
		_pet_activity_range = "full"
	_language = "en" if String(save.get_value("settings", "language", "zh")) == "en" else "zh"
	_selected_pet_id = String(save.get_value("pets", "selected_pet_id", ""))
	_pet_states = _sanitize_loaded_pet_states(save.get_value("pets", "states", {}))
	if loaded_save_version >= PET_UNLOCK_SAVE_VERSION:
		_unlocked_pet_ids = _sanitize_pet_id_list(
			save.get_value("pets", "unlocked_ids", PetCatalog.STARTER_UNLOCKED_PETS),
			PetCatalog.ACTIVE_DESKTOP_PETS
		)
		if not _unlocked_pet_ids.has("pet1"):
			_unlocked_pet_ids.push_front("pet1")
		_deployed_pet_ids = _sanitize_pet_id_list(
			save.get_value("pets", "deployed_ids", PetCatalog.STARTER_UNLOCKED_PETS),
			_unlocked_pet_ids
		)
	else:
		_unlocked_pet_ids = ["pet1"]
		_deployed_pet_ids = ["pet1"]
	for deployed_pet_id in _deployed_pet_ids.duplicate():
		if _is_pet_recovering(String(deployed_pet_id)):
			_deployed_pet_ids.erase(deployed_pet_id)
	if _deployed_pet_ids.is_empty():
		for unlocked_pet_id in _unlocked_pet_ids:
			if not _is_pet_recovering(String(unlocked_pet_id)):
				_deployed_pet_ids.append(String(unlocked_pet_id))
				break
	if not _selected_pet_id.is_empty() and not _unlocked_pet_ids.has(_selected_pet_id):
		_selected_pet_id = ""
	_pet_offering_buffs = _sanitize_loaded_offering_buffs(
		save.get_value("offerings", "active_buffs", {})
	)
	_shop_owned_counts = _sanitize_owned_counts(save.get_value("shop", "owned_counts", {}))
	if loaded_save_version >= PET_UNLOCK_SAVE_VERSION:
		_gacha_draw_count = clampi(int(save.get_value("gacha", "draw_count", 0)), 0, 1000000)
		_gacha_pity_count = clampi(
			int(save.get_value("gacha", "pity_count", 0)),
			0,
			GachaProgression.NEW_PET_PITY_DRAWS - 1
		)
		_gacha_history = _sanitize_gacha_history(save.get_value("gacha", "history", []))
	else:
		# Legacy draws granted global buffs, so their count cannot price the new pet pool.
		_gacha_draw_count = 0
		_gacha_pity_count = 0
		_gacha_history.clear()
	_loaded_news_state = {
		"copy_version": save.get_value("news", "copy_version", 0),
		"history": save.get_value("news", "history", []),
		"next_id": save.get_value("news", "next_id", 1),
		"faith_tier": _get_loaded_news_faith_tier(
			loaded_save_version,
			save.get_value("news", "faith_tier", 0),
			_get_faith_growth_rate()
		),
		"follower_tier": save.get_value("news", "follower_tier", NewsFeed.get_follower_tier(_follower_count)),
		"recent_templates": save.get_value("news", "recent_templates", [])
	}
	var carried_value: Variant = save.get_value(
		"shop",
		"carried_offering",
		save.get_value("offerings", "carried", {})
	)
	if carried_value is Dictionary:
		_carried_offering = OfferingCatalog.normalize_offering(carried_value)
	else:
		_carried_offering.clear()
	_loaded_save_unix = maxf(0.0, float(save.get_value("meta", "saved_unix", 0.0)))
	var saved_menu_anchor := float(save.get_value("ui", "menu_handle_anchor", -1.0))
	_loaded_menu_handle_anchor = (
		clampf(saved_menu_anchor, 0.0, 1.0)
		if is_finite(saved_menu_anchor) and saved_menu_anchor >= 0.0
		else -1.0
	)


func _save_game() -> void:
	if not _persistence_enabled:
		return
	var save := ConfigFile.new()
	save.set_value("meta", "version", SAVE_VERSION)
	save.set_value("meta", "saved_unix", Time.get_unix_time_from_system())
	save.set_value("economy", "faith_points", maxf(0.0, _faith_points))
	save.set_value("economy", "lifetime_faith", maxf(0.0, _lifetime_faith))
	save.set_value("economy", "followers", maxf(0.0, _follower_count))
	save.set_value("economy", "gold_coins", maxi(0, _gold_coins))
	save.set_value("statistics", "total_runtime_seconds", maxf(0.0, _total_runtime_seconds))
	save.set_value("settings", "pet_activity_range", _pet_activity_range)
	save.set_value("settings", "language", _language)
	save.set_value("pets", "selected_pet_id", _selected_pet_id)
	save.set_value("pets", "states", _pet_states.duplicate(true))
	save.set_value("pets", "unlocked_ids", _unlocked_pet_ids.duplicate())
	save.set_value("pets", "deployed_ids", _deployed_pet_ids.duplicate())
	save.set_value("shop", "owned_counts", _shop_owned_counts.duplicate(true))
	save.set_value("gacha", "draw_count", _gacha_draw_count)
	save.set_value("gacha", "pity_count", _gacha_pity_count)
	save.set_value("gacha", "history", _gacha_history.duplicate(true))
	var news_state := _news_feed.get_state()
	save.set_value("news", "copy_version", news_state.get("copy_version", NewsFeed.NEWS_COPY_VERSION))
	save.set_value("news", "history", news_state.get("history", []))
	save.set_value("news", "next_id", news_state.get("next_id", 1))
	save.set_value("news", "faith_tier", news_state.get("faith_tier", 0))
	save.set_value("news", "follower_tier", news_state.get("follower_tier", 0))
	save.set_value("news", "recent_templates", news_state.get("recent_templates", []))
	save.set_value("shop", "carried_offering", _carried_offering.duplicate(true))
	save.set_value("offerings", "active_buffs", _pet_offering_buffs.duplicate(true))
	if _side_drawer != null and _side_drawer.has_method("get_menu_handle_anchor"):
		save.set_value("ui", "menu_handle_anchor", _side_drawer.call("get_menu_handle_anchor"))
	var save_error := save.save(SAVE_PATH)
	if save_error != OK:
		push_warning("Could not save game data: %s" % error_string(save_error))


func _apply_offline_progress() -> void:
	if _loaded_save_unix <= 0.0:
		return
	var elapsed_seconds := clampf(
		Time.get_unix_time_from_system() - _loaded_save_unix,
		0.0,
		OFFLINE_PROGRESS_MAX_SECONDS
	)
	_loaded_save_unix = 0.0
	if elapsed_seconds < 1.0:
		return
	var effective_seconds := elapsed_seconds * OFFLINE_PROGRESS_EFFICIENCY
	var faith_rate := _get_faith_growth_rate()
	_grant_faith(faith_rate * effective_seconds)
	_follower_count = FollowerProgression.advance(_follower_count, faith_rate, effective_seconds)


func _update_autosave(delta: float) -> void:
	if not _persistence_enabled:
		return
	_autosave_timer += maxf(0.0, delta)
	if _autosave_timer < AUTOSAVE_INTERVAL_SECONDS:
		return
	_autosave_timer = 0.0
	_save_game()


func _sanitize_loaded_pet_states(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_states: Dictionary = raw_value
	for pet_id_value in PetCatalog.ACTIVE_DESKTOP_PETS:
		var pet_id := String(pet_id_value)
		var state_value: Variant = raw_states.get(pet_id, {})
		if not state_value is Dictionary:
			continue
		var raw_state: Dictionary = state_value
		var state := {
			"upgrade_level": clampi(
				int(raw_state.get("upgrade_level", raw_state.get("count", 1))),
				1,
				PetProgression.MAX_LEVEL
			)
		}
		var recover_until := maxf(0.0, float(raw_state.get("recover_until", 0.0)))
		var recovery_duration := clampf(float(raw_state.get("recovery_duration", 0.0)), 0.0, 3600.0)
		var recovery_started_at := maxf(0.0, float(raw_state.get("recovery_started_at", recover_until - recovery_duration)))
		if recover_until > Time.get_unix_time_from_system() and recovery_duration > 0.0:
			state["recovery_started_at"] = recovery_started_at
			state["recover_until"] = recover_until
			state["recovery_duration"] = recovery_duration
		var custom_name := String(raw_state.get("name", "")).strip_edges().left(40)
		if custom_name.is_empty():
			state.erase("name")
		else:
			state["name"] = custom_name
		sanitized[pet_id] = state
	return sanitized


static func _sanitize_pet_id_list(raw_value: Variant, allowed_ids: Array) -> Array[String]:
	var requested := {}
	if raw_value is Array:
		for pet_id_value in raw_value:
			requested[String(pet_id_value)] = true
	var sanitized: Array[String] = []
	for pet_id_value in allowed_ids:
		var pet_id := String(pet_id_value)
		if requested.has(pet_id) and not sanitized.has(pet_id):
			sanitized.append(pet_id)
	return sanitized


static func _get_loaded_news_faith_tier(
	save_version: int,
	saved_tier: Variant,
	current_faith_rate: float
) -> int:
	if save_version < NEWS_RATE_MODEL_SAVE_VERSION:
		return NewsFeed.get_faith_tier(current_faith_rate)
	return clampi(int(saved_tier), 0, NewsFeed.FAITH_RATE_MILESTONES.size())


func _sanitize_owned_counts(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var raw_counts: Dictionary = raw_value
	for key_value in raw_counts:
		var key := String(key_value)
		if key.is_empty():
			continue
		sanitized[key] = clampi(int(raw_counts[key_value]), 0, 100000)
	return sanitized


func _sanitize_loaded_offering_buffs(raw_value: Variant) -> Dictionary:
	var sanitized := {}
	if not raw_value is Dictionary:
		return sanitized
	var now := _get_now_seconds()
	var raw_buffs: Dictionary = raw_value
	for pet_id_value in raw_buffs:
		var pet_id := String(pet_id_value)
		if not PetCatalog.DEFINITIONS.has(pet_id):
			continue
		var buff_value: Variant = raw_buffs[pet_id_value]
		if not buff_value is Dictionary:
			continue
		var buff: Dictionary = buff_value
		var multiplier := clampf(float(buff.get("multiplier", 1.0)), 1.0, 100.0)
		var expires_at := clampf(float(buff.get("expires_at", 0.0)), 0.0, now + 3600.0)
		if multiplier <= 1.0 or expires_at <= now:
			continue
		sanitized[pet_id] = {
			"multiplier": multiplier,
			"expires_at": expires_at,
			"offering_name": String(buff.get("offering_name", "贡品")).strip_edges().left(40)
		}
	return sanitized


func _sanitize_gacha_history(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	for entry_value in raw_value:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var pet_id := String(entry.get("pet_id", ""))
		var pool_entry := GachaProgression.get_pool_entry(pet_id)
		if pool_entry.is_empty():
			continue
		var is_new := bool(entry.get("is_new", false))
		pool_entry["is_new"] = is_new
		pool_entry["duplicate_faith"] = (
			0
			if is_new
			else clampi(
				int(entry.get("duplicate_faith", 0)),
				0,
				GachaProgression.MAX_DUPLICATE_FAITH_REWARD
			)
		)
		pool_entry["name"] = String(
			entry.get("name", PetCatalog.get_definition(pet_id).get("name", pet_id))
		).strip_edges().left(40)
		sanitized.append(pool_entry)
		if sanitized.size() >= 10:
			break
	return sanitized


func _is_pet_unlocked(pet_id: String) -> bool:
	return not pet_id.is_empty() and _unlocked_pet_ids.has(pet_id)


func _get_inventory_pet_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id_value in _unlocked_pet_ids:
		var pet_id := String(pet_id_value)
		if _deployed_pet_ids.has(pet_id):
			continue
		var entry := PetCatalog.make_inventory_entry(pet_id)
		entry["name"] = _get_pet_display_name(pet_id)
		entry.merge(_get_pet_recovery_info(pet_id), true)
		entries.append(entry)
	return entries


func _select_pet(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	_selected_pet_id = pet_id
	_ensure_pet_state(pet_id)
	_refresh_pet_stats()


func _ensure_pet_state(pet_id: String) -> void:
	if not _pet_states.has(pet_id):
		_pet_states[pet_id] = {"upgrade_level": 1}
		return

	var state: Dictionary = _pet_states[pet_id]
	var level := clampi(
		int(state.get("upgrade_level", state.get("count", 1))),
		1,
		PetProgression.MAX_LEVEL
	)
	for key in state.keys():
		if key not in ["upgrade_level", "name", "recovery_started_at", "recover_until", "recovery_duration"]:
			state.erase(key)
	state["upgrade_level"] = level
	var custom_name := String(state.get("name", "")).strip_edges().left(40)
	if custom_name.is_empty():
		state.erase("name")
	else:
		state["name"] = custom_name
	var recover_until := maxf(0.0, float(state.get("recover_until", 0.0)))
	var recovery_duration := clampf(float(state.get("recovery_duration", 0.0)), 0.0, 3600.0)
	if recover_until <= _get_now_seconds() or recovery_duration <= 0.0:
		state.erase("recovery_started_at")
		state.erase("recover_until")
		state.erase("recovery_duration")
	else:
		state["recovery_started_at"] = maxf(0.0, float(state.get("recovery_started_at", recover_until - recovery_duration)))
		state["recover_until"] = recover_until
		state["recovery_duration"] = recovery_duration
	_pet_states[pet_id] = state


func _get_pet_state(pet_id: String) -> Dictionary:
	_ensure_pet_state(pet_id)
	return _pet_states[pet_id]


func _is_pet_recovering(pet_id: String, now := -1.0) -> bool:
	if pet_id.is_empty() or not _pet_states.has(pet_id):
		return false
	var check_time := _get_now_seconds() if now < 0.0 else now
	var state: Dictionary = _pet_states[pet_id]
	return float(state.get("recover_until", 0.0)) > check_time


func _get_pet_recovery_info(pet_id: String) -> Dictionary:
	var state := _get_pet_state(pet_id)
	var now := _get_now_seconds()
	var recover_until := float(state.get("recover_until", 0.0))
	var duration := maxf(0.0, float(state.get("recovery_duration", 0.0)))
	var remaining := maxf(0.0, recover_until - now)
	var recovering := remaining > 0.0 and duration > 0.0
	return {
		"recovering": recovering,
		"recovery_seconds_remaining": remaining,
		"recovery_progress": clampf(1.0 - remaining / maxf(0.001, duration), 0.0, 1.0) if recovering else 1.0
	}


func _update_recovery_states(delta: float) -> void:
	_recovery_ui_refresh_time += maxf(0.0, delta)
	if _recovery_ui_refresh_time < 1.0:
		return
	_recovery_ui_refresh_time = 0.0
	var now := _get_now_seconds()
	var has_active_recovery := false
	var recovery_completed := false
	for pet_id_value in _pet_states.keys():
		var pet_id := String(pet_id_value)
		var state: Dictionary = _pet_states[pet_id]
		var recover_until := float(state.get("recover_until", 0.0))
		if recover_until <= 0.0:
			continue
		if recover_until > now:
			has_active_recovery = true
			continue
		state.erase("recovery_started_at")
		state.erase("recover_until")
		state.erase("recovery_duration")
		_pet_states[pet_id] = state
		recovery_completed = true
	if has_active_recovery or recovery_completed:
		_pet_upgrade_stats_dirty = true
		if _inventory_window != null and _inventory_window.visible:
			_sync_inventory_window()
	if recovery_completed:
		_refresh_pet_stats(true)
		_save_game()


func _get_pet_upgrade_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id_value in _unlocked_pet_ids:
		var pet_id := String(pet_id_value)
		var state := _get_pet_state(pet_id)
		var level := PetProgression.progression_level(state)
		var pet_data := PetCatalog.get_definition(pet_id)
		var is_max_level := level >= PetProgression.MAX_LEVEL
		var cost := 0 if is_max_level else _get_upgrade_cost(pet_id)
		var offering_multiplier := _get_pet_offering_multiplier(pet_id)
		var recovery_info := _get_pet_recovery_info(pet_id)
		var recovering := bool(recovery_info.get("recovering", false))
		var current_fps := (
			_get_pet_faith_per_second(pet_id, level)
			* offering_multiplier
			* _get_total_faith_multiplier()
		)
		var next_fps := _get_pet_faith_per_second(
			pet_id,
			mini(PetProgression.MAX_LEVEL, level + 1)
		) * offering_multiplier * _get_total_faith_multiplier()
		var current_money_rate := _get_pet_money_value_per_minute(pet_id, level)
		var next_money_rate := _get_pet_money_value_per_minute(
			pet_id,
			mini(PetProgression.MAX_LEVEL, level + 1)
		)
		if recovering:
			current_fps = 0.0
			current_money_rate = 0.0
		entries.append({
			"id": pet_id,
			"name": _get_pet_display_name(pet_id),
			"description": String(pet_data.get("description", "")),
			"rarity_stars": clampi(int(pet_data.get("rarity_stars", 1)), 1, 5),
			"age_text": _get_pet_age_text(pet_data),
			"personality": String(pet_data.get("personality", "性格不详")),
			"level": level,
			"is_max_level": is_max_level,
			"cost": cost,
			"current_fps": current_fps,
			"next_fps": next_fps,
			"next_growth_bonus": maxf(0.0, next_fps - current_fps),
			"total_growth_bonus": current_fps,
			"current_money_rate": current_money_rate,
			"next_money_rate": next_money_rate,
			"money_rate_gain": maxf(0.0, next_money_rate - current_money_rate),
			"offering_multiplier": offering_multiplier,
			"offering_seconds_remaining": _get_pet_offering_seconds_remaining(pet_id),
			"affordable": not is_max_level and int(floor(_faith_points)) >= cost
		})
		entries[entries.size() - 1].merge(recovery_info, true)

	return entries


func _get_pet_age_text(pet_data: Dictionary) -> String:
	if not pet_data.has("base_age_years"):
		return String(pet_data.get("age_text", pet_data.get("age", "Unknown" if _language == "en" else "年龄不详")))
	var elapsed_years := EraProgression.get_elapsed_calendar_years(_total_runtime_seconds)
	var age_years := maxi(0, int(pet_data.get("base_age_years", 0)) + elapsed_years)
	var qualifier := String(pet_data.get("age_qualifier", ""))
	if _language == "en":
		if qualifier == "about":
			return "about %d years" % age_years
		if qualifier == "at_least":
			return "at least %d years" % age_years
		return "%d years" % age_years
	if qualifier == "about":
		return "约%d岁" % age_years
	if qualifier == "at_least":
		return "至少%d岁" % age_years
	return "%d岁" % age_years


func _get_upgrade_cost(pet_id: String) -> int:
	var pet_data := PetCatalog.get_definition(pet_id)
	var state := _get_pet_state(pet_id)
	return PetProgression.upgrade_cost(pet_data, state)


func _get_faith_growth_rate() -> float:
	var total_fps := 0.0
	for pet_id_value in _unlocked_pet_ids:
		var pet_id := String(pet_id_value)
		if _is_pet_recovering(pet_id):
			continue
		var state := _get_pet_state(pet_id)
		total_fps += (
			_get_pet_faith_per_second(pet_id, PetProgression.progression_level(state))
			* _get_pet_offering_multiplier(pet_id)
		)

	return total_fps * _get_total_faith_multiplier()


func _get_follower_growth_rate() -> float:
	return FollowerProgression.followers_per_second(_get_faith_growth_rate())


func _get_pet_faith_per_second(pet_id: String, level: int) -> float:
	return PetProgression.faith_per_second(PetCatalog.get_definition(pet_id), level)


func _get_pet_money_value_per_minute(pet_id: String, level: int) -> float:
	return PetProgression.money_drop_value_per_minute(PetCatalog.get_definition(pet_id), level)


func _get_pet_offering_multiplier(pet_id: String, now := -1.0) -> float:
	var buff_value: Variant = _pet_offering_buffs.get(pet_id, {})
	if not buff_value is Dictionary:
		return 1.0
	var buff: Dictionary = buff_value
	var current_time := _get_now_seconds() if now < 0.0 else now
	if float(buff.get("expires_at", 0.0)) <= current_time:
		return 1.0
	return maxf(1.0, float(buff.get("multiplier", 1.0)))


func _get_pet_offering_seconds_remaining(pet_id: String, now := -1.0) -> float:
	var buff_value: Variant = _pet_offering_buffs.get(pet_id, {})
	if not buff_value is Dictionary:
		return 0.0
	var current_time := _get_now_seconds() if now < 0.0 else now
	return maxf(0.0, float((buff_value as Dictionary).get("expires_at", 0.0)) - current_time)


func _update_pet_offering_buffs() -> void:
	if _pet_offering_buffs.is_empty():
		return
	var now := _get_now_seconds()
	var changed := false
	for pet_id_value in _pet_offering_buffs.keys().duplicate():
		var pet_id := String(pet_id_value)
		if _get_pet_offering_seconds_remaining(pet_id, now) > 0.0:
			continue
		_pet_offering_buffs.erase(pet_id)
		changed = true
	if changed:
		_pet_upgrade_stats_dirty = true


func _get_total_faith_multiplier() -> float:
	return GLOBAL_FAITH_MULTIPLIER * BUFF_FAITH_MULTIPLIER


func _get_pet_display_name(pet_id: String) -> String:
	var state := _get_pet_state(pet_id)
	var custom_name := String(state.get("name", "")).strip_edges()
	if not custom_name.is_empty():
		return custom_name

	var pet_data := PetCatalog.get_definition(pet_id)
	return String(pet_data.get("name", pet_id))


func _apply_pet_display_name(pet_id: String) -> void:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _get_actor_pet_id(pet) != pet_id:
			continue
		if pet.has_method("set_display_name"):
			pet.call("set_display_name", _get_pet_display_name(pet_id))


func _set_pet_custom_name(pet_id: String, custom_name: String) -> void:
	if pet_id.is_empty():
		return

	var state := _get_pet_state(pet_id)
	custom_name = custom_name.strip_edges().left(40)
	if custom_name.is_empty():
		state.erase("name")
	else:
		state["name"] = custom_name
	_pet_states[pet_id] = state

	_apply_pet_display_name(pet_id)
	if _inventory_window != null and _inventory_window.has_method("set_pet_name"):
		_inventory_window.call("set_pet_name", pet_id, custom_name)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)


func _grant_faith(amount: float) -> void:
	var safe_amount := maxf(0.0, amount)
	if safe_amount <= 0.0:
		return
	_faith_points += safe_amount
	_lifetime_faith += safe_amount


func _update_faith(delta: float) -> void:
	_grant_faith(_get_faith_growth_rate() * delta)
	_refresh_faith_display()
	_stats_refresh_timer += delta
	if _stats_refresh_timer >= UI_REFRESH_INTERVAL:
		_stats_refresh_timer = 0.0
		_refresh_pet_stats()


func _update_followers(delta: float) -> void:
	_follower_count = FollowerProgression.advance(
		_follower_count,
		_get_faith_growth_rate(),
		delta
	)
	var follower_count := int(floor(_follower_count))
	if follower_count != _last_reported_follower_count:
		_last_reported_follower_count = follower_count
		_refresh_follower_display()


func _update_pet_emotions() -> void:
	var now := _get_now_seconds()
	for pet in _pets:
		if not is_instance_valid(pet):
			continue

		var pet_id := _get_actor_pet_id(pet)
		if pet_id.is_empty():
			continue

		var next_emotion_at := float(_next_ambient_emotion_at.get(pet_id, 0.0))
		if now < next_emotion_at:
			continue

		var emotion := PetCatalog.choose_weighted_emotion(pet_id, _rng.randf())
		_spawn_emotion(pet, emotion, Vector2(-12.0, -18.0), EMOTION_SCALE, 0.0, true)
		_schedule_next_ambient_emotion(pet_id, now)


func _schedule_next_ambient_emotion(pet_id: String, now := -1.0) -> void:
	var pet_data := PetCatalog.get_definition(pet_id)
	var interval_min := maxf(4.0, float(pet_data.get("ambient_emotion_interval_min", 18.0)))
	var interval_max := maxf(interval_min, float(pet_data.get("ambient_emotion_interval_max", 36.0)))
	var base_time := _get_now_seconds() if now < 0.0 else now
	_next_ambient_emotion_at[pet_id] = base_time + _rng.randf_range(interval_min, interval_max)


# Shared helpers
func _get_actor_pet_id(actor: Node2D) -> String:
	if actor != null and "pet_id" in actor:
		return String(actor.pet_id)

	return ""


func _get_now_seconds() -> float:
	return _simulation_now_seconds if _simulation_now_seconds > 0.0 else Time.get_unix_time_from_system()


func _get_news_runtime_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _get_current_screen_usable_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(_get_current_screen())


func _get_current_screen() -> int:
	var screen := DisplayServer.SCREEN_WITH_MOUSE_FOCUS
	if screen < 0:
		screen = DisplayServer.window_get_current_screen()
	return screen


# Event handlers
func _on_pet_petted(actor: Node2D) -> void:
	_hovered_pet = actor
	_pet_the_pet(actor)
	_spawn_pet_coin(actor)
	var pet_id := _get_actor_pet_id(actor)
	if not pet_id.is_empty():
		_try_queue_news_event(
			"petting",
			{},
			"petting:%s" % pet_id,
			35.0,
			0.55
		)


func _on_pet_grabbed_changed(actor: Node2D, grabbed: bool) -> void:
	if not _battle_active or actor == null or not is_instance_valid(actor):
		return
	if grabbed:
		# Once the player takes command, stop the formation AI from pulling the
		# pet back. Its dropped position becomes its new battle line.
		_battle_pet_formed[str(actor.get_instance_id())] = true


func _on_pet_notable_action(actor: Node2D, action_id: String) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if action_id not in ["burrow", "sleep", "air_roam", "wall_crawl", "hide"]:
		return
	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return
	_try_queue_news_event(
		action_id,
		{},
		"pet_action:%s:%s" % [pet_id, action_id],
		75.0
	)


func _on_pet_recall_requested(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var pet_id := _get_actor_pet_id(actor)
	if pet_id.is_empty():
		return

	_deployed_pet_ids.erase(pet_id)
	if _inventory_window != null and _inventory_window.has_method("add_pet"):
		_inventory_window.call("add_pet", pet_id, _get_pet_display_name(pet_id))

	_pets.erase(actor)
	var actor_key := str(actor.get_instance_id())
	_next_pet_coin_drop_at.erase(actor_key)
	_pet_coin_drop_intervals.erase(actor_key)
	if pet_id == "pet11":
		_next_pet11_absorb_at = 0.0
	if _hovered_pet == actor:
		_hovered_pet = null

	if _selected_pet_id == pet_id:
		_selected_pet_id = _get_first_desktop_pet_id()

	_finish_pending_offering_for_actor(actor)
	_clear_pet_runtime_effects(pet_id)
	actor.queue_free()
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_save_game()


func _finish_pending_offering_for_actor(actor: Node2D) -> void:
	if actor == null:
		return

	var target_key := str(actor.get_instance_id())
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var pet_id := _get_actor_pet_id(actor)
	var sprite := feed_data.get("sprite") as Sprite2D
	var drop_position: Vector2 = feed_data.get("drop_position", actor.position)
	var offering: Dictionary = feed_data.get("offering", {})
	_finish_offering_consumed(sprite, offering, drop_position, pet_id)


func _on_believer_exited(actor: Node2D) -> void:
	if actor != null:
		_believers.erase(actor)


func _get_first_desktop_pet_id() -> String:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var pet_id := _get_actor_pet_id(pet)
		if not pet_id.is_empty():
			return pet_id

	return ""


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
			_debug_game_speed
		)
	_settings_window.open_window()


func _on_gacha_draw_requested(draw_amount: int = 1) -> void:
	if _gacha_window == null:
		return
	var safe_draw_amount := 10 if draw_amount >= 10 else 1
	var batch_cost := GachaProgression.draw_cost_total(_gacha_draw_count, safe_draw_amount)
	if float(_gold_coins) < batch_cost:
		_sync_gacha_state()
		return

	var results: Array[Dictionary] = []
	var gross_cost_spent := 0.0
	for _draw_index in safe_draw_amount:
		var cost := GachaProgression.draw_cost(_gacha_draw_count)
		_gold_coins -= cost
		gross_cost_spent += float(cost)
		var result := GachaProgression.roll_pet(
			_rng.randf(),
			_unlocked_pet_ids,
			_gacha_pity_count
		)
		if result.is_empty():
			_gold_coins += cost
			gross_cost_spent -= float(cost)
			break

		var pet_id := String(result.get("pet_id", ""))
		if pet_id.is_empty() or not PetCatalog.GACHA_PETS.has(pet_id):
			_gold_coins += cost
			gross_cost_spent -= float(cost)
			break
		_ensure_pet_state(pet_id)
		result["name"] = _get_pet_display_name(pet_id)
		if bool(result.get("is_new", false)):
			_unlocked_pet_ids.append(pet_id)
			_unlocked_pet_ids = _sanitize_pet_id_list(
				_unlocked_pet_ids,
				PetCatalog.ACTIVE_DESKTOP_PETS
			)
			if _inventory_window != null and _inventory_window.has_method("add_pet"):
				_inventory_window.call("add_pet", pet_id, _get_pet_display_name(pet_id))
		else:
			var duplicate_faith := GachaProgression.duplicate_faith_reward(cost, result)
			_faith_points += float(duplicate_faith)
			result["duplicate_faith"] = duplicate_faith

		_gacha_pity_count = GachaProgression.next_pity_count(_gacha_pity_count, result)
		_gacha_draw_count += 1
		_gacha_history.push_front(result.duplicate(true))
		if _gacha_history.size() > 10:
			_gacha_history.resize(10)
		results.append(result.duplicate(true))
		_try_queue_news_event(
			"gacha",
			{"item_name": String(result.get("name", "未知宠物"))},
			"gacha",
			5.0
		)

	if results.is_empty():
		_sync_gacha_state()
		return
	_show_coin_change_popup(_get_window_mouse_position(get_window()), -int(round(gross_cost_spent)))
	_gacha_window.show_results(results)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_refresh_coin_display()
	_sync_gacha_state()
	_save_game()


func _on_shop_purchase_requested(good_id: String) -> void:
	if _shop_window == null or good_id.is_empty():
		return

	var good: Dictionary = _shop_window.call("get_good", good_id)
	if good.is_empty():
		_shop_window.call("set_purchase_result", good_id, false, "Item not found" if _language == "en" else "商品不存在")
		return

	var price := maxi(0, int(good.get("price", 0)))
	var is_offering := OfferingCatalog.is_offering(good)
	if is_offering and not _carried_offering.is_empty():
		_shop_window.call("set_purchase_result", good_id, false, "Place or cancel the carried offering first" if _language == "en" else "请先投放或取消鼠标上的贡品")
		return
	if _gold_coins < price:
		_shop_window.call("set_purchase_result", good_id, false, "Not enough gold" if _language == "en" else "金币不足")
		return

	if is_offering:
		var carried := OfferingCatalog.normalize_offering(good)
		if carried.is_empty():
			_shop_window.call("set_purchase_result", good_id, false, "Invalid offering data" if _language == "en" else "贡品数据无效")
			return
		_gold_coins -= price
		carried["purchase_price"] = price
		_carried_offering = carried
		_set_offering_cursor(String(_carried_offering.get("texture", "")))
		_update_offering_input_window()
		_show_coin_change_popup(_get_window_mouse_position(get_window()), -price)
		_sync_shop_state()
		_shop_window.call(
			"set_purchase_result",
			good_id,
			true,
			("Carrying %s. Click the desktop to place it; right-click to cancel" if _language == "en" else "已拿起：%s，点击桌面任意位置投放，右键取消") % String(good.get("name", "贡品"))
		)
		if _shop_window.has_method("close_window"):
			_shop_window.call("close_window")
		else:
			_shop_window.visible = false
		_refresh_pet_stats(true)
		_refresh_coin_display()
		_save_game()
		return

	_gold_coins -= price
	_show_coin_change_popup(_get_window_mouse_position(get_window()), -price)
	_shop_owned_counts[good_id] = int(_shop_owned_counts.get(good_id, 0)) + 1
	_sync_shop_state()
	_shop_window.call("set_purchase_result", good_id, true, ("Purchased: %s" if _language == "en" else "购买成功：%s") % String(good.get("name", "商品")))
	_refresh_pet_stats(true)
	_refresh_coin_display()
	_save_game()


func _on_inventory_pet_deploy_requested(pet_id: String) -> void:
	if pet_id.is_empty() or not _is_pet_unlocked(pet_id) or _deployed_pet_ids.has(pet_id):
		return
	if _battle_active or _pilgrimage_active or _is_pet_recovering(pet_id):
		_sync_inventory_window()
		return

	var actor := _spawn_desktop_pet(pet_id)
	if actor == null:
		return

	_selected_pet_id = pet_id
	_deployed_pet_ids.append(pet_id)
	if _inventory_window != null and _inventory_window.has_method("remove_pet"):
		_inventory_window.call("remove_pet", pet_id)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_save_game()


func _on_inventory_pet_rename_requested(pet_id: String, custom_name: String) -> void:
	_set_pet_custom_name(pet_id, custom_name)


func _on_pet_detail_rename_requested(pet_id: String, custom_name: String) -> void:
	_set_pet_custom_name(pet_id, custom_name)
	_save_game()


# Offerings
func _cancel_carried_offering() -> void:
	var cancelled_offering := _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	var refund := maxi(0, int(cancelled_offering.get("purchase_price", 0)))
	if refund > 0:
		_gold_coins += refund
		_show_coin_change_popup(_get_window_mouse_position(get_window()), refund)
		_sync_shop_state()
		_refresh_coin_display()
		if _shop_window != null and _shop_window.has_method("set_purchase_result"):
			_shop_window.call(
				"set_purchase_result",
				String(cancelled_offering.get("id", "")),
				true,
				("Placement cancelled. Refunded $%d gold" if _language == "en" else "已取消投放，返还 $%d 金币") % refund
			)
	call_deferred("_update_offering_input_window")
	_save_game()


func _drop_carried_offering(window_position: Vector2) -> void:
	if _carried_offering.is_empty():
		return

	var offering := _carried_offering.duplicate(true)
	_carried_offering.clear()
	_clear_offering_cursor()
	call_deferred("_update_offering_input_window")
	_save_game()

	var texture := load(String(offering.get("texture", ""))) as Texture2D
	if texture == null:
		_finish_offering_consumed(null, offering, window_position, "")
		return

	var sprite := Sprite2D.new()
	sprite.name = "Offering_%s" % String(offering.get("name", "Food"))
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2.ONE * (OFFERING_DROP_SCALE * 0.78)
	sprite.z_index = 260

	var drop_position := _get_grounded_offering_position(window_position.x, texture, OFFERING_DROP_SCALE)
	sprite.position = _get_safe_sprite_position(drop_position + Vector2(0.0, -58.0), texture, OFFERING_DROP_SCALE * 0.78, SAFE_CANVAS_MARGIN)
	add_child(sprite)

	var drop_tween := create_tween()
	drop_tween.set_trans(Tween.TRANS_BACK)
	drop_tween.set_ease(Tween.EASE_OUT)
	drop_tween.tween_property(sprite, "position", drop_position, 0.28)
	drop_tween.parallel().tween_property(sprite, "scale", Vector2.ONE * OFFERING_DROP_SCALE, 0.28)

	var target := _get_offering_target_pet(drop_position.x)
	if target == null or not is_instance_valid(target):
		drop_tween.tween_interval(0.18)
		drop_tween.tween_callback(_finish_offering_consumed.bind(sprite, offering, drop_position, ""))
		return

	var target_key := str(target.get_instance_id())
	_pending_offering_feeds[target_key] = {
		"sprite": sprite,
		"offering": offering,
		"drop_position": drop_position,
		"target": target,
		"expires_at": _get_now_seconds() + OFFERING_FEED_TIMEOUT_SECONDS,
		"landed": false,
		"arrived": false
	}

	if target.has_method("walk_to_offering_x"):
		drop_tween.tween_callback(_mark_offering_landed.bind(target_key))
		_send_pet_to_offering(target, target_key, drop_position.x)
	else:
		_pending_offering_feeds.erase(target_key)
		drop_tween.tween_interval(0.42)
		drop_tween.tween_callback(_finish_offering_consumed.bind(sprite, offering, drop_position, ""))


func _get_grounded_offering_position(click_x: float, texture: Texture2D, sprite_scale: float) -> Vector2:
	var scaled_size := texture.get_size() * sprite_scale
	var half_size := scaled_size * 0.5
	var x := clampf(click_x, half_size.x + SAFE_CANVAS_MARGIN, float(_pet_window_size.x) - half_size.x - SAFE_CANVAS_MARGIN)
	var usable_bottom := float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	var y := usable_bottom - half_size.y - OFFERING_GROUND_MARGIN
	return _get_safe_sprite_position(Vector2(x, y), texture, sprite_scale, OFFERING_GROUND_MARGIN)


func _get_offering_target_pet(drop_x: float) -> Node2D:
	var nearest_pet: Node2D
	var nearest_distance := INF
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if pet.has_method("is_swallowed") and bool(pet.call("is_swallowed")):
			continue
		if _pending_offering_feeds.has(str(pet.get_instance_id())):
			continue
		var distance := absf(pet.position.x - drop_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_pet = pet
	return nearest_pet


func _send_pet_to_offering(target: Node2D, target_key: String, target_x: float) -> void:
	if target != null and is_instance_valid(target) and target.has_method("walk_to_offering_x"):
		target.call("walk_to_offering_x", target_x)
		return

	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var sprite := feed_data.get("sprite") as Sprite2D
	var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size.x * 0.5, _pet_window_size.y * 0.5))
	var actor := feed_data.get("target") as Node2D
	var pet_id := _get_actor_pet_id(actor) if actor != null and is_instance_valid(actor) else ""
	var offering: Dictionary = feed_data.get("offering", {})
	_finish_offering_consumed(sprite, offering, drop_position, pet_id)


func _update_pending_offerings() -> void:
	if _pending_offering_feeds.is_empty():
		return
	var now := _get_now_seconds()
	for target_key_value in _pending_offering_feeds.keys().duplicate():
		var target_key := String(target_key_value)
		var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
		if feed_data.is_empty():
			continue
		var actor := feed_data.get("target") as Node2D
		var expired := now >= float(feed_data.get("expires_at", now + OFFERING_FEED_TIMEOUT_SECONDS))
		if actor != null and is_instance_valid(actor) and not expired:
			continue

		_pending_offering_feeds.erase(target_key)
		var sprite := feed_data.get("sprite") as Sprite2D
		var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size) * 0.5)
		var pet_id := _get_actor_pet_id(actor) if actor != null and is_instance_valid(actor) else ""
		var offering: Dictionary = feed_data.get("offering", {})
		_finish_offering_consumed(sprite, offering, drop_position, pet_id)


func _mark_offering_landed(target_key: String) -> void:
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	feed_data["landed"] = true
	_pending_offering_feeds[target_key] = feed_data
	if bool(feed_data.get("arrived", false)):
		_consume_pending_offering(target_key)


func _on_pet_forced_target_reached(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var target_key := str(actor.get_instance_id())
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	if not bool(feed_data.get("landed", true)):
		feed_data["arrived"] = true
		_pending_offering_feeds[target_key] = feed_data
		return

	_consume_pending_offering(target_key)


func _consume_pending_offering(target_key: String) -> void:
	var feed_data: Dictionary = _pending_offering_feeds.get(target_key, {})
	if feed_data.is_empty():
		return

	_pending_offering_feeds.erase(target_key)
	var sprite := feed_data.get("sprite") as Sprite2D
	var drop_position: Vector2 = feed_data.get("drop_position", Vector2(_pet_window_size.x * 0.5, _pet_window_size.y * 0.5))
	var actor := feed_data.get("target") as Node2D
	var offering: Dictionary = feed_data.get("offering", {})
	if sprite == null or not is_instance_valid(sprite):
		var fallback_pet_id := _get_actor_pet_id(actor) if actor != null and is_instance_valid(actor) else ""
		_finish_offering_consumed(null, offering, drop_position, fallback_pet_id)
		return

	var actor_position := actor.position if actor != null and is_instance_valid(actor) else drop_position
	var pet_id := _get_actor_pet_id(actor) if actor != null and is_instance_valid(actor) else ""
	var eat_position := _get_safe_sprite_position(actor_position + Vector2(0.0, -30.0), sprite.texture, OFFERING_DROP_SCALE, SAFE_CANVAS_MARGIN)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", eat_position, 0.18)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * 0.12, 0.18)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.18)
	tween.tween_callback(_finish_offering_consumed.bind(sprite, offering, eat_position, pet_id))


func _finish_offering_consumed(
	sprite: Sprite2D,
	offering: Dictionary,
	popup_position: Vector2,
	pet_id := ""
) -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()

	if not pet_id.is_empty():
		_apply_pet_offering_buff(pet_id, offering)
		_react_pet_to_offering(pet_id)
		var offering_name := String(offering.get("name", "贡品"))
		_try_queue_news_event(
			"offering",
			{"item_name": offering_name},
			"offering:%s" % pet_id,
			24.0,
			0.72
		)
		_show_offering_buff_popup(popup_position, pet_id, offering)
	else:
		_show_status_popup(popup_position, "No pet collected the offering" if _language == "en" else "没有宠物接取贡品", Color(1.0, 0.68, 0.48, 1.0))
	_refresh_pet_stats(true)
	_save_game()


func _apply_pet_offering_buff(pet_id: String, offering: Dictionary) -> void:
	if pet_id.is_empty() or not _is_pet_unlocked(pet_id):
		return
	var multiplier := clampf(float(offering.get("multiplier", 1.0)), 1.0, 100.0)
	var duration_seconds := clampf(float(offering.get("duration_seconds", 60.0)), 1.0, 3600.0)
	if multiplier <= 1.0:
		return
	_pet_offering_buffs[pet_id] = {
		"multiplier": multiplier,
		"expires_at": _get_now_seconds() + duration_seconds,
		"offering_name": String(offering.get("name", "贡品")).strip_edges().left(40)
	}
	_pet_upgrade_stats_dirty = true


func _react_pet_to_offering(pet_id: String) -> void:
	var actor := _get_desktop_pet_by_id(pet_id)
	if actor != null:
		_clear_pet_runtime_effects(pet_id)
		_spawn_emotion(actor, "happy", Vector2(38.0, -10.0), 0.21, 0.0, true)


func _get_desktop_pet_by_id(pet_id: String) -> Node2D:
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		if _get_actor_pet_id(pet) == pet_id:
			return pet
	return null


func _show_offering_buff_popup(anchor: Vector2, pet_id: String, offering: Dictionary) -> void:
	var multiplier := maxf(1.0, float(offering.get("multiplier", 1.0)))
	var duration_seconds := maxi(1, int(round(float(offering.get("duration_seconds", 60.0)))))
	_show_status_popup(
		anchor,
		("%s  ×%s · %ds" if _language == "en" else "%s  ×%s · %d秒") % [
			_get_pet_display_name(pet_id),
			_format_multiplier(multiplier),
			duration_seconds
		],
		Color(0.88, 1.0, 0.64, 1.0)
	)


func _show_faith_change_popup(anchor: Vector2, amount: float) -> void:
	if is_zero_approx(amount):
		return
	var prefix := "+" if amount > 0.0 else "-"
	var color := Color(0.88, 1.0, 0.78, 1.0) if amount > 0.0 else Color(1.0, 0.58, 0.46, 1.0)
	_show_status_popup(
		anchor,
		("%s%s FAITH" if _language == "en" else "%s%s 信仰") % [prefix, _format_faith_amount(absf(amount))],
		color
	)


func _show_coin_change_popup(anchor: Vector2, amount: int, coin_type := "") -> void:
	if amount == 0:
		return
	var prefix := "+" if amount > 0 else "-"
	var type_hint := (
		" %s" % CoinDrop.get_drop_label(coin_type, _language)
		if not coin_type.is_empty() and amount > 0
		else ""
	)
	var color := Color(1.0, 0.84, 0.32, 1.0) if amount > 0 else Color(1.0, 0.58, 0.46, 1.0)
	if amount > 0:
		match coin_type:
			"C":
				color = Color(0.94, 0.47, 0.28, 1.0)
			"S":
				color = Color(0.78, 0.86, 0.94, 1.0)
			"G":
				color = Color(1.0, 0.92, 0.24, 1.0)
	_show_status_popup(
		anchor,
		("%s$%d GOLD%s" if _language == "en" else "%s$%d 金币%s") % [prefix, absi(amount), type_hint],
		color
	)


func _show_status_popup(anchor: Vector2, text_value: String, color: Color) -> void:
	if not is_inside_tree():
		return
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(280.0, 34.0)
	label.position = _get_safe_control_position(anchor + Vector2(-140.0, -96.0), label.size, SAFE_CANVAS_MARGIN)
	label.z_index = 360
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", _get_safe_control_position(label.position + Vector2(0.0, -28.0), label.size, SAFE_CANVAS_MARGIN), 0.58)
	tween.parallel().tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.58)
	tween.tween_callback(Callable(label, "queue_free"))


static func _format_multiplier(value: float) -> String:
	var text := String.num(maxf(1.0, value), 2)
	while text.contains(".") and text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text


static func _format_faith_amount(value: float) -> String:
	var safe_value := maxf(0.0, value) if is_finite(value) else 0.0
	if safe_value >= 1.0e18:
		return "%.2e" % safe_value
	var units := [
		{"threshold": 1.0e15, "suffix": "Qa"},
		{"threshold": 1.0e12, "suffix": "T"},
		{"threshold": 1.0e9, "suffix": "B"},
		{"threshold": 1.0e6, "suffix": "M"},
		{"threshold": 1.0e3, "suffix": "K"}
	]
	for unit in units:
		var threshold := float(unit.get("threshold", 1.0))
		if safe_value >= threshold:
			var scaled := safe_value / threshold
			return "%.0f%s" % [scaled, String(unit.get("suffix", ""))] if scaled >= 100.0 else "%.1f%s" % [scaled, String(unit.get("suffix", ""))]
	return "%.0f" % safe_value if safe_value >= 10.0 else String.num(safe_value, 2)


func _get_safe_control_position(raw_position: Vector2, size: Vector2, margin: float) -> Vector2:
	var right := float(_pet_window_size.x) - size.x - margin
	var bottom := float(_pet_window_size.y) - size.y - margin
	raw_position.x = clampf(raw_position.x, margin, maxf(margin, right))
	raw_position.y = clampf(raw_position.y, margin, maxf(margin, bottom))
	return raw_position


# Upgrade and global commands
func _on_pet_upgrade_requested(pet_id: String) -> void:
	if pet_id.is_empty() or not _is_pet_unlocked(pet_id):
		return
	var state := _get_pet_state(pet_id)
	if PetProgression.progression_level(state) >= PetProgression.MAX_LEVEL:
		_refresh_pet_stats(true)
		return
	var cost := _get_upgrade_cost(pet_id)
	if int(floor(_faith_points)) < cost:
		_refresh_pet_stats(true)
		return

	_faith_points = maxf(0.0, _faith_points - float(cost))
	state["upgrade_level"] = clampi(
		PetProgression.progression_level(state) + 1,
		1,
		PetProgression.MAX_LEVEL
	)
	_selected_pet_id = pet_id
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_try_queue_news_event(
		"upgrade",
		{"level": PetProgression.progression_level(state)},
		"upgrade:%s" % pet_id,
		40.0,
		0.45
	)
	_save_game()


func _on_faith_add_requested(amount: int) -> void:
	var faith_gain := _get_manual_faith_click_gain(amount)
	_grant_faith(faith_gain)
	_show_faith_change_popup(_get_window_mouse_position(get_window()), faith_gain)
	_refresh_pet_stats(true)
	_save_game()


func _on_menu_handle_moved(anchor: float) -> void:
	_loaded_menu_handle_anchor = clampf(anchor, 0.0, 1.0)
	_save_game()


func _on_activity_range_changed(range_mode: String) -> void:
	if range_mode not in ["full", "right", "left"]:
		return
	_pet_activity_range = range_mode
	_update_actor_window_bounds()
	_save_game()


func _on_debug_economy_requested(faith_points: float, gold_coins: int) -> void:
	_faith_points = clampf(faith_points, 0.0, 1_000_000_000_000_000.0)
	_lifetime_faith = maxf(_lifetime_faith, _faith_points)
	_gold_coins = clampi(gold_coins, 0, 1_000_000_000_000_000)
	_pet_upgrade_stats_dirty = true
	_refresh_pet_stats(true)
	_refresh_faith_display()
	_refresh_coin_display()
	_sync_shop_state()
	if _settings_window != null and _settings_window.has_method("refresh_debug_values"):
		_settings_window.call(
			"refresh_debug_values",
			_faith_points,
			_gold_coins,
			_debug_enemy_power_scale,
			_debug_game_speed
		)
	_save_game()


func _on_debug_simulation_requested(enemy_power_scale: float, game_speed: float) -> void:
	_debug_enemy_power_scale = clampf(enemy_power_scale, 0.0, 1_000_000_000_000_000.0)
	_debug_game_speed = clampf(game_speed, 0.1, 20.0)
	Engine.time_scale = _debug_game_speed
	if _settings_window != null and _settings_window.has_method("refresh_debug_values"):
		_settings_window.call(
			"refresh_debug_values",
			_faith_points,
			_gold_coins,
			_debug_enemy_power_scale,
			_debug_game_speed
		)


func _on_debug_event_requested(event_type: String) -> void:
	if event_type not in ["pilgrimage", "battle"]:
		return
	if _event_invitation != null and is_instance_valid(_event_invitation):
		_event_invitation.queue_free()
	_event_invitation = null
	_pending_battle_difficulty_scale = -1.0
	if _pilgrimage_active:
		_finish_pilgrimage(false)
	if _battle_active:
		_finish_battle(true)
	_spawn_event_invitation(event_type)


func _on_language_changed(language_code: String) -> void:
	_language = "en" if language_code == "en" else "zh"
	_apply_language()
	_save_game()


func _apply_language() -> void:
	TranslationServer.set_locale(_language)
	if _side_drawer != null and _side_drawer.has_method("set_language"):
		_side_drawer.call("set_language", _language)
	if _settings_window != null and _settings_window.has_method("set_language"):
		_settings_window.call("set_language", _language)
	if _shop_window != null and _shop_window.has_method("set_language"):
		_shop_window.call("set_language", _language)
	if _gacha_window != null and _gacha_window.has_method("set_language"):
		_gacha_window.call("set_language", _language)
	if _inventory_window != null and _inventory_window.has_method("set_language"):
		_inventory_window.call("set_language", _language)
	if _news_window != null and _news_window.has_method("set_language"):
		_news_window.call("set_language", _language)
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_language"):
			pet.call("set_language", _language)
	_last_era_display = ""
	_refresh_era_display(true)


func _get_manual_faith_click_gain(base_amount := 1) -> float:
	var passive_scaled_gain := _get_faith_growth_rate() * MANUAL_CLICK_RATE_SECONDS
	if not is_finite(passive_scaled_gain):
		passive_scaled_gain = 0.0
	return maxf(float(maxi(1, base_amount)), passive_scaled_gain)


func _on_quit_requested() -> void:
	_save_game()
	get_tree().quit()
