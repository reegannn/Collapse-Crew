--!strict
--[[
	Client Bootstrap

	Purpose
		The ONE script that starts the client side of the game (the part that
		runs on each player's device). Every Controller is a module that this
		script loads, in the order written in CONTROLLER_ORDER below.

	What it does, in order
		1. Waits until the game has finished arriving from the server.
		2. Sets how much detail the log shows (GameConfig.Logging).
		3. Connects to the network remotes the server created (Remotes.InitClient).
		4. Loads every Controller, calls each Init(), then each Start()
		   (see Util/Lifecycle for exactly what those two steps mean).

	Adding a Controller
		Create src/client/Controllers/<Name>.luau, then add "<Name>" to
		CONTROLLER_ORDER. A module that is not in the list is never loaded.
		Keep "SessionController" LAST: its Start tells the server this client is
		ready, which must happen after every other Controller is listening.
]]

-- Shared modules live in ReplicatedStorage and arrive over the network. Wait
-- for the initial load to finish so everything below is guaranteed to exist.
-- TODO(verify-in-studio): after game.Loaded, ReplicatedStorage.Shared and all of its descendants exist on the client.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local GameConfig = require(Shared.Config.GameConfig)
local Lifecycle = require(Shared.Util.Lifecycle)
local Logger = require(Shared.Util.Logger)
local Remotes = require(Shared.Remotes)

local CONTROLLER_ORDER = {
	"SessionController",
}

local loggingConfig = GameConfig.Logging
Logger.SetLevel(if RunService:IsStudio() then loggingConfig.studioLevel else loggingConfig.level)

Remotes.InitClient()
-- TODO(verify-in-studio): the Client folder is copied from StarterPlayerScripts with Bootstrap and Controllers intact, so script.Parent.Controllers exists here.
Lifecycle.Run("Client", script.Parent.Controllers, CONTROLLER_ORDER)
