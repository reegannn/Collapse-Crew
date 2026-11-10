--!strict
--[[
	Signal

	Purpose
		A lightweight event object written in plain Luau. It lets one module
		announce "something happened" without knowing who is listening. Services
		expose Signals; other services connect to them.

	Public API
		Signal.new() -> Signal<T...>
		signal:Connect(handler) -> Connection   Call `handler` on every Fire.
		signal:Once(handler) -> Connection      Call `handler` on the next Fire only.
		signal:Wait() -> T...                   Pause the current thread until the next Fire.
		signal:Fire(...)                        Call every connected handler with these arguments.
		signal:DisconnectAll()                  Remove every handler.
		signal:Destroy()                        Same as DisconnectAll (so a Maid can clean a Signal).
		connection:Disconnect()                 Stop one handler. Safe to call more than once.
		connection.Connected                    false once disconnected.

	Usage
		local Signal = require(path.to.Signal)
		local coinsChanged = Signal.new() :: Signal.Signal<Player, number>
		coinsChanged:Connect(function(player, coins) ... end)
		coinsChanged:Fire(player, 50)

	Contract
		- Every handler runs in its own thread (task.spawn), so a handler that
		  errors or pauses cannot block the other handlers or the code that fired.
		- Handlers run in the order they were connected.
		- Connecting or disconnecting during a Fire is safe. A handler added
		  during a Fire is first called on the next Fire.
		- Arguments are passed as-is (tables are not copied).
		- A thread paused in Wait() stays paused forever if the signal never
		  fires again. Do not Wait() on a signal that may be destroyed first.
		- DisconnectAll/Destroy only remove the handlers. They do not wake
		  threads paused in Wait(), and the signal can still be connected to and
		  fired afterwards.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type Handler = (...any) -> ()

-- The internals are typed loosely (`any`) on purpose: the public types above
-- are what callers see, and keeping the implementation simple is worth more
-- than fully typing private fields.

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false

	local connections = self._signal._connections
	local index = table.find(connections, self)
	if index ~= nil then
		table.remove(connections, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _connections = {} }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect(self: any, handler: Handler): Connection
	local connection = setmetatable({
		Connected = true,
		_signal = self,
		_handler = handler,
	}, ConnectionClass)
	table.insert(self._connections, connection)
	return (connection :: any) :: Connection
end

function Signal.Once(self: any, handler: Handler): Connection
	local connection: any
	connection = Signal.Connect(self, function(...: any)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Wait(self: any): ...any
	local waitingThread = coroutine.running()
	local connection: any
	connection = Signal.Connect(self, function(...: any)
		connection:Disconnect()
		-- The waiting thread may have been cancelled in the meantime (a Maid
		-- cancels threads it owns). Resuming a finished thread would raise an error.
		-- TODO(verify-in-studio): task.spawn(thread, ...) resumes a thread parked in coroutine.yield(), and yield returns those values.
		if coroutine.status(waitingThread) == "suspended" then
			task.spawn(waitingThread, ...)
		end
	end)
	return coroutine.yield()
end

function Signal.Fire(self: any, ...: any)
	-- Iterate over a copy so handlers may connect or disconnect while firing.
	local snapshot = table.clone(self._connections)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, connection in self._connections do
		connection.Connected = false
	end
	table.clear(self._connections)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
