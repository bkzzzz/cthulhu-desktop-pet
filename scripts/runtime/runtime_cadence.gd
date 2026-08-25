extends RefCounted

## Staggers equally frequent runtime systems so a 10 Hz simulation pulse does
## not turn into one large, periodic frame spike. At most one group is released
## by each call; overdue groups remain queued for following rendered frames.

const GROUP_PROGRESSION := 0
const GROUP_WORLD := 1
const GROUP_MAINTENANCE := 2
const GROUP_COUNT := 3

var _interval_seconds := 0.1
var _elapsed_by_group: Array[float] = []
var _next_group := 0
var _last_delta := 0.0


func _init(interval_seconds := 0.1) -> void:
	_interval_seconds = maxf(0.001, interval_seconds)
	_elapsed_by_group.resize(GROUP_COUNT)
	for group in range(GROUP_COUNT):
		# The first releases happen at 1/3, 2/3, and 3/3 of the interval.
		_elapsed_by_group[group] = (
			_interval_seconds
			* float(GROUP_COUNT - 1 - group)
			/ float(GROUP_COUNT)
		)


func advance(delta: float) -> int:
	var safe_delta := maxf(0.0, delta)
	for group in range(GROUP_COUNT):
		_elapsed_by_group[group] += safe_delta

	for offset in range(GROUP_COUNT):
		var group := (_next_group + offset) % GROUP_COUNT
		if _elapsed_by_group[group] + 0.000001 < _interval_seconds:
			continue
		_last_delta = _elapsed_by_group[group]
		_elapsed_by_group[group] = 0.0
		_next_group = (group + 1) % GROUP_COUNT
		return group

	_last_delta = 0.0
	return -1


func get_last_delta() -> float:
	return _last_delta
