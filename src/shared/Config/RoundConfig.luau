--!strict
--[[
	RoundConfig

	Purpose
		Tunable numbers for one expedition (a "round" or "run"): how long each
		phase lasts and how long a run may take.

	Public API
		A read-only table (see the fields below).

	Contract
		- Read-only at runtime (frozen).
		- M1 holds only the values the framework's types refer to. The round
		  state machine (M4) adds its own tunables here; nothing in gameplay code
		  may hard-code a duration.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local RoundConfig = {
	Phases = {
		-- "Briefing": the short get-ready moment after a team arrives in its arena.
		briefingSeconds = 6,

		-- "Results": how long the results screen stays up before returning to the lobby.
		resultsSeconds = 12,
	},

	-- Hard limit on a single run. Design target is 4-8 minutes per expedition,
	-- so the limit sits at the top of that range.
	maxRunSeconds = 480,
}

return TableUtil.DeepFreeze(RoundConfig)
