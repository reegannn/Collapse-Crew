--!strict
--[[
	Safe

	Purpose
		Small helpers for calling code that might fail (anything that talks to
		Roblox's online services: saving data, purchases, teleports) without
		letting the failure crash the caller. This is the project's "plain pcall
		helpers" in place of a Promise library.

	Public API
		Safe.Call(label, fn, ...) -> (ok, resultOrError)
			Runs fn(...). On failure logs a warning tagged with `label` and
			returns (false, errorMessage). On success returns (true, firstResult).

		Safe.Retry(options, fn) -> (ok, resultOrError)
			Runs fn(attemptNumber) up to options.attempts times, waiting between
			tries. The wait starts at options.baseDelaySeconds and is multiplied
			by options.backoffFactor after each failure, capped at
			options.maxDelaySeconds ("exponential backoff": wait longer each
			time so a struggling service is not hammered).
			Returns (true, firstResult) on the first success, or
			(false, lastErrorMessage) after the final failure.

		Safe.Spawn(label, fn, ...) -> thread
			Runs fn(...) in a new thread. An error is logged with `label`
			instead of surfacing as an anonymous error.

	Contract
		- Only the FIRST return value of `fn` is passed back.
		- Safe.Call and Safe.Retry yield if `fn` yields. Safe.Retry also yields
		  between attempts, so never call it from code that must not pause.
		- Retry options come from Config (never inline numbers at call sites).
]]

local Logger = require(script.Parent.Logger)

local log = Logger.new("Safe")

export type RetryOptions = {
	attempts: number,
	baseDelaySeconds: number,
	maxDelaySeconds: number,
	backoffFactor: number,
}

local Safe = {}

function Safe.Call(label: string, fn: (...any) -> ...any, ...: any): (boolean, any)
	local ok, result = pcall(fn, ...)
	if not ok then
		log:Warn("%s failed: %s", label, tostring(result))
		return false, tostring(result)
	end
	return true, result
end

function Safe.Retry(options: RetryOptions, fn: (attempt: number) -> any): (boolean, any)
	local attempts = math.max(1, options.attempts)
	local delaySeconds = options.baseDelaySeconds
	local lastError = "no attempt was made"

	for attempt = 1, attempts do
		local ok, result = pcall(fn, attempt)
		if ok then
			return true, result
		end
		lastError = tostring(result)

		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * options.backoffFactor, options.maxDelaySeconds)
		end
	end

	return false, lastError
end

function Safe.Spawn(label: string, fn: (...any) -> ...any, ...: any): thread
	return task.spawn(function(...: any)
		local ok, problem = pcall(fn, ...)
		if not ok then
			log:Error("%s failed: %s", label, tostring(problem))
		end
	end, ...)
end

return Safe
