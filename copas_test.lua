local copas = require("copas")
local asynchttp = require("copas.http").request

local list = {
  "http://www.google.com",
  "http://www.microsoft.com",
  "http://www.apple.com",
  "http://www.facebook.com",
  "http://www.yahoo.com",
}

local handler = function(host)
  res, err = asynchttp(host)
  if host:match("microsoft") then
      print(a + 7)
  end
  print("Host done: "..host)
end

err_fun = function(errstat)
    local tback = debug.traceback(errstat)
    --tback = tback:gsub("/home/fuxoft/work/web/private/.-/", "..../")
    print(tback)
end


local function handler0(host)
    xpcall(function () handler(host) end, err_fun)
end

local function main()
    for _, host in ipairs(list) do copas.addthread(handler0, host) end
    copas.loop()
end

main()
