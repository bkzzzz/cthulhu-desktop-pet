extends "res://scripts/runtime/main_context.gd"

const ENCOUNTER_REWARD_KEY := "_encounter_reward_budget"
const ENCOUNTER_DIFFICULTY_KEY := "_encounter_difficulty_scale"

var _pilgrimage_total_member_count := 0
var _pilgrimage_resolved_count := 0
var _pilgrimage_faith_earned := 0.0
var _pilgrimage_gold_dropped := 0

func _update_believers() -> void:
	_cleanup_believers()
	var threat_positions = _get_believer_threat_positions()
	for believer in _believers:
		if is_instance_valid(believer) and believer.has_method("set_threat_positions"):
			believer.call("set_threat_positions", threat_positions)
	if _pilgrimage_active or _battle_active:
		return

	var now = _host._get_now_seconds()
	if now < _next_believer_spawn_at:
		return

	if _believers.size() >= BELIEVER_MAX_ACTIVE:
		_schedule_next_believer_spawn(now)
		return

	var available_slots = BELIEVER_MAX_ACTIVE - _believers.size()
	var spawn_count = 1
	if available_slots >= 2 and _rng.randf() < BELIEVER_SECOND_SPAWN_CHANCE:
		spawn_count = 2
	for _spawn_index in mini(spawn_count, available_slots):
		_spawn_believer(false)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)

func _schedule_next_believer_spawn(now: float) -> void:
	var random_delay = _rng.randf_range(BELIEVER_SPAWN_MIN_SECONDS, BELIEVER_SPAWN_MAX_SECONDS)
	var time_since_last_spawn = maxf(0.0, now - _last_believer_spawn_at)
	var force_delay = maxf(BELIEVER_SPAWN_MIN_SECONDS, BELIEVER_FORCE_SPAWN_SECONDS - time_since_last_spawn)
	_next_believer_spawn_at = now + minf(random_delay, force_delay)

func _spawn_believer(visible_on_spawn := false) -> void:
	var believer: Node2D = BelieverActor.new()
	var spawn_from_left: bool = _rng.randf() < 0.5
	var ground_contact_y = float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	if visible_on_spawn and believer.has_method("setup_visible"):
		believer.call("setup_visible", _pet_window_size, ground_contact_y)
	else:
		believer.call("setup", _pet_window_size, spawn_from_left, ground_contact_y)
	believer.connect("exited", Callable(_host, "_on_believer_exited"))
	believer.connect("scared_away", Callable(_host, "_on_believer_scared_away"))
	believer.connect("prayed", Callable(_host, "_on_believer_prayed"))
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
	var delay_min = PILGRIMAGE_INITIAL_DELAY_MIN_SECONDS if initial else PILGRIMAGE_INTERVAL_MIN_SECONDS
	var delay_max = PILGRIMAGE_INITIAL_DELAY_MAX_SECONDS if initial else PILGRIMAGE_INTERVAL_MAX_SECONDS
	_next_pilgrimage_at = now + _rng.randf_range(delay_min, delay_max)

func _update_pilgrimage() -> void:
	var now = _host._get_now_seconds()
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
		if (
			_next_battle_at > 0.0
			and _next_battle_at <= now + BATTLE_INVITATION_RESERVATION_SECONDS
		):
			_next_pilgrimage_at = now + 60.0
			return
		if _has_valid_desktop_pet() and _event_invitation == null:
			_spawn_event_invitation("pilgrimage")
		else:
			_next_pilgrimage_at = now + 60.0

func _schedule_next_battle(now: float, initial := false) -> void:
	var delay_min = BATTLE_INITIAL_DELAY_MIN_SECONDS if initial else BATTLE_INTERVAL_MIN_SECONDS
	var delay_max = BATTLE_INITIAL_DELAY_MAX_SECONDS if initial else BATTLE_INTERVAL_MAX_SECONDS
	_next_battle_at = now + _rng.randf_range(delay_min, delay_max)


func _schedule_declined_battle(now: float) -> void:
	_next_battle_at = now + _rng.randf_range(
		BATTLE_DECLINED_DELAY_MIN_SECONDS,
		BATTLE_DECLINED_DELAY_MAX_SECONDS
	)


func _queue_final_boss_invitation() -> void:
	if _battle_active or _pilgrimage_active:
		return
	var now: float = float(_host._get_now_seconds())
	if _next_battle_at <= 0.0 or _next_battle_at > now + 1.0:
		_next_battle_at = now

func _update_event_invitations() -> void:
	_host._refresh_era_display()
	if _battle_active or _pilgrimage_active:
		return
	if _event_invitation != null and not is_instance_valid(_event_invitation):
		_event_invitation = null
		_pending_battle_difficulty_scale = -1.0
		_battle_wave_schedule.clear()
	if _event_invitation != null:
		return
	if _total_runtime_seconds < BATTLE_UNLOCK_RUNTIME_SECONDS:
		return
	var now = _host._get_now_seconds()
	if _next_battle_at <= 0.0:
		_schedule_next_battle(now, true)
	elif now >= _next_battle_at and _has_valid_desktop_pet():
		_spawn_event_invitation("battle")

func _spawn_event_invitation(event_type: String) -> void:
	if _event_invitation != null or _battle_active or _pilgrimage_active:
		return
	if event_type != "battle":
		_pending_battle_difficulty_scale = -1.0
		_battle_wave_schedule.clear()
	var invite: Node2D = EventInvitation.new()
	var texture_path = BATTLE_INVITE_TEXTURE if event_type == "battle" else PILGRIMAGE_INVITE_TEXTURE
	var difficulty_text = ""
	var difficulty_text_en = ""
	var difficulty_text_zh = ""
	if event_type == "battle":
		_battle_wave_schedule = (
			BattleBalance.build_final_boss_schedule()
			if _host._should_offer_final_boss()
			else BattleBalance.build_wave_schedule(
				EraProgression.get_wave_schedule(_get_era_runtime_seconds()),
				EconomyBalance.average_level(_deployed_pet_ids, _pet_states),
				_host._is_endless_mode()
			)
		)
		_pending_battle_difficulty_scale = _host._roll_battle_difficulty_scale()
		var reward_budget: Dictionary = _host._get_battle_reward_budget(
			_pending_battle_difficulty_scale
		)
		if not _battle_wave_schedule.is_empty():
			_battle_wave_schedule[0][ENCOUNTER_DIFFICULTY_KEY] = _pending_battle_difficulty_scale
			_battle_wave_schedule[0][ENCOUNTER_REWARD_KEY] = reward_budget.duplicate(true)
		difficulty_text_en = _host._get_battle_difficulty_text(_pending_battle_difficulty_scale, "en")
		difficulty_text_zh = _host._get_battle_difficulty_text(_pending_battle_difficulty_scale, "zh")
		difficulty_text = difficulty_text_en if _language == "en" else difficulty_text_zh
	var safe_margin = 120.0
	var spawn_x = _rng.randf_range(
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
		difficulty_text,
		difficulty_text_en,
		difficulty_text_zh
	)
	invite.connect("accepted", Callable(self, "_on_event_invitation_accepted"))
	invite.connect("discarded", Callable(self, "_on_event_invitation_discarded"))
	invite.connect("expired", Callable(self, "_on_event_invitation_expired"))
	add_child(invite)
	_event_invitation = invite
	if event_type == "battle":
		_host.call_deferred("_warm_battle_assets", _battle_wave_schedule.duplicate(true))

func _on_event_invitation_accepted(event_type: String) -> void:
	_event_invitation = null
	if event_type == "battle":
		_active_battle_difficulty_scale = (
			_pending_battle_difficulty_scale
			if _pending_battle_difficulty_scale >= 0.0
			else _host._roll_battle_difficulty_scale()
		)
		_pending_battle_difficulty_scale = -1.0
		_host._start_battle()
	else:
		_start_pilgrimage()

func _on_event_invitation_discarded(event_type: String) -> void:
	_event_invitation = null
	if event_type == "battle":
		_pending_battle_difficulty_scale = -1.0
		_battle_wave_schedule.clear()
	_reschedule_declined_event(event_type)
	_host._publish_news({
		"category": "公告",
		"headline": "事件邀请已被丢弃。",
		"headline_en": "The invitation was discarded."
	}, false, false)

func _on_event_invitation_expired(event_type: String) -> void:
	_event_invitation = null
	if event_type == "battle":
		_pending_battle_difficulty_scale = -1.0
		_battle_wave_schedule.clear()
	_reschedule_declined_event(event_type)

func _reschedule_declined_event(event_type: String) -> void:
	var now = _host._get_now_seconds()
	if event_type == "battle":
		if _host._should_offer_final_boss():
			_schedule_next_battle(now)
		else:
			_schedule_declined_battle(now)
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
	_pilgrimage_ends_at = _host._get_now_seconds() + PILGRIMAGE_DURATION_SECONDS
	_pilgrimage_total_member_count = 0
	_pilgrimage_resolved_count = 0
	_pilgrimage_faith_earned = 0.0
	_pilgrimage_gold_dropped = 0
	_host._update_actor_window_bounds()
	_set_pet_autonomy_paused(true)

	var group_count = clampi(
		int(round(float(_pet_window_size.x) / 560.0)),
		PILGRIMAGE_GROUP_MIN,
		PILGRIMAGE_GROUP_MAX
	)
	var group_index = 0
	for group_center in _get_pilgrimage_group_centers(group_count):
		var member_count = _rng.randi_range(PILGRIMAGE_GROUP_MEMBER_MIN, PILGRIMAGE_GROUP_MEMBER_MAX)
		for member_index in member_count:
			var centered_index = float(member_index) - (float(member_count - 1) * 0.5)
			var spawn_x = group_center + (centered_index * PILGRIMAGE_GROUP_SPACING)
			spawn_x += _rng.randf_range(-4.0, 4.0)
			_spawn_pilgrimage_believer(
				spawn_x,
				group_center <= float(_pet_window_size.x) * 0.5,
				float(group_index) * 0.22 + float(member_index) * 0.08
			)
		group_index += 1

	_host._publish_news({
		"category": "公告",
		"headline": "朝圣事件：大批教徒正从桌面边缘涌入，拖动宠物靠近他们！",
		"headline_en": "PILGRIMAGE: Cultists are pouring in from the desktop edges. Drag a pet to confront them!"
	}, true, false)
	_update_pilgrimage_status(_host._get_now_seconds())
	_host._show_pilgrimage_broadcast(
		"PILGRIMAGE" if _language == "en" else "朝圣事件",
		"Drag pets to the cultists before they disperse"
		if _language == "en"
		else "拖动宠物接近教徒，在他们散去前完成遭遇",
		{
			"title_en": "PILGRIMAGE",
			"subtitle_en": "Drag pets to the cultists before they disperse",
			"title_zh": "朝圣事件",
			"subtitle_zh": "拖动宠物接近教徒，在他们散去前完成遭遇"
		}
	)

func _finish_pilgrimage(resolved_early: bool) -> void:
	if not _pilgrimage_active:
		return
	if resolved_early:
		var completion_faith := maxf(
			1.0,
			float(_host._get_faith_growth_rate())
			* PILGRIMAGE_COMPLETION_BURST_SECONDS
			* PILGRIMAGE_COMPLETION_FAITH_MULTIPLIER
		)
		_host._grant_faith(completion_faith)
		_pilgrimage_faith_earned += completion_faith
		_host._show_faith_change_popup(
			Vector2(float(_pet_window_size.x) * 0.5, float(_pet_window_size.y) * 0.45),
			completion_faith
		)
		_host._refresh_faith_display()
		_host._request_save()
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
	_host._update_actor_window_bounds()
	var now = _host._get_now_seconds()
	_schedule_next_pilgrimage(now)
	_last_believer_spawn_at = now
	_schedule_next_believer_spawn(now)

	var title = (
		"PILGRIMAGE COMPLETE"
		if resolved_early and _language == "en"
		else "PILGRIMAGE ENDED"
		if _language == "en"
		else "朝圣结束"
	)
	var subtitle = (
		"Every group was confronted"
		if resolved_early and _language == "en"
		else "所有教徒小组均已完成遭遇"
		if resolved_early
		else "The remaining cultists dispersed"
		if _language == "en"
		else "剩余教徒已经散去"
	)
	var reward_summary := (
		"FAITH SURGE +%d · MONEY DROPPED %s"
		if _language == "en"
		else "信仰暴增 +%d · 金钱掉落 %s"
	) % [int(round(_pilgrimage_faith_earned)), CurrencyDisplay.format_compact(_pilgrimage_gold_dropped)]
	subtitle = "%s · %s" % [subtitle, reward_summary]
	_host._show_pilgrimage_broadcast(title, subtitle, {
		"title_en": "PILGRIMAGE COMPLETE" if resolved_early else "PILGRIMAGE ENDED",
		"subtitle_en": "%s · FAITH SURGE +%d · MONEY DROPPED %s" % [
			"Every group was confronted" if resolved_early else "The remaining cultists dispersed",
			int(round(_pilgrimage_faith_earned)),
			CurrencyDisplay.format_compact(_pilgrimage_gold_dropped)
		],
		"title_zh": "朝圣结束",
		"subtitle_zh": "%s · 信仰暴增 +%d · 金钱掉落 %s" % [
			"所有教徒小组均已完成遭遇" if resolved_early else "剩余教徒已经散去",
			int(round(_pilgrimage_faith_earned)),
			CurrencyDisplay.format_compact(_pilgrimage_gold_dropped)
		]
	})
	_host._publish_news({
		"category": "公告",
		"headline": (
			"朝圣结束：所有教徒小组均已完成遭遇。"
			if resolved_early
			else "朝圣结束：剩余教徒已经散去。"
		),
		"headline_en": (
			"The pilgrimage ended after every cultist group was confronted."
			if resolved_early
			else "The pilgrimage ended; the remaining cultists dispersed."
		)
	}, false, false)

func _spawn_pilgrimage_believer(
	spawn_x: float,
	spawn_from_left := true,
	entrance_delay := 0.0
) -> void:
	var believer: Node2D = BelieverActor.new()
	var ground_contact_y = float(_pet_window_size.y - PET_TASKBAR_OVERLAP_PIXELS)
	believer.call(
		"setup_pilgrim",
		_pet_window_size,
		spawn_x,
		ground_contact_y,
		spawn_from_left,
		entrance_delay
	)
	believer.connect("exited", Callable(_host, "_on_believer_exited"))
	believer.connect("scared_away", Callable(_host, "_on_believer_scared_away"))
	believer.connect("prayed", Callable(_host, "_on_believer_prayed"))
	add_child(believer)
	_believers.append(believer)
	if _pilgrimage_active:
		_pilgrimage_total_member_count += 1


func _get_active_pilgrimage_faith_multiplier() -> float:
	if not _pilgrimage_active:
		return 1.0
	var progress := clampf(
		float(_pilgrimage_resolved_count) / float(maxi(1, _pilgrimage_total_member_count)),
		0.0,
		1.0
	)
	var chain_multiplier := lerpf(1.0, PILGRIMAGE_FAITH_CHAIN_MAX_MULTIPLIER, progress)
	return PILGRIMAGE_FAITH_BASE_MULTIPLIER * chain_multiplier


func _resolve_pilgrimage_encounter(
	actor: Node2D,
	drop_position: Vector2,
	prayed: bool,
	base_gold_value: int
) -> int:
	var safe_base_gold := maxi(0, base_gold_value)
	if (
		not _pilgrimage_active
		or actor == null
		or not is_instance_valid(actor)
		or not actor.has_method("is_pilgrimage_member")
		or not bool(actor.call("is_pilgrimage_member"))
	):
		return safe_base_gold if prayed else 0
	if bool(actor.get_meta("pilgrimage_reward_resolved", false)):
		return 0
	actor.set_meta("pilgrimage_reward_resolved", true)
	_pilgrimage_resolved_count += 1

	var seconds_remaining := maxf(0.0, _pilgrimage_ends_at - float(_host._get_now_seconds()))
	var time_ratio := clampf(seconds_remaining / PILGRIMAGE_DURATION_SECONDS, 0.0, 1.0)
	var early_multiplier := lerpf(1.0, PILGRIMAGE_FAITH_EARLY_MULTIPLIER_MAX, time_ratio)
	var action_multiplier := PILGRIMAGE_PRAYER_FAITH_MULTIPLIER if prayed else 1.0
	var faith_burst := maxf(
		1.0,
		float(_host._get_faith_growth_rate())
		* PILGRIMAGE_FAITH_BURST_SECONDS
		* early_multiplier
		* action_multiplier
	)
	_host._grant_faith(faith_burst)
	_host._show_faith_change_popup(drop_position, faith_burst)
	_host._refresh_faith_display()
	_host._request_save()
	_pilgrimage_faith_earned += faith_burst

	var event_gold_base := safe_base_gold if prayed else PILGRIMAGE_SCARE_GOLD_BASE
	var adjusted_gold := clampi(
		int(round(float(event_gold_base) * PILGRIMAGE_GOLD_MULTIPLIER)),
		1,
		PILGRIMAGE_MAX_SINGLE_GOLD_REWARD
	)
	_pilgrimage_gold_dropped += adjusted_gold
	return adjusted_gold

func _get_pilgrimage_group_centers(group_count: int) -> Array[float]:
	var centers: Array[float] = []
	var safe_group_count = clampi(group_count, PILGRIMAGE_GROUP_MIN, PILGRIMAGE_GROUP_MAX)
	var window_width = float(_pet_window_size.x)
	var edge_margin = minf(PILGRIMAGE_GROUP_EDGE_MARGIN, window_width * 0.24)
	var min_x = edge_margin
	var max_x = maxf(min_x + 1.0, window_width - edge_margin)
	var candidate_count = maxi(12, safe_group_count * 8)
	var candidates: Array[float] = []
	for candidate_index in candidate_count:
		var weight = (float(candidate_index) + 0.5) / float(candidate_count)
		candidates.append(lerpf(min_x, max_x, weight))
	var distant_candidates: Array[float] = []
	for candidate_x in candidates:
		if _get_nearest_pet_x_distance(candidate_x) >= PILGRIMAGE_PET_CLEARANCE:
			distant_candidates.append(candidate_x)
	if distant_candidates.size() >= safe_group_count:
		candidates = distant_candidates

	for _group_index in safe_group_count:
		var best_index = 0
		var best_score = -1.0
		for candidate_index in candidates.size():
			var candidate_x = candidates[candidate_index]
			var score = _get_nearest_pet_x_distance(candidate_x)
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
	var nearest_distance = float(_pet_window_size.x)
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
	var pending_count = 0
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
	var seconds_left = maxi(0, int(ceil(_pilgrimage_ends_at - now)))
	var pending_count = _get_pending_pilgrim_count()
	var faith_multiplier := _get_active_pilgrimage_faith_multiplier()
	_pilgrimage_status_label.text = (
		"PILGRIMAGE  %02d:%02d  ·  %d REMAINING  ·  FAITH ×%.1f"
		if _language == "en"
		else "朝圣  %02d:%02d  ·  剩余 %d 人  ·  信仰 ×%.1f"
	) % [int(seconds_left / 60), seconds_left % 60, pending_count, faith_multiplier]
	_pilgrimage_status_label.visible = _pilgrimage_active

func _set_pet_autonomy_paused(paused: bool) -> void:
	for pet in _pets:
		if is_instance_valid(pet) and pet.has_method("set_autonomy_paused"):
			pet.call("set_autonomy_paused", paused)
