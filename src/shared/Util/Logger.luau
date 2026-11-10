--!strict
--[[
	Logger

	Purpose
		One consistent way to write messages to the Roblox output window, with
		severity levels and a single switch for how much detail is shown.

	Public API
		Logger.new(scope) -> Logger        `scope` is a short label, usually the module name.
		Logger.SetLevel(levelName)         "Debug" | "Info" | "Warn" | "Error". Messages below
		                                   this level are hidden. Unknown names are ignored.
		Logger.GetLevel() -> string
		logger:Debug(message, ...)         Developer detail. Hidden unless the level is "Debug".
		logger:Info(message, ...)          Normal lifecycle events.
		logger:Warn(message, ...)          Something unexpected that the game recovered from.
		logger:Error(message, ...)         Something failed. Logged loudly but NEVER thrown.

	Usage
		local log = Logger.new("DataService")
		log:Info("Loaded profile for %s in %.2fs", player.Name, elapsed)

	Contract
		- `message` may contain string.format placeholders (%s, %d ...) filled
		  from the extra arguments. A bad format string never throws; the raw
		  message is printed instead.
		- Logging never yields and never raises an error, so it is safe anywhere,
		  including inside pcall handlers and cleanup code.
		- The level is global (shared by every Logger on this side of the
		  network). Each Bootstrap sets it once from GameConfig.Logging.
		- This module depends on nothing else, so any module may require it.
]]

local OUTPUT_PREFIX = "[CC]"

local LEVEL_RANK: { [string]: number } = {
	Debug = 1,
	Info = 2,
	Warn = 3,
	Error = 4,
}

local currentLevelName = "Info"
local currentRank = LEVEL_RANK.Info

local Logger = {}
Logger.__index = Logger

export type Logger = typeof(setmetatable({} :: { _scope: string }, Logger))

local function formatMessage(message: string, ...: any): string
	if select("#", ...) == 0 then
		return message
	end
	local ok, result = pcall(string.format, message, ...)
	if ok then
		return result
	end
	return message .. " [log format error]"
end

local function buildLine(levelName: string, scope: string, message: string, ...: any): string
	return string.format(
		"%s[%s][%s] %s",
		OUTPUT_PREFIX,
		levelName,
		scope,
		formatMessage(tostring(message), ...)
	)
end

function Logger.new(scope: string): Logger
	return setmetatable({ _scope = scope }, Logger)
end

function Logger.SetLevel(levelName: string)
	local rank = LEVEL_RANK[levelName]
	if rank == nil then
		warn(buildLine("Warn", "Logger", "Ignoring unknown log level %q", tostring(levelName)))
		return
	end
	currentLevelName = levelName
	currentRank = rank
end

function Logger.GetLevel(): string
	return currentLevelName
end

function Logger.Debug(self: Logger, message: string, ...: any)
	if currentRank <= LEVEL_RANK.Debug then
		print(buildLine("Debug", self._scope, message, ...))
	end
end

function Logger.Info(self: Logger, message: string, ...: any)
	if currentRank <= LEVEL_RANK.Info then
		print(buildLine("Info", self._scope, message, ...))
	end
end

function Logger.Warn(self: Logger, message: string, ...: any)
	if currentRank <= LEVEL_RANK.Warn then
		warn(buildLine("Warn", self._scope, message, ...))
	end
end

function Logger.Error(self: Logger, message: string, ...: any)
	-- Uses warn() rather than error() on purpose: error() would throw and stop
	-- the calling code, and logging must never change control flow.
	warn(buildLine("Error", self._scope, message, ...))
end

return Logger
