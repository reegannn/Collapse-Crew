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
			once when they become ready. If the player leaves first, or has
			already left when this is called, the callback never runs and
			nothing is kept waiting.

	Contract
		- Server only.
		- "Ready" is a courtesy signal from the client about its own start-up.
		  It grants nothing: no rewards, data or permissions depend on it, so a
		  cheater gains nothing by sending or withholding it.
		- A client that never reports ready (for example because its networking
		  failed to start) is simply never sent pushed state. Nothing waits on it.
		- All per-player state is removed when the player leaves.
		- This service runs for the whole life of the server, so its Maid is
		  never cleaned. It exists to keep the connections it owns in one place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Maid = require(Shared.Util.Maid)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

type ReadyCallback = (player: Player) -> ()

local PlayerSessionService = {}

PlayerSessionService.ClientReady = Signal.new() :: Signal.Signal<Player>

local maid = Maid.new()

-- Both tables are keyed by Player and emptied for a player in onPlayerRemoving.
local readyPlayers: { [Player]: boolean } = {}
local waitingCallbacks: { [Player]: { ReadyCallback } } = {}

local function onClientReady(player: Player)
	if readyPlayers[player] then
		return
	end
	readyPlayers[player] = true

	local callbacks = waitingCallbacks[player]
	waitingCallbacks[player] = nil

	PlayerSessionService.ClientReady:Fire(player)
	if callbacks ~= nil then
		for _, callback in callbacks do
			task.spawn(callback, player)
		end
	end
end

local function onPlayerRemoving(player: Player)
	readyPlayers[player] = nil
	waitingCallbacks[player] = nil
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

function PlayerSessionService.WhenClientReady(player: Player, callback: ReadyCallback)
	if readyPlayers[player] then
		task.spawn(callback, player)
		return
	end

	-- A player who has already left will never become ready. Storing a
	-- callback for them would keep it (and the Player) in memory forever,
	-- because their PlayerRemoving has already happened.
	-- TODO(verify-in-studio): a Player's Parent is nil once they have left (same assumption as Remotes.acceptCall).
	if player.Parent == nil then
		return
	end

	local callbacks = waitingCallbacks[player]
	if callbacks == nil then
		callbacks = {}
		waitingCallbacks[player] = callbacks
	end
	table.insert(callbacks, callback)
end

return PlayerSessionService
