#! /usr/bin/luajit

local function config()
	math.randomseed(os.time())
	_G.RUMCAJS = {}
	_G.RUMCAJS.root_dir = "/home/fuxoft/work/web/private/rumcajs/"
	_G.RUMCAJS.app_dir = RUMCAJS.root_dir.."apps/"
end

local function main()

	config()
	setmetatable(_G,{__index=function (tbl,key)
    	error("Attempt to access undefined global variable "..tostring(key),2)
	end})

	package.path = package.path..";"..RUMCAJS.root_dir.."lib/?.lua"
	_G.LOG = require("log")
	local TASKER = require("tasker")

--[[	local loadlib = function(libname)
		assert(not libname:match("/"))
		return require(libname)
	end]]

	function RUMCAJS.i_died(mod, error)
		local mod = tostring(mod)
		local error = tostring(error)
		LOG.error("Rumcajs crash in '%s': %s", mod, error)
		LOG.info("Aborting because of crash in '%s'.", mod)
		os.exit()
	end


	local function start_apps()
	    RUMCAJS.apps = {}
	    local fd = io.popen("ls "..RUMCAJS.app_dir.."/*.lua","r")
	    local txt = fd:read("*a")
	    fd:close()
	    local appids = {}
	    for id in txt:gmatch("/([^/%s]+)%.lua") do
	        table.insert(appids,id)
	    end
	    table.sort(appids)
	    LOG.debug("Starting all apps")
	    for i, appid in ipairs(appids) do
	        LOG.debug("Starting app: "..appid)
	        local app = dofile(RUMCAJS.app_dir..appid..".lua")
	        assert(app)
	        RUMCAJS.apps[appid] = {module = app}
	        local startfn = app.start
	        assert(type(startfn) == "function", "App "..appid.." does not provide start() function.")
	        TASKER.add_pthread(appid,startfn)
	        LOG.debug("Started app: "..appid)
	        --RUMCAJS.apps[appid].fiber = fib
	    end
	end

	start_apps()
	TASKER.loop()

	LOG.info("Tasker loop ended, exiting normally.")

end

main()
