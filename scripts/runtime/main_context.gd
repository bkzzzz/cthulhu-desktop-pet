extends Node2D

const GameState = preload("res://scripts/runtime/game_state.gd")
# Dependencies
const PetCatalog = preload("res://scripts/pet_catalog.gd")
const PetProgression = preload("res://scripts/domain/pet_progression.gd")
const FollowerProgression = preload("res://scripts/domain/follower_progression.gd")
const GachaProgression = preload("res://scripts/domain/gacha_progression.gd")
const NewsFeed = preload("res://scripts/domain/news_feed.gd")
const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const EraProgression = preload("res://scripts/domain/era_progression.gd")
const EconomyBalance = preload("res://scripts/domain/economy_balance.gd")
const BattleBalance = preload("res://scripts/domain/battle_balance.gd")
const DesktopPetActor = preload("res://scripts/desktop_pet_actor.gd")
const BelieverActor = preload("res://scripts/believer_actor.gd")
const EnemyActor = preload("res://scripts/enemy_actor.gd")
const EnemyProjectileActor = preload("res://scripts/enemy_projectile_actor.gd")
const BattleEffectActor = preload("res://scripts/battle_effect_actor.gd")
const EventInvitation = preload("res://scripts/event_invitation.gd")
const InventoryWindowScript = preload("res://scripts/inventory_window.gd")
const EvolutionWindowScript = preload("res://scripts/evolution_window.gd")
const ShopWindowScript = preload("res://scripts/shop_window.gd")
const GachaWindowScript = preload("res://scripts/gacha_window.gd")
const NewsWindowScript = preload("res://scripts/news_window.gd")
const SettingsWindowScript = preload("res://scripts/settings_window.gd")
const CompletionWindowScript = preload("res://scripts/completion_window.gd")
const SideDrawerController = preload("res://scripts/side_drawer_controller.gd")
const NativeVisualClickthrough = preload("res://scripts/native_visual_clickthrough.gd")
const CoinDrop = preload("res://scripts/coin_drop.gd")
const LanguageSettings = preload("res://scripts/domain/language_settings.gd")

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
const UI_REFRESH_INTERVAL := 0.25
# Two deliberate clicks per second add about 8% to passive production. This
# keeps petting useful without letting autoclick-style input erase the campaign.
const MANUAL_CLICK_RATE_SECONDS := 0.04
# Large gacha requests are resolved incrementally. The hard chunk ceiling keeps
# work deterministic, while the time budget protects slower machines/assets.
const GACHA_BATCH_MAX_DRAWS_PER_FRAME := 128
const GACHA_BATCH_FRAME_BUDGET_USEC := 1800
const GACHA_BATCH_BUDGET_CHECK_INTERVAL := 16
const SAVE_PATH := "user://cthulu_save.cfg"
const SAVE_VERSION := 12
const PET_UNLOCK_SAVE_VERSION := 8
const NEWS_RATE_MODEL_SAVE_VERSION := 5
const AUTOSAVE_INTERVAL_SECONDS := 30.0
const SAVE_DEBOUNCE_SECONDS := 0.45
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
const BATTLE_UNLOCK_RUNTIME_SECONDS := 60.0
const BATTLE_INITIAL_DELAY_MIN_SECONDS := 35.0
const BATTLE_INITIAL_DELAY_MAX_SECONDS := 70.0
const BATTLE_INTERVAL_MIN_SECONDS := 8.0
const BATTLE_INTERVAL_MAX_SECONDS := 18.0
const BATTLE_DECLINED_DELAY_MIN_SECONDS := 75.0
const BATTLE_DECLINED_DELAY_MAX_SECONDS := 135.0
const BATTLE_DURATION_SECONDS := 55.0
const BATTLE_DIFFICULTY_VARIANCE_MIN := 0.90
const BATTLE_DIFFICULTY_VARIANCE_MAX := 1.16
const BATTLE_DRAG_HINT_EN := "Melee pets charge automatically; drag them forward to shield the ranged line"
const BATTLE_DRAG_HINT_ZH := "近战宠物会自动冲锋；拖动宠物到前线可以保护后排远程宠物"
const BATTLE_PET_RECOVERY_MIN_SECONDS := 75.0
const BATTLE_PET_RECOVERY_MAX_SECONDS := 180.0
const BATTLE_EFFECT_LIMIT := 28
const SMOKE_SHEET_TEXTURE := "res://assets/effects/smoke/smoke1_sheet.png"
const SMOKE_FRAME_COUNT := 10
const RANGED_BATTLE_PET_IDS := ["pet2", "pet7", "pet8", "pet9", "pet10"]
const MELEE_BATTLE_HEALTH_MULTIPLIER := 1.65
const RANGED_BATTLE_HEALTH_MULTIPLIER := 0.88
const MELEE_BATTLE_CHASE_SPEED := 285.0
const PET5_BATTLE_CHASE_SPEED := 335.0
const PET5_ROLL_OVERSHOOT := 82.0
const PET5_ROLL_HIT_RADIUS := 48.0
const PET5_ROLL_SPEED := 760.0

# Runtime actors and input state

# Shared runtime context
var _state: GameState = GameState.new()
var _host: Variant = self

func share_context(state_value: GameState, host_value: Variant) -> void:
	_state = state_value
	_host = host_value

# Compatibility properties keep the existing Main API stable while state lives in GameState.
var _pets: Array[Node2D]:
	get: return _state._pets
	set(value): _state._pets = value
var _believers: Array[Node2D]:
	get: return _state._believers
	set(value): _state._believers = value
var _coin_drops: Array[Node2D]:
	get: return _state._coin_drops
	set(value): _state._coin_drops = value
var _hovered_pet: Node2D:
	get: return _state._hovered_pet
	set(value): _state._hovered_pet = value
var _active_emotions: Dictionary:
	get: return _state._active_emotions
	set(value): _state._active_emotions = value
var _active_emotion_tweens: Dictionary:
	get: return _state._active_emotion_tweens
	set(value): _state._active_emotion_tweens = value
var _next_emotion_allowed_at: Dictionary:
	get: return _state._next_emotion_allowed_at
	set(value): _state._next_emotion_allowed_at = value
var _next_ambient_emotion_at: Dictionary:
	get: return _state._next_ambient_emotion_at
	set(value): _state._next_ambient_emotion_at = value
var _carried_offering: Dictionary:
	get: return _state._carried_offering
	set(value): _state._carried_offering = value
var _current_cursor_texture: Texture2D:
	get: return _state._current_cursor_texture
	set(value): _state._current_cursor_texture = value
var _offering_cursor_texture: Texture2D:
	get: return _state._offering_cursor_texture
	set(value): _state._offering_cursor_texture = value
var _offering_cursor_path: String:
	get: return _state._offering_cursor_path
	set(value): _state._offering_cursor_path = value
var _offering_cursor_size: Vector2i:
	get: return _state._offering_cursor_size
	set(value): _state._offering_cursor_size = value
var _offering_cursor_active: bool:
	get: return _state._offering_cursor_active
	set(value): _state._offering_cursor_active = value
var _offering_input_window: Window:
	get: return _state._offering_input_window
	set(value): _state._offering_input_window = value
var _offering_input_area: Control:
	get: return _state._offering_input_area
	set(value): _state._offering_input_area = value
var _pending_offering_feeds: Dictionary:
	get: return _state._pending_offering_feeds
	set(value): _state._pending_offering_feeds = value
var _pet_offering_buffs: Dictionary:
	get: return _state._pet_offering_buffs
	set(value): _state._pet_offering_buffs = value
var _position_retry_frames: int:
	get: return _state._position_retry_frames
	set(value): _state._position_retry_frames = value
var _pet_window_size:
	get: return _state._pet_window_size
	set(value): _state._pet_window_size = value
var _rng: RandomNumberGenerator:
	get: return _state._rng
	set(value): _state._rng = value
var _selected_pet_id: String:
	get: return _state._selected_pet_id
	set(value): _state._selected_pet_id = value
var _pet_states: Dictionary:
	get: return _state._pet_states
	set(value): _state._pet_states = value
var _unlocked_pet_ids: Array[String]:
	get: return _state._unlocked_pet_ids
	set(value): _state._unlocked_pet_ids = value
var _deployed_pet_ids: Array[String]:
	get: return _state._deployed_pet_ids
	set(value): _state._deployed_pet_ids = value
var _faith_points: float:
	get: return _state._faith_points
	set(value): _state._faith_points = value
var _stats_refresh_timer: float:
	get: return _state._stats_refresh_timer
	set(value): _state._stats_refresh_timer = value
var _last_reported_faith_count: int:
	get: return _state._last_reported_faith_count
	set(value): _state._last_reported_faith_count = value
var _last_reported_growth_rate: float:
	get: return _state._last_reported_growth_rate
	set(value): _state._last_reported_growth_rate = value
var _pet_upgrade_stats_dirty: bool:
	get: return _state._pet_upgrade_stats_dirty
	set(value): _state._pet_upgrade_stats_dirty = value
var _next_believer_spawn_at: float:
	get: return _state._next_believer_spawn_at
	set(value): _state._next_believer_spawn_at = value
var _last_believer_spawn_at: float:
	get: return _state._last_believer_spawn_at
	set(value): _state._last_believer_spawn_at = value
var _pilgrimage_active: bool:
	get: return _state._pilgrimage_active
	set(value): _state._pilgrimage_active = value
var _pilgrimage_ends_at: float:
	get: return _state._pilgrimage_ends_at
	set(value): _state._pilgrimage_ends_at = value
var _next_pilgrimage_at: float:
	get: return _state._next_pilgrimage_at
	set(value): _state._next_pilgrimage_at = value
var _event_invitation: Node2D:
	get: return _state._event_invitation
	set(value): _state._event_invitation = value
var _battle_active: bool:
	get: return _state._battle_active
	set(value): _state._battle_active = value
var _battle_started_at: float:
	get: return _state._battle_started_at
	set(value): _state._battle_started_at = value
var _battle_ends_at: float:
	get: return _state._battle_ends_at
	set(value): _state._battle_ends_at = value
var _next_battle_at: float:
	get: return _state._next_battle_at
	set(value): _state._next_battle_at = value
var _battle_enemies: Array[Node2D]:
	get: return _state._battle_enemies
	set(value): _state._battle_enemies = value
var _battle_effects: Array[Node2D]:
	get: return _state._battle_effects
	set(value): _state._battle_effects = value
var _battle_wave_schedule: Array[Dictionary]:
	get: return _state._battle_wave_schedule
	set(value): _state._battle_wave_schedule = value
var _battle_next_wave_index: int:
	get: return _state._battle_next_wave_index
	set(value): _state._battle_next_wave_index = value
var _battle_pet_health: Dictionary:
	get: return _state._battle_pet_health
	set(value): _state._battle_pet_health = value
var _battle_pet_max_health: Dictionary:
	get: return _state._battle_pet_max_health
	set(value): _state._battle_pet_max_health = value
var _battle_pet_attack_at: Dictionary:
	get: return _state._battle_pet_attack_at
	set(value): _state._battle_pet_attack_at = value
var _battle_pet_target_x: Dictionary:
	get: return _state._battle_pet_target_x
	set(value): _state._battle_pet_target_x = value
var _battle_pet_formed: Dictionary:
	get: return _state._battle_pet_formed
	set(value): _state._battle_pet_formed = value
var _battle_pet_enemy_targets: Dictionary:
	get: return _state._battle_pet_enemy_targets
	set(value): _state._battle_pet_enemy_targets = value
var _battle_pet5_rolls: Dictionary:
	get: return _state._battle_pet5_rolls
	set(value): _state._battle_pet5_rolls = value
var _battle_save_pending: bool:
	get: return _state._battle_save_pending
	set(value): _state._battle_save_pending = value
var _battle_defeated_enemies: int:
	get: return _state._battle_defeated_enemies
	set(value): _state._battle_defeated_enemies = value
var _battle_dropped_coin_budget: int:
	get: return _state._battle_dropped_coin_budget
	set(value): _state._battle_dropped_coin_budget = value
var _pending_battle_difficulty_scale: float:
	get: return _state._pending_battle_difficulty_scale
	set(value): _state._pending_battle_difficulty_scale = value
var _active_battle_difficulty_scale: float:
	get: return _state._active_battle_difficulty_scale
	set(value): _state._active_battle_difficulty_scale = value
var _last_era_display: String:
	get: return _state._last_era_display
	set(value): _state._last_era_display = value
var _recovery_ui_refresh_time: float:
	get: return _state._recovery_ui_refresh_time
	set(value): _state._recovery_ui_refresh_time = value
var _smoke_frames: SpriteFrames:
	get: return _state._smoke_frames
	set(value): _state._smoke_frames = value
var _inventory_window: Window:
	get: return _state._inventory_window
	set(value): _state._inventory_window = value
var _evolution_window: Window:
	get: return _state._evolution_window
	set(value): _state._evolution_window = value
var _pending_evolution_notifications: Array[String]:
	get: return _state._pending_evolution_notifications
	set(value): _state._pending_evolution_notifications = value
var _shop_window: Window:
	get: return _state._shop_window
	set(value): _state._shop_window = value
var _gacha_window: Window:
	get: return _state._gacha_window
	set(value): _state._gacha_window = value
var _news_window: Window:
	get: return _state._news_window
	set(value): _state._news_window = value
var _settings_window: Window:
	get: return _state._settings_window
	set(value): _state._settings_window = value
var _completion_window: Window:
	get: return _state._completion_window
	set(value): _state._completion_window = value
var _follower_count: float:
	get: return _state._follower_count
	set(value): _state._follower_count = value
var _last_reported_follower_count: int:
	get: return _state._last_reported_follower_count
	set(value): _state._last_reported_follower_count = value
var _shop_owned_counts: Dictionary:
	get: return _state._shop_owned_counts
	set(value): _state._shop_owned_counts = value
var _side_drawer: Node:
	get: return _state._side_drawer
	set(value): _state._side_drawer = value
var _lifetime_faith: float:
	get: return _state._lifetime_faith
	set(value): _state._lifetime_faith = value
var _gold_coins: int:
	get: return _state._gold_coins
	set(value): _state._gold_coins = value
var _gacha_draw_count: int:
	get: return _state._gacha_draw_count
	set(value): _state._gacha_draw_count = value
var _gacha_pity_count: int:
	get: return _state._gacha_pity_count
	set(value): _state._gacha_pity_count = value
var _gacha_history: Array[Dictionary]:
	get: return _state._gacha_history
	set(value): _state._gacha_history = value
var _gacha_batch_active: bool:
	get: return _state._gacha_batch_active
	set(value): _state._gacha_batch_active = value
var _gacha_batch_token: int:
	get: return _state._gacha_batch_token
	set(value): _state._gacha_batch_token = value
var _gacha_batch_state: Dictionary:
	get: return _state._gacha_batch_state
	set(value): _state._gacha_batch_state = value
var _autosave_timer: float:
	get: return _state._autosave_timer
	set(value): _state._autosave_timer = value
var _save_dirty: bool:
	get: return _state._save_dirty
	set(value): _state._save_dirty = value
var _save_debounce_remaining: float:
	get: return _state._save_debounce_remaining
	set(value): _state._save_debounce_remaining = value
var _loaded_save_unix: float:
	get: return _state._loaded_save_unix
	set(value): _state._loaded_save_unix = value
var _loaded_menu_handle_anchor: float:
	get: return _state._loaded_menu_handle_anchor
	set(value): _state._loaded_menu_handle_anchor = value
var _persistence_enabled: bool:
	get: return _state._persistence_enabled
	set(value): _state._persistence_enabled = value
var _news_feed: NewsFeed:
	get: return _state._news_feed
	set(value): _state._news_feed = value
var _loaded_news_state: Dictionary:
	get: return _state._loaded_news_state
	set(value): _state._loaded_news_state = value
var _news_broadcast_panel: PanelContainer:
	get: return _state._news_broadcast_panel
	set(value): _state._news_broadcast_panel = value
var _news_broadcast_label: Label:
	get: return _state._news_broadcast_label
	set(value): _state._news_broadcast_label = value
var _news_broadcast_queue: Array[Dictionary]:
	get: return _state._news_broadcast_queue
	set(value): _state._news_broadcast_queue = value
var _news_broadcast_tween: Tween:
	get: return _state._news_broadcast_tween
	set(value): _state._news_broadcast_tween = value
var _news_broadcast_active: bool:
	get: return _state._news_broadcast_active
	set(value): _state._news_broadcast_active = value
var _pilgrimage_broadcast_panel: PanelContainer:
	get: return _state._pilgrimage_broadcast_panel
	set(value): _state._pilgrimage_broadcast_panel = value
var _pilgrimage_broadcast_title: Label:
	get: return _state._pilgrimage_broadcast_title
	set(value): _state._pilgrimage_broadcast_title = value
var _pilgrimage_broadcast_subtitle: Label:
	get: return _state._pilgrimage_broadcast_subtitle
	set(value): _state._pilgrimage_broadcast_subtitle = value
var _pilgrimage_status_label: Label:
	get: return _state._pilgrimage_status_label
	set(value): _state._pilgrimage_status_label = value
var _pilgrimage_broadcast_tween: Tween:
	get: return _state._pilgrimage_broadcast_tween
	set(value): _state._pilgrimage_broadcast_tween = value
var _news_story_backlog: Array[Dictionary]:
	get: return _state._news_story_backlog
	set(value): _state._news_story_backlog = value
var _next_news_at: float:
	get: return _state._next_news_at
	set(value): _state._next_news_at = value
var _news_milestone_check_timer: float:
	get: return _state._news_milestone_check_timer
	set(value): _state._news_milestone_check_timer = value
var _next_pet_coin_drop_at: Dictionary:
	get: return _state._next_pet_coin_drop_at
	set(value): _state._next_pet_coin_drop_at = value
var _pet_coin_drop_intervals: Dictionary:
	get: return _state._pet_coin_drop_intervals
	set(value): _state._pet_coin_drop_intervals = value
var _background_logic_time: float:
	get: return _state._background_logic_time
	set(value): _state._background_logic_time = value
var _pointer_hover_time: float:
	get: return _state._pointer_hover_time
	set(value): _state._pointer_hover_time = value
var _session_runtime_seconds: float:
	get: return _state._session_runtime_seconds
	set(value): _state._session_runtime_seconds = value
var _total_runtime_seconds: float:
	get: return _state._total_runtime_seconds
	set(value): _state._total_runtime_seconds = value
var _settings_refresh_timer: float:
	get: return _state._settings_refresh_timer
	set(value): _state._settings_refresh_timer = value
var _pet_activity_range: String:
	get: return _state._pet_activity_range
	set(value): _state._pet_activity_range = value
var _language: String:
	get: return _state._language
	set(value): _state._language = value
var _debug_enemy_power_scale: float:
	get: return _state._debug_enemy_power_scale
	set(value): _state._debug_enemy_power_scale = value
var _debug_game_speed: float:
	get: return _state._debug_game_speed
	set(value): _state._debug_game_speed = value
var _simulation_now_seconds: float:
	get: return _state._simulation_now_seconds
	set(value): _state._simulation_now_seconds = value
var _background_faith_growth_cache_active: bool:
	get: return _state._background_faith_growth_cache_active
	set(value): _state._background_faith_growth_cache_active = value
var _background_faith_growth_cache: float:
	get: return _state._background_faith_growth_cache
	set(value): _state._background_faith_growth_cache = value
var _campaign_completed: bool:
	get: return _state._campaign_completed
	set(value): _state._campaign_completed = value
var _campaign_completion_acknowledged: bool:
	get: return _state._campaign_completion_acknowledged
	set(value): _state._campaign_completion_acknowledged = value
var _endless_mode: bool:
	get: return _state._endless_mode
	set(value): _state._endless_mode = value
var _reset_in_progress: bool:
	get: return _state._reset_in_progress
	set(value): _state._reset_in_progress = value

# Small deterministic helpers remain inherited for source and test compatibility.
static func _get_enemy_launch_direction() -> float:
	return -1.0

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

static func _get_news_broadcast_hold_seconds(headline: String) -> float:
	return clampf(5.5 + (float(headline.length()) * 0.04), 6.0, 9.0)

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
