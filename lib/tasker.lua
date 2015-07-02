--Tasker

local _M = {}

local COPAS = require("copas")

_M.sleep = assert(COPAS.sleep)
_M.loop = assert(COPAS.loop)
_M.add_thread = assert(COPAS.addthread)
_M.http_request = require("copas.http").request

local err_fun = function(errstat)
    local tback = debug.traceback(errstat)
    tback = tback:gsub("/home/fuxoft/work/web/private/rumcajs/", "..../")
    LOG.error(tback)
end

_M.add_pthread = function(fn,a,b,c,d,e)
    local pfun = function()
        return fn(a,b,c,d,e)
    end

    COPAS.addthread(function()
        xpcall(pfun, err_fun)
    end)
end

return _M
