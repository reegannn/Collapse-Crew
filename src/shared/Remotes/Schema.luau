--!strict
--[[
	Remotes/Schema

	Purpose
		Building blocks for describing what arguments a network message is
		allowed to carry. The server uses these to check every message a client
		sends, because a cheating client can send absolutely anything.

	What a validator is
		A function that takes one value and answers (true, nil) if the value is
		acceptable, or (false, reason) if it is not. The functions below build
		validators; a remote's schema is simply a list of them, one per argument.

	Public API (each returns a validator)
		Schema.String(options?)       text; options = { minLength?, maxLength? }
		Schema.Number(options?)       number; options = { min?, max?, integer? }
		                              Always rejects NaN and infinity.
		Schema.Integer(min, max)      whole number in [min, max]
		Schema.Boolean()              true or false
		Schema.Enum(allowed)          a string that is exactly one of `allowed`
		Schema.InstanceOf(className)  a Roblox Instance of that class (or a subclass)
		Schema.Vector3(maxMagnitude?) a Vector3 with no NaN parts, optionally length-limited
		Schema.Array(element, maxLength?)  a list (1..n, no gaps) whose items pass `element`
		Schema.Optional(validator)    nil, or a value that passes `validator`
		Schema.Table()                any table      } ONLY for server-to-client remotes.
		Schema.Any()                  any value      } Never use these for client input.

		Schema.ValidateArgs(validators, packedArgs) -> (ok, reason?)
			Checks a whole argument list (`packedArgs` comes from table.pack(...)).
			Fails if there are more arguments than validators, or if any argument
			fails its validator. Missing trailing arguments are checked as nil,
			so they pass only if their validator is Optional.

	Contract
		- Validators never yield and never throw.
		- Validators only answer yes/no. They never change the value.
		- Default size limits come from GameConfig.Remotes.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local remoteConfig = GameConfig.Remotes

export type Validator = (value: any) -> (boolean, string?)

export type StringOptions = {
	minLength: number?,
	maxLength: number?,
}

export type NumberOptions = {
	min: number?,
	max: number?,
	integer: boolean?,
}

export type PackedArgs = { n: number, [number]: any }

local Schema = {}

function Schema.String(options: StringOptions?): Validator
	local minLength = 0
	local maxLength = remoteConfig.defaultMaxStringLength
	if options ~= nil then
		minLength = options.minLength or minLength
		maxLength = options.maxLength or maxLength
	end

	return function(value: any): (boolean, string?)
		if type(value) ~= "string" then
			return false, "expected a string, got " .. typeof(value)
		end
		local length = #value
		if length < minLength or length > maxLength then
			return false, string.format("string length %d is outside %d-%d", length, minLength, maxLength)
		end
		return true, nil
	end
end

function Schema.Number(options: NumberOptions?): Validator
	local min = -math.huge
	local max = math.huge
	local integerOnly = false
	if options ~= nil then
		min = options.min or min
		max = options.max or max
		integerOnly = options.integer == true
	end

	return function(value: any): (boolean, string?)
		if type(value) ~= "number" then
			return false, "expected a number, got " .. typeof(value)
		end
		-- NaN ("not a number") is the only value that is not equal to itself.
		-- It and infinity slip past ordinary range checks, so reject them first.
		if value ~= value then
			return false, "number is NaN"
		end
		if value == math.huge or value == -math.huge then
			return false, "number is infinite"
		end
		if integerOnly and value % 1 ~= 0 then
			return false, "expected a whole number"
		end
		if value < min or value > max then
			return false, string.format("number %s is outside %s to %s", tostring(value), tostring(min), tostring(max))
		end
		return true, nil
	end
end

function Schema.Integer(min: number, max: number): Validator
	return Schema.Number({ min = min, max = max, integer = true })
end

function Schema.Boolean(): Validator
	return function(value: any): (boolean, string?)
		if type(value) ~= "boolean" then
			return false, "expected a boolean, got " .. typeof(value)
		end
		return true, nil
	end
end

function Schema.Enum(allowed: { string }): Validator
	local lookup: { [string]: boolean } = {}
	for _, option in allowed do
		lookup[option] = true
	end

	return function(value: any): (boolean, string?)
		if type(value) ~= "string" then
			return false, "expected a string option, got " .. typeof(value)
		end
		if not lookup[value] then
			return false, "string is not one of the allowed options"
		end
		return true, nil
	end
end

function Schema.InstanceOf(className: string): Validator
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Instance" then
			return false, "expected an Instance, got " .. typeof(value)
		end
		if not value:IsA(className) then
			return false, string.format("expected a %s, got a %s", className, value.ClassName)
		end
		return true, nil
	end
end

function Schema.Vector3(maxMagnitude: number?): Validator
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Vector3" then
			return false, "expected a Vector3, got " .. typeof(value)
		end
		if value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z then
			return false, "Vector3 contains NaN"
		end
		local magnitude = value.Magnitude
		if magnitude == math.huge then
			return false, "Vector3 is infinite"
		end
		if maxMagnitude ~= nil and magnitude > maxMagnitude then
			return false, "Vector3 is longer than allowed"
		end
		return true, nil
	end
end

function Schema.Array(element: Validator, maxLength: number?): Validator
	local limit = maxLength or remoteConfig.defaultMaxArrayLength

	return function(value: any): (boolean, string?)
		if type(value) ~= "table" then
			return false, "expected a list, got " .. typeof(value)
		end

		local length = #value
		if length > limit then
			return false, string.format("list has %d items; at most %d allowed", length, limit)
		end

		-- Count every key. If there are more keys than list slots, the table
		-- has extra (non-list) keys or gaps, so it is not a clean list.
		local keyCount = 0
		for _ in value do
			keyCount += 1
			if keyCount > length then
				return false, "table is not a plain list"
			end
		end

		for index = 1, length do
			local ok, reason = element(value[index])
			if not ok then
				return false, string.format("item %d: %s", index, reason or "invalid")
			end
		end
		return true, nil
	end
end

function Schema.Optional(validator: Validator): Validator
	return function(value: any): (boolean, string?)
		if value == nil then
			return true, nil
		end
		return validator(value)
	end
end

function Schema.Table(): Validator
	return function(value: any): (boolean, string?)
		if type(value) ~= "table" then
			return false, "expected a table, got " .. typeof(value)
		end
		return true, nil
	end
end

function Schema.Any(): Validator
	return function(_value: any): (boolean, string?)
		return true, nil
	end
end

function Schema.ValidateArgs(validators: { Validator }, packedArgs: PackedArgs): (boolean, string?)
	local expected = #validators
	if packedArgs.n > expected then
		return false, string.format("too many arguments (got %d, at most %d allowed)", packedArgs.n, expected)
	end

	for index = 1, expected do
		local ok, reason = validators[index](packedArgs[index])
		if not ok then
			return false, string.format("argument %d: %s", index, reason or "invalid")
		end
	end
	return true, nil
end

return Schema
