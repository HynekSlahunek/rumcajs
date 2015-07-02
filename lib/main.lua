--Shelob soft init

--[[ SHELOB.apps...
    .fiber
    .module

Apps API:
    .start()

]]

local _M = {}
local LOG = require('log')

function stop_all_apps()
    for appid, app in pairs(SHELOB.app) do
        local stopfun = app.module.stop
        if stop then
            stop()
        end
    end
end

local function start_apps()
    local FIBER = require("fiber")
    SHELOB.apps = {}
    local fd = assert(io.popen("ls "..SHELOB.app_dir.."*.lua"))
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
        local app = dofile(SHELOB.app_dir..appid..".lua")
        assert(app)
        SHELOB.apps[appid] = {module = app}
        local startfn = app.start
        assert(type(startfn) == "function", "App "..appid.." does not provide start() function.")
        local fib = assert(FIBER.create(app.start))
        LOG.debug("Started app: "..appid)
        SHELOB.apps[appid].fiber = fib
    end
end

local function main()
    SHELOB.system_channel:put("shelob_running")
    start_apps()
end

main()
return _M
