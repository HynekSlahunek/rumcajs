local _M = {}

--[[host entry:
.valid_until = (time)
.ips = table of ips
]]

local replacer = function(a,x,b)
	return a.._M.resolve_host(x)..(b or "")
end

_M.get_ips = function(host) --Actually get IPs from the OS
	host = host:lower()
	assert(host:match("%l"), "Host name contains no letters: "..host)

	local fd = assert(io.popen("host "..host))
	local txt = fd:read("*a")
	fd:close()
	local ips = {}
	for ip in txt:gmatch("has address (%d+%.%d+%.%d+%.%d+)") do
		table.insert(ips,ip)
	end
	table.sort(ips)
	if #ips == 0 then
		error("Cannot resolve host: "..host)
	end
	return ips
end

_M.resolve_host = function(host)
	host = host:lower()
	local ostime = os.time()
	local item = _M.hosts[host]
	if not item or item.valid_until < ostime then
		--LOG.debug("Host not cached.")
		local ips = _M.get_ips(host)
		item = {valid_until = ostime + 60*60*12} --12 hours
		item.ips = ips
		_M.hosts[host] = item
	else
		--LOG.debug("Host cached.")
	end
	local ips = item.ips
	local ip = ips[math.random(#ips)]
	return ip
end

_M.resolve_url = function(txt)
	local replaced,n = txt:gsub("^(.-://)(.-)(/.+)",replacer)
	if n ~= 1 then
		replaced,n = txt:gsub("^(.-://)(.-)(%?.+)",replacer)
		if n ~=1 then
			replaced,n = txt:gsub("^(.-://)(.+)",replacer)
			if n ~= 1 then
				error("Cannot resolve URL: "..txt)
			end
		end
	end
	return replaced
end

local function init()
	_M.hosts = {}
end

init()
return _M
