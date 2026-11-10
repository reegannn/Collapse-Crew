--!strict
--[[
	SessionController

	Purpose
		Tells the server when this client has finished starting up, so the
		server knows it is safe to begin sending game state. It is the client
		half of the server's PlayerSessionService.

	Public API
		SessionController.Init()
		SessionController.Start()   Sends "ClientReady" to the server, once.

	Contract
		- Client only.
		- Must be the LAST entry in the client Bootstrap's CONTROLLER_ORDER.
		  Start() functions begin in list order, so by the time this one runs
		  every other Controller has connected its listeners.
		- Sends nothing else and decides nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Remotes = require(Shared.Remotes)

local SessionController = {}

function SessionController.Init() end

function SessionController.Start()
	Remotes.FireServer("ClientReady")
end

return SessionController
