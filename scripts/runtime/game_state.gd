extends RefCounted

const NewsFeed = preload("res://scripts/domain/news_feed.gd")

var _pets: Array[Node2D] = []
var _turrets: Array[Node2D] = []
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
var _pet_window_size := Vector2i(820, 420)
var _rng := RandomNumberGenerator.new()
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
var _battle_pet_enemy_targets := {}
var _battle_pet5_rolls := {}
var _battle_turret_health := {}
var _battle_turret_max_health := {}
var _battle_turret_attack_at := {}
var _battle_turret_enemy_targets := {}
var _battle_save_pending := false
var _battle_defeated_enemies := 0
var _battle_dropped_coin_budget := 0
var _pending_battle_difficulty_scale := -1.0
var _active_battle_difficulty_scale := -1.0
var _last_era_display := ""
var _era_floor_index := 0
var _debug_era_preview_index := -1
var _recovery_ui_refresh_time := 0.0
var _smoke_frames: SpriteFrames
var _inventory_window: Window
var _evolution_window: Window
var _pending_evolution_notifications: Array[String] = []
var _shop_window: Window
var _gacha_window: Window
var _news_window: Window
var _settings_window: Window
var _completion_window: Window
var _follower_count := 0.0
var _last_reported_follower_count := -1
var _shop_owned_counts := {}
var _turret_states := {}
var _side_drawer: Node
var _lifetime_faith := 0.0
var _gold_coins := 0
var _gacha_draw_count := 0
var _gacha_pity_count := 0
var _gacha_history: Array[Dictionary] = []
var _gacha_batch_active := false
var _gacha_batch_token := 0
var _gacha_batch_state: Dictionary = {}
var _autosave_timer := 0.0
var _save_dirty := false
var _save_debounce_remaining := 0.0
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
var _background_logic_time := 0.0
var _pointer_hover_time := 0.0
var _session_runtime_seconds := 0.0
var _total_runtime_seconds := 0.0
var _playtime_refresh_timer := 0.0
var _pet_activity_range := "full"
var _language := "en"
var _debug_enemy_power_scale := 1.0
var _debug_game_speed := 1.0
var _simulation_now_seconds := 0.0
var _background_faith_growth_cache_active := false
var _background_faith_growth_cache := 0.0
var _campaign_completed := false
var _campaign_completion_acknowledged := false
var _final_boss_defeated := false
var _endless_mode := false
var _reset_in_progress := false
