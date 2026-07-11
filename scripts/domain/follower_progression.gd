extends RefCounted

## Followers are a passive result of the current faith economy. They never feed
## back into faith generation, which keeps the progression loop predictable.

const FOLLOWERS_PER_FAITH_PER_SECOND := 0.05


static func followers_per_second(faith_growth_rate: float) -> float:
	return maxf(0.0, faith_growth_rate) * FOLLOWERS_PER_FAITH_PER_SECOND


static func advance(current_followers: float, faith_growth_rate: float, delta: float) -> float:
	if delta <= 0.0 or not is_finite(delta):
		return maxf(0.0, current_followers)
	return maxf(0.0, current_followers) + followers_per_second(faith_growth_rate) * delta
