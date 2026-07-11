extends RefCounted

const FollowerProgression = preload("res://scripts/domain/follower_progression.gd")


static func run() -> Array[String]:
	var failures: Array[String] = []
	if FollowerProgression.followers_per_second(-10.0) != 0.0:
		failures.append("negative faith growth must not remove followers")
	var rate := FollowerProgression.followers_per_second(20.0)
	if not is_equal_approx(rate, 1.0):
		failures.append("follower growth must be derived from faith growth")
	var followers := FollowerProgression.advance(5.0, 20.0, 10.0)
	if not is_equal_approx(followers, 15.0):
		failures.append("followers must grow passively over time")
	if FollowerProgression.advance(followers, 20.0, -1.0) != followers:
		failures.append("invalid time must not change followers")
	return failures
