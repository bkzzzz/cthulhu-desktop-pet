extends "res://scripts/runtime/main_context.gd"

# The sofa is a single-seat, temporary comfort activity. Its multiplier is
# deliberately smaller than a food offering because the player can keep the
# furniture on the desktop indefinitely, while only one pet can use it at a
# time.
const SOFA_ITEM_ID := "sofa"
const SOFA_FAITH_MULTIPLIER := 1.5
const SOFA_VISIT_DURATION_SECONDS := 34.0
# This only limits a guest that becomes unable to reach the sofa. It is not
# comfort time: the production boost begins after the climb has completed.
const SOFA_APPROACH_TIMEOUT_SECONDS := 45.0
const SOFA_INITIAL_VISIT_DELAY_SECONDS := 1.0
const SOFA_VISIT_COOLDOWN_MIN_SECONDS := 16.0
const SOFA_VISIT_COOLDOWN_MAX_SECONDS := 28.0
const SOFA_RETRY_SECONDS := 4.0
const SOFA_SEAT_X_FRACTION := 0.50
const SOFA_SEAT_Y_FRACTION := 0.62
# The pet's visual body must overlap this padded furniture rect on release.
# This is forgiving enough for differently sized pets without turning a drop
# merely near the sofa into an unintended rest session.
const SOFA_MANUAL_DROP_PADDING := 18.0
const SOFA_SESSION_KEY := "sofa_session"
const SOFA_NEXT_VISIT_KEY := "sofa_next_visit_at"


func _update_sofa_interaction(_delta: float) -> void:
	var state := _get_sofa_item_state()
	if state.is_empty() or not bool(state.get("owned", false)):
		return
	var now: float = float(_host._get_now_seconds())
	var sofa = _get_sofa_actor()
	if sofa == null or not bool(state.get("deployed", false)):
		if not _get_sofa_session(state).is_empty():
			_clear_sofa_session(state, now, false)
		return
	if _battle_active or _pilgrimage_active:
		_release_sofa_interaction("", false)
		return

	var session := _get_sofa_session(state)
	if not session.is_empty():
		_maintain_sofa_session(state, session, sofa, now)
		return

	var next_visit_at := float(state.get(SOFA_NEXT_VISIT_KEY, 0.0))
	if next_visit_at <= 0.0:
		state[SOFA_NEXT_VISIT_KEY] = now + SOFA_INITIAL_VISIT_DELAY_SECONDS
		_write_sofa_item_state(state)
		return
	if now < next_visit_at:
		return
	_start_sofa_session(state, sofa, now)


func _on_sofa_deployed() -> void:
	var state := _get_sofa_item_state()
	if state.is_empty() or not bool(state.get("owned", false)):
		return
	# A newly placed sofa begins a fresh, visible visit shortly after placement.
	# A restored save never calls this hook, so its active session remains intact.
	state.erase(SOFA_SESSION_KEY)
	state[SOFA_NEXT_VISIT_KEY] = _host._get_now_seconds() + SOFA_INITIAL_VISIT_DELAY_SECONDS
	_write_sofa_item_state(state)
	_host._request_save()


func _release_sofa_interaction(pet_id := "", animate := true) -> void:
	var state := _get_sofa_item_state()
	var session := _get_sofa_session(state)
	if session.is_empty():
		return
	var occupant_id := String(session.get("pet_id", ""))
	if not pet_id.is_empty() and occupant_id != pet_id:
		return
	var actor := _get_desktop_pet_by_id(occupant_id)
	_clear_sofa_session(state, _host._get_now_seconds(), true)
	if actor != null and actor.has_method("leave_sofa_visit"):
		actor.call("leave_sofa_visit", animate)
	_refresh_sofa_production()


func _try_begin_manual_sofa_visit(actor: Node2D) -> bool:
	if (
		actor == null
		or not is_instance_valid(actor)
		or _battle_active
		or _pilgrimage_active
	):
		return false
	var state := _get_sofa_item_state()
	if state.is_empty() or not bool(state.get("owned", false)) or not bool(state.get("deployed", false)):
		return false
	var sofa := _get_sofa_actor()
	if sofa == null or not _is_pet_dropped_on_sofa(actor, sofa):
		return false
	# A sofa intentionally has one seat. A player dropping a second pet on it
	# must leave the existing guest and its boost untouched.
	if not _get_sofa_session(state).is_empty():
		return false
	var pet_id := String(_host._get_actor_pet_id(actor))
	if pet_id.is_empty() or _host._is_pet_recovering(pet_id):
		return false
	var seat := _get_sofa_seat_position(sofa)
	if not actor.has_method("seat_on_sofa_immediately") or not bool(actor.call("seat_on_sofa_immediately", seat.x, seat.y)):
		return false
	var now: float = float(_host._get_now_seconds())
	state[SOFA_SESSION_KEY] = {
		"pet_id": pet_id,
		"phase": "seated",
		"ends_at": now + SOFA_VISIT_DURATION_SECONDS
	}
	state.erase(SOFA_NEXT_VISIT_KEY)
	_write_sofa_item_state(state)
	_on_pet_sofa_reached(actor)
	_host._request_save()
	return true


func _on_pet_sofa_reached(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id: String = String(_host._get_actor_pet_id(actor))
	var state := _get_sofa_item_state()
	var session := _get_sofa_session(state)
	if pet_id.is_empty() or String(session.get("pet_id", "")) != pet_id:
		return
	if not bool(state.get("deployed", false)) or _battle_active or _pilgrimage_active:
		_release_sofa_interaction(pet_id, false)
		return
	var now: float = float(_host._get_now_seconds())
	var was_approaching := String(session.get("phase", "")) == "approaching"
	session["phase"] = "seated"
	session.erase("approach_expires_at")
	# A restored seated visit already has an end timestamp and should retain its
	# remaining time. A new guest receives the complete comfort duration only
	# after it has actually reached the seat.
	if was_approaching or float(session.get("ends_at", 0.0)) <= now:
		session["ends_at"] = now + SOFA_VISIT_DURATION_SECONDS
	state[SOFA_SESSION_KEY] = session
	_write_sofa_item_state(state)
	_host._clear_pet_runtime_effects(pet_id)
	_host._spawn_emotion(actor, "happy", Vector2(24.0, -22.0), EMOTION_SCALE, 0.0, true)
	_refresh_sofa_production()


func _on_pet_sofa_departed(actor: Node2D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var pet_id: String = String(_host._get_actor_pet_id(actor))
	if pet_id.is_empty():
		return
	var state := _get_sofa_item_state()
	var session := _get_sofa_session(state)
	if String(session.get("pet_id", "")) != pet_id:
		return
	_clear_sofa_session(state, _host._get_now_seconds(), true)
	_refresh_sofa_production()


func _get_pet_sofa_multiplier(pet_id: String, now := -1.0) -> float:
	if pet_id.is_empty() or _battle_active or _pilgrimage_active:
		return 1.0
	var state := _get_sofa_item_state()
	if not bool(state.get("deployed", false)) or _get_sofa_actor() == null:
		return 1.0
	var session := _get_sofa_session(state)
	var check_time: float = float(_host._get_now_seconds()) if now < 0.0 else now
	if (
		String(session.get("pet_id", "")) != pet_id
		or String(session.get("phase", "")) != "seated"
		or float(session.get("ends_at", 0.0)) <= check_time
	):
		return 1.0
	var actor := _get_desktop_pet_by_id(pet_id)
	if actor == null or not actor.has_method("is_sofa_seated") or not bool(actor.call("is_sofa_seated")):
		return 1.0
	return SOFA_FAITH_MULTIPLIER


func _get_pet_sofa_seconds_remaining(pet_id: String, now := -1.0) -> float:
	if _get_pet_sofa_multiplier(pet_id, now) <= 1.0:
		return 0.0
	var session := _get_sofa_session(_get_sofa_item_state())
	var check_time: float = float(_host._get_now_seconds()) if now < 0.0 else now
	return maxf(0.0, float(session.get("ends_at", 0.0)) - check_time)


func _maintain_sofa_session(state: Dictionary, session: Dictionary, sofa: Node2D, now: float) -> void:
	var pet_id := String(session.get("pet_id", ""))
	var actor := _get_desktop_pet_by_id(pet_id)
	if actor == null or _is_sofa_session_expired(session, now):
		_clear_sofa_session(state, now, true)
		if actor != null and actor.has_method("leave_sofa_visit"):
			actor.call("leave_sofa_visit", true)
		_refresh_sofa_production()
		return
	var seat := _get_sofa_seat_position(sofa)
	if actor.has_method("is_sofa_visit_active") and bool(actor.call("is_sofa_visit_active")):
		if actor.has_method("update_sofa_visit_target"):
			actor.call("update_sofa_visit_target", seat.x, seat.y)
		return
	if not actor.has_method("begin_sofa_visit") or not bool(actor.call("begin_sofa_visit", seat.x, seat.y)):
		# Preserve the selected pet for this short retry window; this prevents a
		# pet that has just finished another desktop interaction from being skipped.
		session["phase"] = "approaching"
		state[SOFA_SESSION_KEY] = session
		state[SOFA_NEXT_VISIT_KEY] = now + SOFA_RETRY_SECONDS
		_write_sofa_item_state(state)


func _start_sofa_session(state: Dictionary, sofa: Node2D, now: float) -> void:
	var actor := _choose_sofa_guest()
	if actor == null:
		state[SOFA_NEXT_VISIT_KEY] = now + SOFA_RETRY_SECONDS
		_write_sofa_item_state(state)
		return
	var pet_id: String = String(_host._get_actor_pet_id(actor))
	var seat := _get_sofa_seat_position(sofa)
	if pet_id.is_empty() or not actor.has_method("begin_sofa_visit") or not bool(actor.call("begin_sofa_visit", seat.x, seat.y)):
		state[SOFA_NEXT_VISIT_KEY] = now + SOFA_RETRY_SECONDS
		_write_sofa_item_state(state)
		return
	state[SOFA_SESSION_KEY] = {
		"pet_id": pet_id,
		"phase": "approaching",
		"approach_expires_at": now + SOFA_APPROACH_TIMEOUT_SECONDS
	}
	state.erase(SOFA_NEXT_VISIT_KEY)
	_write_sofa_item_state(state)
	_host._request_save()


func _clear_sofa_session(state: Dictionary, now: float, schedule_next := true) -> void:
	state.erase(SOFA_SESSION_KEY)
	if schedule_next and bool(state.get("deployed", false)):
		state[SOFA_NEXT_VISIT_KEY] = now + _rng.randf_range(
			SOFA_VISIT_COOLDOWN_MIN_SECONDS,
			SOFA_VISIT_COOLDOWN_MAX_SECONDS
		)
	else:
		state.erase(SOFA_NEXT_VISIT_KEY)
	_write_sofa_item_state(state)


func _choose_sofa_guest() -> Node2D:
	var candidates: Array[Node2D] = []
	for pet in _pets:
		if not is_instance_valid(pet):
			continue
		var pet_id: String = String(_host._get_actor_pet_id(pet))
		if pet_id.is_empty() or _host._is_pet_recovering(pet_id):
			continue
		if pet.has_method("can_visit_sofa") and bool(pet.call("can_visit_sofa")):
			candidates.append(pet)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _get_sofa_actor() -> Node2D:
	if _host == null or not _host.has_method("_get_desktop_item"):
		return null
	var actor = _host.call("_get_desktop_item", SOFA_ITEM_ID)
	return actor as Node2D if is_instance_valid(actor) and actor is Node2D else null


func _get_desktop_pet_by_id(pet_id: String) -> Node2D:
	if pet_id.is_empty():
		return null
	for pet in _pets:
		if is_instance_valid(pet) and _host._get_actor_pet_id(pet) == pet_id:
			return pet
	return null


func _get_sofa_seat_position(sofa: Node2D) -> Vector2:
	var visual_size := _get_sofa_visual_size(sofa)
	var visual_top := sofa.position.y - visual_size.y * 0.5
	return Vector2(
		sofa.position.x + visual_size.x * (SOFA_SEAT_X_FRACTION - 0.5),
		visual_top + visual_size.y * SOFA_SEAT_Y_FRACTION
	)


func _is_pet_dropped_on_sofa(actor: Node2D, sofa: Node2D) -> bool:
	var visual_size := _get_sofa_visual_size(sofa)
	var sofa_rect := Rect2(sofa.position - visual_size * 0.5, visual_size).grow(SOFA_MANUAL_DROP_PADDING)
	var pet_rect := Rect2(actor.position - Vector2(48.0, 96.0), Vector2(96.0, 128.0))
	if actor.has_method("get_draw_rect"):
		var reported_rect: Variant = actor.call("get_draw_rect")
		if reported_rect is Rect2:
			pet_rect = reported_rect
	return sofa_rect.intersects(pet_rect)


func _get_sofa_visual_size(sofa: Node2D) -> Vector2:
	var definition := sofa.call("get_item_definition") as Dictionary if sofa.has_method("get_item_definition") else {}
	var texture := load(String(definition.get("texture", ""))) as Texture2D
	var scale := clampf(float(definition.get("visual_scale", 0.5)), 0.10, 2.0)
	return texture.get_size() * scale if texture != null else Vector2(180.0, 120.0)


func _get_sofa_item_state() -> Dictionary:
	var state_value: Variant = _item_states.get(SOFA_ITEM_ID, {})
	return state_value.duplicate(true) if state_value is Dictionary else {}


func _write_sofa_item_state(state: Dictionary) -> void:
	if state.is_empty():
		_item_states.erase(SOFA_ITEM_ID)
		return
	_item_states[SOFA_ITEM_ID] = state


func _get_sofa_session(state: Dictionary) -> Dictionary:
	var session_value: Variant = state.get(SOFA_SESSION_KEY, {})
	if not session_value is Dictionary:
		return {}
	var session: Dictionary = session_value
	var pet_id := String(session.get("pet_id", ""))
	var phase := String(session.get("phase", ""))
	if not PetCatalog.DEFINITIONS.has(pet_id) or phase not in ["approaching", "seated"]:
		return {}
	return session.duplicate(true)


func _is_sofa_session_expired(session: Dictionary, now: float) -> bool:
	if String(session.get("phase", "")) == "seated":
		return float(session.get("ends_at", 0.0)) <= now
	return float(session.get("approach_expires_at", 0.0)) <= now


func _refresh_sofa_production() -> void:
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._request_save()
