--!strict
--[[
	Types

	Purpose
		The single place where the game's data shapes are defined. A "type" is a
		description of what a piece of data looks like (which fields it has and
		what kind of value each holds). Luau's --!strict mode uses these to point
		out mistakes, such as a misspelled field, before the game is run.

	Public API
		Only types (see below). The module returns an empty table.

		Usage:
			local Types = require(ReplicatedStorage.Shared.Types)
			local function describe(team: Types.TeamState) ... end

	Contract
		- Every data shape shared between modules is defined here, once.
		- This module requires nothing, so any module may require it.
		- Anything that is saved (PlayerData) or sent over the network must use
		  only plain values: numbers, strings, booleans and tables of those.
		  Tables must be EITHER a list (1, 2, 3 ...) OR a dictionary with string
		  keys. Roblox does not reliably save or send dictionaries with number
		  keys, which is why lists of small records are used instead of
		  `{ [userId]: value }` maps.
		- Shapes marked "(draft)" are the M1 starting point and are finalised by
		  the milestone named next to them.
]]

----------------------------------------------------------------------------
-- Start-up
----------------------------------------------------------------------------

-- A Service (server) or Controller (client): a module with the two start-up
-- steps run by Util/Lifecycle.
export type Service = {
	Init: () -> (),
	Start: () -> (),
}

export type Controller = Service

----------------------------------------------------------------------------
-- Player data (saved between sessions; owned by DataService, M2)
----------------------------------------------------------------------------

export type PlayerSettings = {
	-- Accessibility: tone down screen shake and flashy movement (M9).
	reducedMotion: boolean,
	-- 0 (silent) to 1 (full).
	musicVolume: number,
	sfxVolume: number,
}

-- Day values are UTC day numbers (see Util/Time). 0 means "never".
export type StreakData = {
	-- Consecutive days played.
	current: number,
	-- Highest `current` ever reached.
	best: number,
	-- Last day that counted towards the streak.
	lastPlayedDay: number,
	-- Last day the daily reward was claimed.
	lastDailyRewardDay: number,
}

export type PlayerStats = {
	runsStarted: number,
	runsCompleted: number,
	roomsCleared: number,
}

export type PlayerData = {
	-- Version of this shape. Raised whenever fields change, so older saves can
	-- be upgraded by a migration function.
	schemaVersion: number,

	-- Unix time (UTC seconds) of the player's first ever join. 0 until set.
	firstJoinAt: number,
	-- Unix time of the most recent save.
	lastSeenAt: number,

	coins: number,
	-- Total XP ever earned. The level is stored too so it never has to be
	-- re-derived on the client.
	xp: number,
	level: number,

	streak: StreakData,

	-- Cosmetic id -> true for every cosmetic the player owns.
	ownedCosmetics: { [string]: boolean },
	-- Slot name (for example "Trail") -> cosmetic id worn in that slot.
	equippedCosmetics: { [string]: string },

	-- Camp upgrade id -> level purchased.
	campUpgrades: { [string]: number },

	-- Purchase id -> Unix time it was granted. Used to make sure a real-money
	-- purchase is never granted twice (M7).
	receipts: { [string]: number },

	settings: PlayerSettings,
	stats: PlayerStats,

	-- Whether the first-run tutorial was finished or skipped (M9).
	tutorialCompleted: boolean,
}

----------------------------------------------------------------------------
-- Teams (owned by the lobby/team services, M3) (draft)
----------------------------------------------------------------------------

export type TeamPhase = "Forming" | "Countdown" | "InRun"

export type TeamMember = {
	userId: number,
	displayName: string,
	isReady: boolean,
}

export type TeamState = {
	id: string,
	phase: TeamPhase,
	leaderUserId: number,
	-- A list (not a userId-keyed map) so it can be sent over the network.
	members: { TeamMember },
	maxSize: number,
}

----------------------------------------------------------------------------
-- Rounds (owned by the round service, M4) (draft)
----------------------------------------------------------------------------

-- The states of one expedition, in order. "Success" and "Failure" are the two
-- possible endings; both lead to "Results".
export type RoundPhase = "Lobby" | "Briefing" | "Running" | "Success" | "Failure" | "Results"

export type RoundState = {
	teamId: string,
	phase: RoundPhase,
	locationId: string,
	hazardId: string,
	-- Which room the team is in (1 = first) and how many there are.
	roomIndex: number,
	roomCount: number,
	-- Synchronised clock time (Time.SyncedNow) at which the current phase ends;
	-- 0 if the phase has no time limit.
	phaseEndsAt: number,
	-- 0 (hazard at its start height) to 1 (hazard at the top).
	hazardProgress: number,
}

export type RoundResults = {
	success: boolean,
	-- Why the run failed, as a short code such as "TimeUp". nil on success.
	failureReason: string?,
	durationSeconds: number,
	roomsCleared: number,
	roomCount: number,
	coinsEarned: number,
	xpEarned: number,
}

----------------------------------------------------------------------------
-- Hazards (config in Config/HazardConfig; behaviour in M5)
----------------------------------------------------------------------------

-- One point on a hazard's speed curve. `atProgress` is 0-1 (how far the hazard
-- has risen); `multiplier` scales the base speed at that point.
export type SpeedCurvePoint = {
	atProgress: number,
	multiplier: number,
}

export type HazardDefinition = {
	id: string,
	displayName: string,
	-- Calm seconds before the hazard starts moving.
	startDelaySeconds: number,
	-- Studs per second before multipliers.
	baseSpeed: number,
	-- Must be sorted by `atProgress`, starting at 0 and ending at 1.
	speedCurve: { SpeedCurvePoint },
	-- Speed fraction applied while the team is working on a puzzle.
	solvingSlowMultiplier: number,
	-- How long a player may touch the hazard before being caught (0 = instantly).
	contactGraceSeconds: number,
}

----------------------------------------------------------------------------
-- Puzzles and locations (content in Shared/Content; behaviour in M6) (draft)
----------------------------------------------------------------------------

export type PuzzleType = "HoldTheDoor" | "PowerRouting" | "TimedSwitches" | "CarryAndPlace"

export type PuzzleDefinition = {
	id: string,
	type: PuzzleType,
	-- Players needed to solve it WITHOUT helper mechanics. Smaller teams get
	-- helpers (for example a weighted crate standing in for a second player).
	requiredPlayers: number,
	-- Settings specific to the puzzle type (for example how long a switch stays lit).
	params: { [string]: any },
}

return {}
