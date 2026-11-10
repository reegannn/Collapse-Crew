--!strict
--[[
	Maid

	Purpose
		Keeps a list of things that must be cleaned up later (event connections,
		created instances, running tasks) and cleans them all in one call. This
		is how the game avoids leaks: whatever a round, puzzle or screen creates,
		it hands to its Maid, and destroying the Maid tidies everything.

	Public API
		Maid.new() -> Maid
		maid:Give(item) -> item             Track `item`; returns it for convenience.
		maid:GiveNamed(name, item) -> item  Track `item` under a name. If that name is
		                                    already in use, the old item is cleaned first.
		maid:Clean(name)                    Clean and forget one named item (no-op if absent).
		maid:DoCleaning()                   Clean everything. The Maid can be reused afterwards.
		maid:Destroy()                      Same as DoCleaning (so Maids can be nested).

	What an "item" may be, and how it is cleaned
		function                 -> called with no arguments
		RBXScriptConnection      -> :Disconnect()
		Instance                 -> :Destroy()
		thread (task.spawn etc.) -> task.cancel(), unless it is the thread doing the cleaning
		table with :Destroy()    -> :Destroy()      (Maid, Signal, our own objects)
		table with :Disconnect() -> :Disconnect()   (Signal connections)
		Anything else is ignored with a warning.

	Contract
		- Named items are cleaned first, then unnamed items in reverse order
		  (last given, first cleaned), so later items may depend on earlier ones.
		- A failure cleaning one item is logged and does not stop the rest.
		- Giving an item to a Maid that is in the middle of cleaning is allowed;
		  it lands in the fresh list and is cleaned by the next DoCleaning.
]]

local Logger = require(script.Parent.Logger)

local log = Logger.new("Maid")

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable(
	{} :: {
		_items: { any },
		_named: { [string]: any },
	},
	Maid
))

local function cleanItem(item: any)
	local kind = typeof(item)

	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		-- A thread cannot cancel itself, and cancelling a finished thread is pointless.
		-- TODO(verify-in-studio): task.cancel on a suspended or task.wait-ing thread stops it without raising an error.
		if item ~= coroutine.running() and coroutine.status(item) ~= "dead" then
			task.cancel(item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		else
			log:Warn("Maid was given a table with no Destroy or Disconnect method; nothing to clean")
		end
	else
		log:Warn("Maid does not know how to clean a value of type %s", kind)
	end
end

local function safeClean(item: any)
	local ok, problem = pcall(cleanItem, item)
	if not ok then
		log:Warn("Cleanup of one item failed: %s", tostring(problem))
	end
end

function Maid.new(): Maid
	return setmetatable({ _items = {}, _named = {} }, Maid)
end

function Maid.Give<T>(self: Maid, item: T): T
	table.insert(self._items, item)
	return item
end

function Maid.GiveNamed<T>(self: Maid, name: string, item: T): T
	Maid.Clean(self, name)
	self._named[name] = item
	return item
end

function Maid.Clean(self: Maid, name: string)
	local item = self._named[name]
	if item == nil then
		return
	end
	self._named[name] = nil
	safeClean(item)
end

function Maid.DoCleaning(self: Maid)
	-- Swap in fresh tables first, so anything given during cleanup is kept
	-- for the next round instead of being lost or cleaned twice.
	local named = self._named
	local items = self._items
	self._named = {}
	self._items = {}

	for _, item in named do
		safeClean(item)
	end
	for index = #items, 1, -1 do
		safeClean(items[index])
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
