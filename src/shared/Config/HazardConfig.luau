--!strict
--[[
	HazardConfig

	Purpose
		Tunable numbers for hazards: the advancing danger (rising water, rising
		lava) that puts a clock on every run.

	Public API
		HazardConfig.Hazards              Map of hazard id -> Types.HazardDefinition.
		HazardConfig.teamSizeSpeedMultiplier   Speed scale by team size (index = player count).
		HazardConfig.difficultySpeedMultiplier Speed scale by room/location difficulty (index 1-5).

	How hazard speed is worked out (implemented in M5)
		speed = baseSpeed
		        x speedCurve multiplier at the hazard's current progress
		        x teamSizeSpeedMultiplier[team size]
		        x difficultySpeedMultiplier[difficulty]
		        x solvingSlowMultiplier (only while the team is working a puzzle)

	Contract
		- Read-only at runtime (frozen).
		- Adding a new hazard means adding an entry to `Hazards` plus one hazard
		  module (M5). The round loop must not need to change.
		- These are first-guess values. They cannot be play-tested until M12 and
		  are expected to change then.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Types = require(script.Parent.Parent.Types)

local Hazards: { [string]: Types.HazardDefinition } = {
	RisingWater = {
		id = "RisingWater",
		displayName = "Rising Water",

		-- Calm seconds at the start of a run before the hazard begins to move.
		startDelaySeconds = 10,

		-- Rise speed in studs per second before any multipliers.
		baseSpeed = 0.5,

		-- Speeds up as it climbs: `atProgress` runs from 0 (start height) to 1
		-- (top of the location). Values in between are blended smoothly.
		speedCurve = {
			{ atProgress = 0, multiplier = 1 },
			{ atProgress = 0.5, multiplier = 1.15 },
			{ atProgress = 1, multiplier = 1.4 },
		},

		-- While the team is actively working on a puzzle the hazard slows to
		-- this fraction of its speed, so thinking is not punished too hard.
		solvingSlowMultiplier = 0.6,

		-- Water is forgiving: a player must stay under for this long to be caught.
		contactGraceSeconds = 2,
	},

	RisingLava = {
		id = "RisingLava",
		displayName = "Rising Lava",
		startDelaySeconds = 14,
		baseSpeed = 0.4,
		speedCurve = {
			{ atProgress = 0, multiplier = 0.9 },
			{ atProgress = 0.6, multiplier = 1.2 },
			{ atProgress = 1, multiplier = 1.6 },
		},
		solvingSlowMultiplier = 0.7,

		-- Lava is strict: touching it catches the player immediately.
		contactGraceSeconds = 0,
	},
}

local HazardConfig = {
	Hazards = Hazards,

	-- Index = number of players on the team (1 to 4). Small teams get a slower
	-- hazard because they have fewer hands for each puzzle.
	teamSizeSpeedMultiplier = { 0.8, 0.9, 1, 1.05 },

	-- Index = difficulty rating (1 = easiest, 5 = hardest).
	difficultySpeedMultiplier = { 0.9, 1, 1.1, 1.2, 1.3 },
}

return TableUtil.DeepFreeze(HazardConfig)
