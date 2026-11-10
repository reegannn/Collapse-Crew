--!strict
--[[
	Flags

	Purpose
		The one place code asks "is this feature switched on?". For now it reads
		the defaults in Config/FlagConfig. Milestone M10 can add live overrides
		here without any caller changing.

	Public API
		Flags.IsEnabled(name) -> boolean
			true if the flag exists and is on. An unknown flag name counts as OFF
			and is reported once in the log (it is almost certainly a typo).
		Flags.GetAll() -> { [name]: boolean }
			A copy of every flag and its current value (for debugging/analytics).

	Contract
		- Never yields, never throws.
		- A flag only switches behaviour on or off. It must never be used to
		  carry numbers or text (those belong in the other Config modules).
		- Flags read on the client are for presentation only. Anything that
		  affects rewards or outcomes is checked on the server.
]]

local FlagConfig = require(script.Parent.Config.FlagConfig)
local Logger = require(script.Parent.Util.Logger)

local log = Logger.new("Flags")

-- Remembers which unknown names were already reported, so a typo inside a
-- loop does not flood the log. Bounded in practice by the number of distinct
-- flag names written in the code.
local reportedUnknown: { [string]: boolean } = {}

local Flags = {}

function Flags.IsEnabled(name: string): boolean
	-- Guard against a non-text name (for example nil from a missing variable),
	-- which would otherwise raise an error when used as a table key below.
	if type(name) ~= "string" then
		log:Warn("Flags.IsEnabled was called with a %s instead of a flag name; treating it as off", typeof(name))
		return false
	end

	local value = FlagConfig[name]
	if value == nil then
		if not reportedUnknown[name] then
			reportedUnknown[name] = true
			log:Warn("Unknown feature flag %q was read; treating it as off", tostring(name))
		end
		return false
	end
	return value
end

function Flags.GetAll(): { [string]: boolean }
	local copy: { [string]: boolean } = {}
	for name, value in FlagConfig do
		copy[name] = value
	end
	return copy
end

return Flags
