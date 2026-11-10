--!strict
--[[
	TableUtil

	Purpose
		Common table operations that Luau does not provide out of the box.

	Public API
		TableUtil.DeepCopy(value) -> copy
			A fully independent copy of a table and every table inside it.
		TableUtil.Reconcile(target, template) -> target
			Fills in any keys that `template` has and `target` lacks (deeply),
			WITHOUT overwriting anything already in `target`. Used to add new
			default fields to older saved player data.
		TableUtil.DeepFreeze(value) -> value
			Makes a table and everything inside it read-only. Used by Config
			modules so settings cannot be changed by accident at runtime.
		TableUtil.Count(dictionary) -> number     Number of keys (works for non-arrays).
		TableUtil.IsEmpty(dictionary) -> boolean
		TableUtil.Keys(dictionary) -> { keys }    Order is not guaranteed.
		TableUtil.Values(dictionary) -> { values }   Order is not guaranteed.
		TableUtil.Shuffle(array, random) -> array
			Returns a NEW array in random order. `random` is a Random object so
			the caller controls the seed (needed for the date-seeded Daily Expedition).

	Contract
		- Intended for plain data tables only: no metatables, and no table that
		  contains itself (DeepCopy/DeepFreeze/Reconcile would never finish).
		- Nothing here yields.
		- This module depends on nothing else, so any module may require it.
]]

local TableUtil = {}

function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = TableUtil.DeepCopy(child)
	end
	return (copy :: any) :: T
end

function TableUtil.Reconcile<T>(target: T, template: { [any]: any }): T
	local targetTable = target :: any
	for key, templateValue in template do
		local existing = targetTable[key]
		if existing == nil then
			targetTable[key] = TableUtil.DeepCopy(templateValue)
		elseif type(existing) == "table" and type(templateValue) == "table" then
			TableUtil.Reconcile(existing, templateValue)
		end
	end
	return target
end

function TableUtil.DeepFreeze<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local asTable = value :: any
	for _, child in asTable do
		TableUtil.DeepFreeze(child)
	end
	if not table.isfrozen(asTable) then
		table.freeze(asTable)
	end
	return value
end

function TableUtil.Count(dictionary: { [any]: any }): number
	local count = 0
	for _ in dictionary do
		count += 1
	end
	return count
end

function TableUtil.IsEmpty(dictionary: { [any]: any }): boolean
	return next(dictionary) == nil
end

function TableUtil.Keys<K, V>(dictionary: { [K]: V }): { K }
	local keys = {}
	for key in dictionary do
		table.insert(keys, key)
	end
	return keys
end

function TableUtil.Values<K, V>(dictionary: { [K]: V }): { V }
	local values = {}
	for _, value in dictionary do
		table.insert(values, value)
	end
	return values
end

function TableUtil.Shuffle<T>(array: { T }, random: Random): { T }
	local shuffled = table.clone(array)
	-- Fisher-Yates shuffle: walk backwards, swapping each slot with a random earlier one.
	for index = #shuffled, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
	end
	return shuffled
end

return TableUtil
