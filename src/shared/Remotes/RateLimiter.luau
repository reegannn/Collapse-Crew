--!strict
--[[
	Remotes/RateLimiter

	Purpose
		Limits how often each player may do something (here: send one kind of
		network message). Without it, a cheating client could flood the server
		with thousands of messages per second.

	How it works ("token bucket")
		Picture a bucket of tokens for each player. Every call costs one token.
		The bucket starts full (`burst` tokens) and refills steadily
		(`perSecond` tokens each second) up to its maximum. If the bucket is
		empty, the call is refused. So `burst` allows a short flurry of quick
		taps, while `perSecond` sets the long-run rate.

	Public API
		RateLimiter.new(burst, perSecond) -> RateLimiter
		limiter:TryConsume(player, now?) -> boolean
			true if the call is allowed (and a token was taken), false if the
			player is over the limit. `now` defaults to os.clock() and exists so
			the logic can be reasoned about with made-up times.
		limiter:RemovePlayer(player)
			Forget a player's bucket. Call when they leave, or memory grows forever.

	Contract
		- Never yields, never throws.
		- Buckets are keyed by UserId (a number), not by the Player object, so a
		  bucket can always be removed even after the Player object is gone.
		- The owner (Remotes) calls RemovePlayer on PlayerRemoving, and refuses
		  calls from players who have already left, so buckets cannot be
		  re-created after cleanup.
]]

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_burst: number,
		_perSecond: number,
		_buckets: { [number]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(burst: number, perSecond: number): RateLimiter
	return setmetatable({
		_burst = math.max(1, burst),
		_perSecond = math.max(0, perSecond),
		_buckets = {},
	}, RateLimiter)
end

function RateLimiter.TryConsume(self: RateLimiter, player: Player, now: number?): boolean
	local currentTime = now or os.clock()
	local userId = player.UserId

	local bucket: Bucket? = self._buckets[userId]
	if bucket == nil then
		local fresh: Bucket = { tokens = self._burst, updatedAt = currentTime }
		self._buckets[userId] = fresh
		bucket = fresh
	else
		local elapsed = math.max(0, currentTime - bucket.updatedAt)
		bucket.tokens = math.min(self._burst, bucket.tokens + elapsed * self._perSecond)
		bucket.updatedAt = currentTime
	end

	local current = bucket :: Bucket
	if current.tokens < 1 then
		return false
	end
	current.tokens -= 1
	return true
end

function RateLimiter.RemovePlayer(self: RateLimiter, player: Player)
	self._buckets[player.UserId] = nil
end

return RateLimiter
