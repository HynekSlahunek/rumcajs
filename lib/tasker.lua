--Tasker

local _M = {}

local COPAS = require("copas")
local DNS = require("dns")

_M.sleep = assert(COPAS.sleep)
_M.loop = assert(COPAS.loop)
_M.add_thread = assert(COPAS.addthread)
_M.http_request = function(a,b,c,d,e,f,g,h)
    if type(a) == "string" then
        --LOG.debug("Resolving:%s",a)
        a = DNS.resolve_url(a)
        --LOG.debug("Resolved: %s",a)
    end
    return require("copas.http").request(a,b,c,d,e,f,g,h)
end

local err_fun = function(errstat)
    local tback = debug.traceback(errstat)
    tback = tback:gsub("/home/fuxoft/work/web/private/rumcajs/", "..../")
    LOG.error(tback)
end

_M.add_pthread = function(id,fn,a,b,c,d,e)
    assert(type(id)=="string", "Missing string id when calling TASKER.add_pthread().")

    local err_fun = function(errstat)
        local tback = debug.traceback(errstat)
        tback = tback:gsub("/home/fuxoft/work/web/private/rumcajs/", "..../")
        RUMCAJS.i_died(id,tback)
    end

    local pfun = function()
        return fn(a,b,c,d,e)
    end

    COPAS.addthread(function()
        xpcall(pfun, err_fun)
    end)
end

return _M
