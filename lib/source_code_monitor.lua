TODO








--Monitors source code changes
local _M = {}

local function ls()
	local command = "ls -Rl ".._G.SHELOB.root_dir.."/lib | sha1sum"
	local fd = assert(io.popen(command))
	local current = assert(fd:read("*a"))
	fd:close()
	return current
end

_M.watch = function()
	local FIBER = require("fiber")
	local prev = ls()
	while true do
		FIBER.sleep(1)
		local current = ls()
		if prev ~= current then
			_G.SHELOB.system_channel:put("lib_sources_changed")
			prev = current
		end
	end
end

return _M
