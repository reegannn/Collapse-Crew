--!strict
--[[
	PlayerSessionService

	Purpose
		Tracks which players' devices have finished starting up. A player
		"joins" the server a moment before their own scripts are running, so a
		message sent the instant they join could arrive before anything is
		listening. Each client therefore sends "ClientReady" once its
		Controllers have started, and other Services wait for that before
		pushing game state to the player.

	Public API
		PlayerSessionService.Init()
		PlayerSessionService.Start()
		PlayerSessionService.ClientReady : Signal<Player>
			Fires once per player, the first time their client reports ready.
		PlayerSessionService.IsClientReady(player) -> boolean
		PlayerSessionService.WhenClientReady(player, callback)
			Runs callback(player) now if the player is already ready, otherwise
			once when they become ready. If the player leaves first, the
			callback never runs.

	Contract
		- Server only.
		- "Ready" is a courtesy signal from the client about its own start-up.
		  It grants nothing: no rewards, data or permissions depend on it, so a
		  cheater gains nothing by sending or withholding it.
		- State is removed when a player leaves; nothing is kept per player
		  after that.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Maid = require(Shared.Util.Maid)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local PlayerSessionService = {}

PlayerSessionService.ClientReady = Signal.new() :: Signal.Signal<Player>

local maid = Maid.new()
local readyPlayers: { [Player]: boolean } = {}

local function onClientReady(player: Player)
	if readyPlayers[player] then
		return
	end
	readyPlayers[player] = true
	PlayerSessionService.ClientReady:Fire(player)
end

local function onPlayerRemoving(player: Player)
	readyPlayers[player] = nil
end

function PlayerSessionService.Init() end

function PlayerSessionService.Start()
	maid:Give(Remotes.OnServerEvent("ClientReady", onClientReady))
	-- Only the leave event is needed: a player has no state here until their
	-- client reports ready, so there is nothing to set up when they join.
	maid:Give(Players.PlayerRemoving:Connect(onPlayerRemoving))
end

function PlayerSessionService.IsClientReady(player: Player): boolean
	return readyPlayers[player] == true
end

function PlayerSessionService.WhenClientReady(player: Player, callback: (player: Player) -> ())
	if readyPlayers[player] then
		task.spawn(callback, player)
		return
	end

	-- Wait for this specific player. The connection removes itself when it has
	-- done its job, or when the player leaves without ever becoming ready.
	local readyConnection: Signal.Connection
	local leaveConnection: RBXScriptConnection

	readyConnection = PlayerSessionService.ClientReady:Connect(function(readyPlayer: Player)
		if readyPlayer ~= player then
			return
		end
		readyConnection:Disconnect()
		leaveConnection:Disconnect()
		callback(player)
	end)

	leaveConnection = Players.PlayerRemoving:Connect(function(leavingPlayer: Player)
		if leavingPlayer == player then
			readyConnection:Disconnect()
			leaveConnection:Disconnect()
		end
	end)
end

return PlayerSessionService
