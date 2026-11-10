--!strict
--[[
	Time

	Purpose
		The ONE place for clock and calendar logic. Daily rewards, streaks and the
		Daily Expedition all depend on "what day is it?", and that answer must be
		identical everywhere, so every date calculation goes through this module.

	Key idea: the "day number"
		All calendar logic uses UTC (the worldwide reference clock, no time zones,
		no daylight saving). A "day number" is the count of whole UTC days since
		1 January 1970. Day numbers are plain integers, so "is this the next
		day?" is just `today - lastDay == 1`. Midnight UTC is the moment the day
		number goes up by one.

	Public API
		Time.SECONDS_PER_DAY                    86400
		Time.Now() -> number                    Current Unix time in whole seconds (UTC).
		Time.SyncedNow() -> number              Server-synchronised clock with fractions of a
		                                        second. Same value on server and every client.
		Time.DayNumber(unixSeconds?) -> number  UTC day number (defaults to now).
		Time.DateKey(unixSeconds?) -> string    "YYYY-MM-DD" in UTC (defaults to now).
		Time.StartOfDay(dayNumber) -> number    Unix time of 00:00:00 UTC on that day.
		Time.SecondsUntilNextDay(unixSeconds?) -> number   1..86400 seconds until UTC midnight.
		Time.FormatClock(seconds) -> string     "M:SS" for timers (negative values show 0:00).

	Contract
		- Game RULES (claims, streaks, rewards) must only use these functions ON
		  THE SERVER. A player's device clock can be changed by the player, so
		  the client may use Time only to DISPLAY countdowns.
		- Nothing here yields.
		- This module depends on nothing else, so any module may require it.

	Edge cases, reasoned (nothing here has been executed)
		- Exactly midnight: unix = N * 86400 gives DayNumber N (the new day), and
		  SecondsUntilNextDay returns 86400 (a full day), never 0.
		- One second before midnight: DayNumber N - 1, SecondsUntilNextDay 1.
		- Leap years and daylight saving do not matter: day numbers count
		  86400-second UTC days, and UTC has no daylight saving.
		- Leap seconds: Unix time ignores them, so every day is exactly 86400s.
]]

local Time = {}

Time.SECONDS_PER_DAY = 86400

local SECONDS_PER_MINUTE = 60

function Time.Now(): number
	-- os.time() with no arguments returns the current UTC Unix timestamp.
	return os.time()
end

function Time.SyncedNow(): number
	-- TODO(verify-in-studio): workspace:GetServerTimeNow() returns a Unix-epoch based clock that matches between server and clients (within network accuracy).
	return workspace:GetServerTimeNow()
end

function Time.DayNumber(unixSeconds: number?): number
	local timestamp = unixSeconds or Time.Now()
	return math.floor(timestamp / Time.SECONDS_PER_DAY)
end

function Time.DateKey(unixSeconds: number?): string
	local timestamp = unixSeconds or Time.Now()
	-- The leading "!" asks for UTC instead of the machine's local time zone.
	-- TODO(verify-in-studio): os.date("!%Y-%m-%d", t) returns e.g. "2026-11-10" for a UTC timestamp.
	return os.date("!%Y-%m-%d", timestamp) :: string
end

function Time.StartOfDay(dayNumber: number): number
	return dayNumber * Time.SECONDS_PER_DAY
end

function Time.SecondsUntilNextDay(unixSeconds: number?): number
	local timestamp = unixSeconds or Time.Now()
	return Time.SECONDS_PER_DAY - (timestamp % Time.SECONDS_PER_DAY)
end

function Time.FormatClock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	local minutes = math.floor(whole / SECONDS_PER_MINUTE)
	local remainder = whole % SECONDS_PER_MINUTE
	return string.format("%d:%02d", minutes, remainder)
end

return Time
