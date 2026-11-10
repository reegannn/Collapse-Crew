--!strict
--[[
	PlayerUtil

	Purpose
		Helpers for working with Player objects. Its main job is to make the
		classic Roblox mistake impossible: connecting to Players.PlayerAdded
		AFTER some players have already joined, and so never noticing them.

	Public API
		PlayerUtil.ObservePlayers(onAdded, onRemoving?) -> stop
			Calls onAdded(player) for every player already in the server and for
			every player who joins later. Calls onRemoving(player) when a player
			leaves. Returns a `stop` function that disconnects both; give it to
			a Maid.

	Contract
		- onAdded runs in its own thread for players who were already present,
		  so one slow callback does not delay the others.
		- Each player is reported exactly once: the connection is made and the
		  existing players are listed in the same step, with no pause between.
		- Works on both server and client (on the client it observes all
		  players the client knows about, including the local player).
]]

local Players = game:GetService("Players")

local PlayerUtil = {}

function PlayerUtil.ObservePlayers(
	onAdded: (player: Player) -> (),
	onRemoving: ((player: Player) -> ())?
): () -> ()
	local connections: { RBXScriptConnection } = {}

	table.insert(connections, Players.PlayerAdded:Connect(onAdded))
	if onRemoving ~= nil then
		table.insert(connections, Players.PlayerRemoving:Connect(onRemoving))
	end

	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return PlayerUtil
