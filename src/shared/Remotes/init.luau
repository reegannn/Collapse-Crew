--!strict
--[[
	Remotes

	Purpose
		The single doorway for all network messages between a player's device
		(client) and the server. Game code never creates or touches RemoteEvents
		directly; it goes through this module, which guarantees that every
		message from a client is:
			1. declared in Remotes/Definitions (unknown messages do not exist),
			2. rate-limited per player (Remotes/RateLimiter), and
			3. checked against its schema (Remotes/Schema)
		BEFORE any game code sees it. Messages that fail are ignored silently
		(they are only noted in the Debug log), so a cheater learns nothing.

	Public API - server
		Remotes.InitServer()
			Creates the remote instances. Called once by the server Bootstrap
			before any Service starts.
		Remotes.OnServerEvent(name, handler) -> RBXScriptConnection
			handler(player, ...) runs for each valid, in-limit client message.
		Remotes.OnServerInvoke(name, handler)
			handler(player, ...) must return (ok: boolean, payload). Rejected
			calls answer (false, "Rejected"); a handler error answers
			(false, "ServerError") and is logged.
		Remotes.FireClient(name, player, ...)     Players who have left are skipped.
		Remotes.FireClients(name, players, ...)
		Remotes.FireAllClients(name, ...)
		Remotes.ReportUnhandled()
			Logs a warning for every client-to-server remote that no service has
			connected a handler to. Called by the server Bootstrap after start-up.

	Public API - client
		Remotes.InitClient()
			Waits for the server-created remotes. Called once by the client
			Bootstrap before any Controller starts. Yields.
		Remotes.FireServer(name, ...)
		Remotes.InvokeServer(name, ...) -> (ok: boolean, payload)
			Yields until the server answers. Never throws: a network failure
			returns (false, "InvokeFailed").
		Remotes.OnClientEvent(name, handler) -> RBXScriptConnection

	Contract
		- Using a name that is not declared, or using a remote in the wrong
		  direction/kind, is a programming mistake and raises an error straight
		  away (at start-up, when handlers are connected), so typos are found
		  immediately rather than failing silently in play.
		- Server handlers are only called for players still in the server.
		- Connect server handlers in a Service's Start(), before its first yield,
		  so that ReportUnhandled sees them.
		- The server never invokes a client (no RemoteFunction calls towards
		  clients): a client could simply never answer and stall the server.
		- Validation of server-to-client messages is a development aid only
		  (Studio + the ValidateOutboundRemotes flag); the server is trusted.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flags = require(script.Parent.Flags)
local GameConfig = require(script.Parent.Config.GameConfig)
local Logger = require(script.Parent.Util.Logger)

local Definitions = require(script.Definitions)
local RateLimiter = require(script.RateLimiter)
local Schema = require(script.Schema)

type RemoteDefinition = Definitions.RemoteDefinition

local log = Logger.new("Remotes")
local remoteConfig = GameConfig.Remotes

local REJECTED = "Rejected"
local SERVER_ERROR = "ServerError"
local NOT_IMPLEMENTED = "NotImplemented"
local INVOKE_FAILED = "InvokeFailed"

local remoteInstances: { [string]: Instance } = {}
local rateLimiters: { [string]: RateLimiter.RateLimiter } = {}
local handledRemotes: { [string]: boolean } = {}
local initialised = false

local Remotes = {}

----------------------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------------------

local function getDefinition(name: string, kind: string, direction: string): RemoteDefinition
	local definition = Definitions[name]
	if definition == nil then
		error(string.format("Remotes: %q is not declared in Remotes/Definitions", tostring(name)), 3)
	end
	if definition.kind ~= kind or definition.direction ~= direction then
		error(
			string.format(
				"Remotes: %q is declared as a %s %s, but was used as a %s %s",
				name,
				definition.direction,
				definition.kind,
				direction,
				kind
			),
			3
		)
	end
	return definition
end

local function getInstance(name: string): Instance
	local instance = remoteInstances[name]
	if instance == nil then
		error(
			string.format(
				"Remotes: %q has no instance. Has Remotes.InitServer/InitClient run (and succeeded)?",
				name
			),
			3
		)
	end
	return instance
end

local function requireServer(functionName: string)
	if not RunService:IsServer() then
		error(string.format("Remotes.%s may only be called on the server", functionName), 3)
	end
end

local function requireClient(functionName: string)
	if not RunService:IsClient() then
		error(string.format("Remotes.%s may only be called on the client", functionName), 3)
	end
end

----------------------------------------------------------------------------
-- Server
----------------------------------------------------------------------------

-- Decides whether a client's call may reach game code.
local function acceptCall(name: string, definition: RemoteDefinition, player: Player, ...: any): boolean
	-- A message can still be in the queue when its sender leaves. Dropping it
	-- here also stops per-player state being re-created after cleanup.
	-- TODO(verify-in-studio): a Player's Parent is nil once they have left (after PlayerRemoving handlers have run).
	if player.Parent == nil then
		return false
	end

	local limiter = rateLimiters[name]
	if limiter ~= nil and not limiter:TryConsume(player) then
		log:Debug("Ignored %s from %s: over the rate limit", name, player.Name)
		return false
	end

	local ok, reason = Schema.ValidateArgs(definition.args, table.pack(...))
	if not ok then
		log:Debug("Ignored %s from %s: %s", name, player.Name, tostring(reason))
		return false
	end

	return true
end

local function checkOutbound(name: string, definition: RemoteDefinition, ...: any)
	if not RunService:IsStudio() or not Flags.IsEnabled("ValidateOutboundRemotes") then
		return
	end
	local ok, reason = Schema.ValidateArgs(definition.args, table.pack(...))
	if not ok then
		log:Warn("Server sent %s with arguments that do not match its schema: %s", name, tostring(reason))
	end
end

-- Catches mistakes in Remotes/Definitions at start-up instead of in play.
local function isValidDefinition(name: string, definition: RemoteDefinition): boolean
	if definition.kind ~= "Event" and definition.kind ~= "Function" then
		log:Error("Remote %q has an unknown kind; it was not created", name)
		return false
	end
	if definition.direction ~= "ClientToServer" and definition.direction ~= "ServerToClient" then
		log:Error("Remote %q has an unknown direction; it was not created", name)
		return false
	end
	if definition.kind == "Function" and definition.direction ~= "ClientToServer" then
		log:Error("Remote %q is a server-to-client Function, which is not allowed; it was not created", name)
		return false
	end
	if type(definition.args) ~= "table" then
		log:Error("Remote %q has no argument schema; it was not created", name)
		return false
	end
	return true
end

function Remotes.InitServer()
	requireServer("InitServer")
	if initialised then
		return
	end
	initialised = true

	local folder = Instance.new("Folder")
	folder.Name = remoteConfig.folderName

	for name, definition in Definitions do
		if not isValidDefinition(name, definition) then
			continue
		end

		local remote: Instance
		if definition.kind == "Function" then
			local remoteFunction = Instance.new("RemoteFunction")
			-- Until a service connects the real handler, answer instead of
			-- leaving the calling client waiting forever.
			remoteFunction.OnServerInvoke = function()
				return false, NOT_IMPLEMENTED
			end
			remote = remoteFunction
		else
			remote = Instance.new("RemoteEvent")
		end
		remote.Name = name
		remote.Parent = folder
		remoteInstances[name] = remote

		if definition.direction == "ClientToServer" then
			local limit = definition.rateLimit or remoteConfig.defaultRateLimit
			rateLimiters[name] = RateLimiter.new(limit.burst, limit.perSecond)
		end
	end

	-- Parent the folder last, so clients receive it with its contents in place.
	folder.Parent = ReplicatedStorage

	-- Never disconnected, on purpose: Remotes exists for exactly as long as the
	-- server does, so there is no earlier moment to clean this up.
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, limiter in rateLimiters do
			limiter:RemovePlayer(player)
		end
	end)

	log:Info("Created %d remotes", #folder:GetChildren())
end

function Remotes.OnServerEvent(name: string, handler: (player: Player, ...any) -> ()): RBXScriptConnection
	requireServer("OnServerEvent")
	local definition = getDefinition(name, "Event", "ClientToServer")
	local remote = getInstance(name) :: RemoteEvent
	handledRemotes[name] = true

	return remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if acceptCall(name, definition, player, ...) then
			handler(player, ...)
		end
	end)
end

function Remotes.OnServerInvoke(name: string, handler: (player: Player, ...any) -> (boolean, any))
	requireServer("OnServerInvoke")
	local definition = getDefinition(name, "Function", "ClientToServer")
	local remote = getInstance(name) :: RemoteFunction
	handledRemotes[name] = true

	remote.OnServerInvoke = function(player: Player, ...: any): (boolean, any)
		if not acceptCall(name, definition, player, ...) then
			return false, REJECTED
		end

		-- xpcall keeps an error inside the handler from travelling to the
		-- client (which would leak server details) and records where it happened.
		local results = table.pack(xpcall(handler, debug.traceback, player, ...))
		if not results[1] then
			log:Error("Handler for %s failed: %s", name, tostring(results[2]))
			return false, SERVER_ERROR
		end
		return results[2] == true, results[3]
	end
end

function Remotes.FireClient(name: string, player: Player, ...: any)
	requireServer("FireClient")
	local definition = getDefinition(name, "Event", "ServerToClient")
	local remote = getInstance(name) :: RemoteEvent
	checkOutbound(name, definition, ...)
	-- Sending to a player who has already left is pointless; skip it quietly.
	if player.Parent ~= nil then
		remote:FireClient(player, ...)
	end
end

function Remotes.FireClients(name: string, players: { Player }, ...: any)
	requireServer("FireClients")
	local definition = getDefinition(name, "Event", "ServerToClient")
	local remote = getInstance(name) :: RemoteEvent
	checkOutbound(name, definition, ...)
	for _, player in players do
		if player.Parent ~= nil then
			remote:FireClient(player, ...)
		end
	end
end

function Remotes.FireAllClients(name: string, ...: any)
	requireServer("FireAllClients")
	local definition = getDefinition(name, "Event", "ServerToClient")
	local remote = getInstance(name) :: RemoteEvent
	checkOutbound(name, definition, ...)
	remote:FireAllClients(...)
end

function Remotes.ReportUnhandled()
	requireServer("ReportUnhandled")
	for name, definition in Definitions do
		if definition.direction == "ClientToServer" and not handledRemotes[name] then
			log:Warn("Remote %q is declared but no service has connected a handler for it", name)
		end
	end
end

----------------------------------------------------------------------------
-- Client
----------------------------------------------------------------------------

function Remotes.InitClient()
	requireClient("InitClient")
	if initialised then
		return
	end
	initialised = true

	local timeout = remoteConfig.clientWaitTimeoutSeconds
	local folder = ReplicatedStorage:WaitForChild(remoteConfig.folderName, timeout)
	if folder == nil then
		log:Error("The %s folder did not appear within %d seconds; networking is unavailable", remoteConfig.folderName, timeout)
		return
	end

	for name in Definitions do
		local remote = folder:WaitForChild(name, timeout)
		if remote ~= nil then
			remoteInstances[name] = remote
		else
			log:Error("Remote %q did not appear within %d seconds", name, timeout)
		end
	end
end

function Remotes.FireServer(name: string, ...: any)
	requireClient("FireServer")
	getDefinition(name, "Event", "ClientToServer")
	local remote = getInstance(name) :: RemoteEvent
	remote:FireServer(...)
end

function Remotes.InvokeServer(name: string, ...: any): (boolean, any)
	requireClient("InvokeServer")
	getDefinition(name, "Function", "ClientToServer")
	local remote = getInstance(name) :: RemoteFunction

	local results = table.pack(pcall(function(...: any): ...any
		return remote:InvokeServer(...)
	end, ...))
	if not results[1] then
		log:Warn("InvokeServer %s failed: %s", name, tostring(results[2]))
		return false, INVOKE_FAILED
	end
	return results[2] == true, results[3]
end

function Remotes.OnClientEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	requireClient("OnClientEvent")
	getDefinition(name, "Event", "ServerToClient")
	local remote = getInstance(name) :: RemoteEvent
	return remote.OnClientEvent:Connect(handler)
end

return Remotes
