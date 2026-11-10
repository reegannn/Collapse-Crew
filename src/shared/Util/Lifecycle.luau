--!strict
--[[
	Lifecycle

	Purpose
		The start-up routine shared by the server Bootstrap (for Services) and
		the client Bootstrap (for Controllers). It loads modules in a fixed,
		written-down order and runs their two start-up steps.

	The two steps, and why there are two
		1. Init()  - "get yourself ready". Create your own state and signals.
		             Must NOT pause (yield) and must NOT call other services,
		             because they may not be ready yet.
		2. Start() - "begin working". Every module has finished Init by now, so
		             it is safe to call other services, connect to their signals,
		             connect remote handlers and start loops. Start may pause.

		Splitting start-up this way removes "who loads first?" bugs: by the time
		anyone talks to anyone else, everyone exists.

	Public API
		Lifecycle.Run(label, container, order)
			label      Name used in log messages, e.g. "Server".
			container  The Folder holding the ModuleScripts.
			order      Module names, in the order to load, Init and Start them.

	Contract
		- All Init() calls run one after another, in order, and finish before
		  any Start() runs.
		- Each Start() runs in its own thread, started in order. Code at the top
		  of a Start (before its first pause) therefore runs in list order.
		- A module that is missing, fails to load, or errors in Init is logged
		  (with a stack trace where one is available) and skipped: its Start is
		  not called. The rest still start, so one broken module does not take
		  the whole game down.
		- By convention every Service/Controller defines both Init and Start
		  (see Types.Service). If one is absent it is simply skipped.
		- Run itself returns as soon as every Start has been launched.
]]

local Logger = require(script.Parent.Logger)

-- `require` with a path chosen at runtime cannot be type-checked, so it is
-- called through an untyped alias to keep --!strict quiet.
local dynamicRequire = require :: any

type LoadedModule = {
	name: string,
	module: any,
}

local Lifecycle = {}

local function loadModules(log: Logger.Logger, container: Instance, order: { string }): { LoadedModule }
	local loaded: { LoadedModule } = {}

	for _, name in order do
		local moduleScript = container:FindFirstChild(name)
		if moduleScript == nil or not moduleScript:IsA("ModuleScript") then
			log:Error("%q is in the load order but was not found in %s", name, container:GetFullName())
			continue
		end

		-- TODO(verify-in-studio): pcall(require, moduleScript) returns false (rather than halting this script) when the module has an error.
		local ok, result = pcall(dynamicRequire, moduleScript)
		if not ok then
			log:Error("%q failed to load: %s", name, tostring(result))
			continue
		end
		if type(result) ~= "table" then
			log:Error("%q did not return a table; skipping it", name)
			continue
		end

		table.insert(loaded, { name = name, module = result })
	end

	return loaded
end

local function initModules(log: Logger.Logger, loaded: { LoadedModule }): { LoadedModule }
	local ready: { LoadedModule } = {}

	for _, entry in loaded do
		local init = entry.module.Init
		if type(init) ~= "function" then
			table.insert(ready, entry)
			continue
		end

		local ok, problem = xpcall(init, debug.traceback)
		if ok then
			table.insert(ready, entry)
		else
			log:Error("%s.Init failed, so it will not be started: %s", entry.name, tostring(problem))
		end
	end

	return ready
end

local function startModules(log: Logger.Logger, ready: { LoadedModule })
	for _, entry in ready do
		local start = entry.module.Start
		if type(start) ~= "function" then
			continue
		end

		task.spawn(function()
			local ok, problem = xpcall(start, debug.traceback)
			if not ok then
				log:Error("%s.Start failed: %s", entry.name, tostring(problem))
			end
		end)
	end
end

function Lifecycle.Run(label: string, container: Instance, order: { string })
	local log = Logger.new(label)

	local loaded = loadModules(log, container, order)
	local ready = initModules(log, loaded)
	startModules(log, ready)

	log:Info("Started %d of %d modules", #ready, #order)
end

return Lifecycle
