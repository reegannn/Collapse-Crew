--!strict
--[[
	Remotes/Definitions

	Purpose
		The complete, declarative list of every network message ("remote") in
		the game. If a message is not declared here, it does not exist: the
		Remotes module only creates and accepts what this table describes.

	Public API
		A table of remote name -> RemoteDefinition.

	Each definition has
		kind         "Event"    = one-way message, no reply.
		             "Function" = request that waits for a reply. Only ever
		                          client -> server (the server never waits on a
		                          client, because a client could stall it forever).
		direction    "ClientToServer" or "ServerToClient".
		args         One Schema validator per argument, in order.
		rateLimit    Required in practice for ClientToServer: how often ONE player
		             may send it. Falls back to GameConfig.Remotes.defaultRateLimit.
		description  What the message means, in plain words.

	Rules for adding a remote
		1. Client -> server arguments must use strict validators (never
		   Schema.Table or Schema.Any) and must be the minimum needed. Send
		   "what the player did" ("pressed switch X"), never "what should
		   happen" ("give me 50 coins").
		2. Function handlers return (ok: boolean, payload). `payload` is the
		   result on success or a short reason code on failure.
		3. Every remote added here must also be added to the remote audit table
		   in docs/SECURITY.md (created in M11).

	Contract
		- Pure data. Requiring this module has no side effects.
]]

local Schema = require(script.Parent.Schema)

export type RateLimit = {
	burst: number,
	perSecond: number,
}

export type RemoteDefinition = {
	kind: "Event" | "Function",
	direction: "ClientToServer" | "ServerToClient",
	args: { Schema.Validator },
	rateLimit: RateLimit?,
	description: string,
}

local Definitions: { [string]: RemoteDefinition } = {
	ClientReady = {
		kind = "Event",
		direction = "ClientToServer",
		args = {},
		-- Sent once per session; the tiny allowance only tolerates a retry.
		rateLimit = { burst = 2, perSecond = 0.1 },
		description = "The client has finished starting up and is ready to receive game state.",
	},
}

return Definitions
