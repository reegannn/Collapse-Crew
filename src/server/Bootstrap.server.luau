--!strict
--[[
	Server Bootstrap

	Purpose
		The ONE script that starts the server side of the game. Nothing else on
		the server runs by itself: every Service is a module that this script
		loads, in the order written in SERVICE_ORDER below.

	What it does, in order
		1. Sets how much detail the log shows (GameConfig.Logging).
		2. Creates the network remotes (Remotes.InitServer).
		3. Loads every Service, calls each Init(), then each Start()
		   (see Util/Lifecycle for exactly what those two steps mean).
		4. Reports any client-to-server remote that nothing is listening to.

	Adding a Service
		Create src/server/Services/<Name>.luau, then add "<Name>" to
		SERVICE_ORDER. A module that is not in the list is never loaded.
		Order matters only for Init (earlier entries are ready first); put a
		Service after the Services it depends on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local GameConfig = require(Shared.Config.GameConfig)
local Lifecycle = require(Shared.Util.Lifecycle)
local Logger = require(Shared.Util.Logger)
local Remotes = require(Shared.Remotes)

local SERVICE_ORDER = {
	"PlayerSessionService",
}

local loggingConfig = GameConfig.Logging
Logger.SetLevel(if RunService:IsStudio() then loggingConfig.studioLevel else loggingConfig.level)

local log = Logger.new("Server")
log:Info("%s v%s starting", GameConfig.name, GameConfig.version)

Remotes.InitServer()
Lifecycle.Run("Server", script.Parent.Services, SERVICE_ORDER)
Remotes.ReportUnhandled()
