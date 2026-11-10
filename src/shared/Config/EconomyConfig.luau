--!strict
--[[
	EconomyConfig

	Purpose
		Tunable numbers for coins and XP.

	Public API
		A read-only table (see the fields below).

	Contract
		- Read-only at runtime (frozen).
		- M1 holds only the basic limits. Saving and transactions (M2) and
		  rewards, levels and prices (M7) add their tunables here.
		- All coin changes happen on the server through EconomyService (M2);
		  the client only ever reads these values for display.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local EconomyConfig = {
	Coins = {
		-- What a brand-new player starts with.
		startingAmount = 0,

		-- Safety ceiling on a player's balance. A balance above this can only be
		-- a bug or an exploit, so the server clamps to it.
		maxBalance = 999_999_999,

		-- Safety ceiling on a single grant or spend, for the same reason.
		maxPerTransaction = 1_000_000,
	},
}

return TableUtil.DeepFreeze(EconomyConfig)
