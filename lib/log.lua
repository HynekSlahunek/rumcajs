--Logger

local _M = {}

local function main()
    local fun = function(str)
        print(str)
    end
    _M.debug = fun
    _M.error = fun
    _M.warn = fun
    _M.info = fun
end

main()
return _M
