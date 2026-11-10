--!strict
--[[
	UIConfig

	Purpose
		Shared constants for the user interface, so every screen looks and feels
		consistent and can be restyled from one place.

	Public API
		A read-only table (see the fields below).

	Contract
		- Read-only at runtime (frozen).
		- M1 holds only the mobile-first basics. The screens themselves (M9) add
		  their layout and colour constants here.
		- UI code reads these values; it never hard-codes sizes or colours.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local UIConfig = {
	Touch = {
		-- Smallest allowed size (in pixels) for anything a player taps. Most
		-- Roblox players are on phones; small buttons cause mis-taps.
		minTapTargetPixels = 48,
	},

	Text = {
		-- Smallest text size used anywhere, so text stays readable on a phone.
		minSizePixels = 16,
		bodySizePixels = 20,
		headingSizePixels = 32,
	},
}

return TableUtil.DeepFreeze(UIConfig)
