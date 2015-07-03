--Logger

local _M = {}

local function should_log(level) --log all
    return(true)
end

local function main()
    local levels = {"error", "warn", "info", "debug"}
    local tags = {error = "*!", warn = "W ", info = "i ", debug = "  "}
    for level, id in ipairs(levels) do
        _M[id] = function(str,a,b,c,d,e,f,g,h,i,j)
            str = tostring(str)
            local stat, text = pcall(function ()
                return str:format(a,b,c,d,e,f,g,h,i,j)
            end)
            if not stat then
                text = str
            end
            local tstr = os.date("*t")
            local output = string.format("%s%02d:%02d:%02d %s", tags[id], tstr.hour, tstr.min, tstr.sec, text)
            print(output)
            io.flush()
        end
    end
end

main()
return _M
