--!strict
--[[
	FlagConfig

	Purpose
		The default on/off value of every feature flag. A feature flag is a
		named switch that turns a piece of behaviour on or off without deleting
		its code, which makes risky features easy to disable.

	Public API
		A read-only map of flag name -> boolean. Read it through the `Flags`
		module (Shared.Flags), not directly, so that a later milestone (M10) can
		layer live overrides on top without touching the callers.

	Contract
		- Read-only at runtime (frozen).
		- Every flag has a comment saying what it controls and which code reads it.
		- A flag is added by the milestone that first reads it. No placeholder
		  flags for features that do not exist yet.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local FlagConfig: { [string]: boolean } = {
	-- Read by: Shared.Remotes.
	-- When on (and only while testing in Studio), every server-to-client
	-- message is checked against its declared schema and a warning is logged on
	-- a mismatch. It catches programming mistakes early; it is not a security
	-- feature (the server is trusted).
	ValidateOutboundRemotes = true,
}

return TableUtil.DeepFreeze(FlagConfig)
