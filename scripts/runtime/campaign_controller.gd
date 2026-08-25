extends "res://scripts/runtime/main_context.gd"


func _get_campaign_level_cap() -> int:
	return PetProgression.MAX_LEVEL if _endless_mode else EconomyBalance.CAMPAIGN_LEVEL_TARGET


func _is_endless_mode() -> bool:
	return _endless_mode


func _get_potential_coin_rate() -> float:
	return EconomyBalance.potential_coin_rate_per_minute(
		_unlocked_pet_ids,
		_pet_states
	)


func _get_dynamic_shop_goods() -> Array[Dictionary]:
	var goods := EconomyBalance.make_dynamic_shop_goods(
		OfferingCatalog.make_shop_goods(),
		_get_potential_coin_rate()
	)
	# Desktop items have fixed authored prices and are reusable after purchase.
	goods.append_array(DesktopItemCatalog.make_shop_goods())
	return goods


func _check_campaign_completion() -> bool:
	var roster_ready := EconomyBalance.is_campaign_complete(
		_unlocked_pet_ids,
		_pet_states
	)
	if not roster_ready:
		return false
	if not _final_boss_defeated:
		if not _pending_evolution_notifications.is_empty():
			return false
		if is_instance_valid(_evolution_window) and _evolution_window.visible:
			return false
		_host._queue_final_boss_invitation()
		return false
	var complete_now := true
	if complete_now and not _campaign_completed:
		_campaign_completed = true
		_campaign_completion_acknowledged = false
		_host._request_save()
	if not _campaign_completed or _campaign_completion_acknowledged:
		return complete_now
	if not _pending_evolution_notifications.is_empty():
		return true
	if is_instance_valid(_evolution_window) and _evolution_window.visible:
		return true
	if _completion_window == null or not is_instance_valid(_completion_window):
		_host._create_completion_window()
	if is_instance_valid(_completion_window) and not _completion_window.visible:
		_completion_window.call("open_window", _total_runtime_seconds)
	return true


func _should_offer_final_boss() -> bool:
	return (
		not _endless_mode
		and not _final_boss_defeated
		and EconomyBalance.is_campaign_complete(_unlocked_pet_ids, _pet_states)
	)


func _on_final_boss_defeated() -> void:
	if not EconomyBalance.is_campaign_complete(_unlocked_pet_ids, _pet_states):
		return
	if not _final_boss_defeated:
		_final_boss_defeated = true
		_host._request_save()
	_check_campaign_completion()


func _on_completion_continue_requested() -> void:
	if not _has_reached_campaign_goal():
		return
	_campaign_completed = true
	_campaign_completion_acknowledged = true
	_host._request_save()


func _on_endless_mode_requested() -> void:
	if not _has_reached_campaign_goal():
		return
	_campaign_completed = true
	_campaign_completion_acknowledged = true
	_endless_mode = true
	_pet_upgrade_stats_dirty = true
	_host._refresh_pet_stats(true)
	_host._request_save()


func _has_reached_campaign_goal() -> bool:
	return (
		_campaign_completed
		or (
			_final_boss_defeated
			and EconomyBalance.is_campaign_complete(_unlocked_pet_ids, _pet_states)
		)
	)
