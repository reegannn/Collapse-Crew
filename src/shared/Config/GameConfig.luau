--!strict
--[[
	GameConfig

	Purpose
		Game-wide settings that do not belong to one specific system.

	Public API
		A read-only table (see the fields below). Changing a value here is the
		ONLY supported way to change the behaviour it controls.

	Contract
		- Read-only at runtime (frozen). Editing happens in this file.
		- Config modules may require Util modules, but nothing in Util may
		  require Config. That one-way rule is what prevents circular requires.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local GameConfig = {
	-- Working title. Shown in logs; player-facing text comes later (M9).
	name = "Collapse Crew",
	version = "0.1.0",

	Team = {
		-- A team may be a single player ("solo"); puzzles scale down for small teams (M6).
		minSize = 1,
		maxSize = 4,
	},

	Logging = {
		-- How much detail the output window shows. One of "Debug", "Info", "Warn", "Error".
		-- `level` applies to the live game; `studioLevel` applies when testing in Studio.
		level = "Info",
		studioLevel = "Debug",
	},

	Remotes = {
		-- Name of the folder (in ReplicatedStorage) that holds the network remotes.
		folderName = "NetRemotes",

		-- How long a client waits for the server to create the remotes before giving up.
		clientWaitTimeoutSeconds = 20,

		-- Rate limit used by any client-to-server remote that does not declare its own.
		-- "burst" = how many calls may arrive at once; "perSecond" = how fast the
		-- allowance refills. See Remotes/RateLimiter for the full explanation.
		defaultRateLimit = {
			burst = 5,
			perSecond = 2,
		},

		-- Upper bounds applied by Schema.String / Schema.Array when a remote does
		-- not set its own. They stop a cheating client sending huge payloads.
		defaultMaxStringLength = 200,
		defaultMaxArrayLength = 50,
	},
}

return TableUtil.DeepFreeze(GameConfig)
