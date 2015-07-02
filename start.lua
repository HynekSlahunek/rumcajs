#! /usr/bin/env luajit

local function config()
	math.randomseed(os.time())
	_G.RUMCAJS = {}
	_G.RUMCAJS.root_dir = "/home/fuxoft/work/web/private/rumcajs/"
	_G.RUMCAJS.app_dir = RUMCAJS.root_dir.."apps/"
end

local function main()

	config()

	package.path = package.path..";"..RUMCAJS.root_dir.."lib/?.lua"
	_G.LOG = require("log")
	local TASKER = require("tasker")

--[[	local loadlib = function(libname)
		assert(not libname:match("/"))
		return require(libname)
	end]]


	local function start_apps()
	    RUMCAJS.apps = {}
	    local fd = assert(io.popen("ls "..RUMCAJS.app_dir.."*.lua"))
	    local txt = fd:read("*a")
	    fd:close()
	    local appids = {}
	    for id in txt:gmatch("/([^/%s]+)%.lua") do
	        table.insert(appids,id)
	    end
	    table.sort(appids)
	    LOG.debug("Starting apps")
	    for i, appid in ipairs(appids) do
	        LOG.debug("Starting app: "..appid)
	        local app = dofile(RUMCAJS.app_dir..appid..".lua")
	        assert(app)
	        RUMCAJS.apps[appid] = {module = app}
	        local startfn = app.start
	        assert(type(startfn) == "function", "App "..appid.." does not provide start() function.")
	        TASKER.add_pthread(startfn)
	        LOG.debug("Started app: "..appid)
	        --RUMCAJS.apps[appid].fiber = fib
	    end
	end

	start_apps()
	TASKER.loop()
--[[
	local serverfn = function(sock)
		LOG.debug("New connection: "..tostring(sock))

		local function remote_error(txt)
			PACKET.encode({error = "Shelob error: "..tostring(txt)}, sock)
		end

		local got = PACKET.decode(sock)
		--print("got: "..tostring(got))
		--print("fiber "..tostring(FIBER.self()).." waiting")
		--FIBER.sleep(1)

		if type(got) ~= "table" then
			remote_error("Didn't get table but "..type(got))
			return
		end

		if not next(got) then
			remote_error("Don't know what to do with empty table")
			return
		end

		--We got table!

		if got.ping ~= nil then
			PACKET.encode({pong=got.ping},sock)
			return
		else
			local keys = {}
			for k,v in pairs(got) do
				table.insert(keys, tostring(k))
			end
			remote_error("Don't know what to do with table with following "..#keys.." keys: "..table.concat(keys, " "))
		end
	end
]]

	--[[
	SOCKET.tcp_server('unix/', '/tmp/shelob.socket', serverfn)

	local srcmonitor = loadlib("source_code_monitor")
	FIBER.create(srcmonitor.watch)

	while true do
		local sysmsg = RUMCAJS.system_channel:get()
		LOG.debug("Sysmsg: "..tostring(sysmsg))
		if sysmsg == "lib_sources_changed" then
			err_fun = function(errstat)
				local tback = debug.traceback(errstat)
				tback = tback:gsub("/home/fuxoft/work/web/private/.-/", "..../")
				return tback
			end
			RUMCAJS.main.stop_all_apps()
			package.loaded.main = nil
			RUMCAJS.main = nil
			local stat, mod = xpcall(function() return loadlib("main") end, err_fun)
			if stat then
				RUMCAJS.main = mod
			else
				LOG.error("****** Compilation error \n"..mod)
			end
		end
	end
]]

end

main()
