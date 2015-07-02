#! /usr/bin/env tarantool
--communicate with Shelob

local _M = {}

_M.socket = "/tmp/shelob.socket"

local PACKET = dofile("lib/packet.lua")

_M.raw_request = function(object)
	local tmpfile = os.tmpname()
	local tmp = assert(io.open(tmpfile,"w"))
	PACKET.encode(object, tmp)
	tmp:close()
	local nc = assert(io.popen(string.format("cat %s | nc -U -w1 %s ", tmpfile, _M.socket)))
	local result = PACKET.decode(nc)
	nc:close()
	os.remove(tmpfile)
	return result
end

_M.ping = function()
	local payload = os.date()
	local got = _M.raw_request{ping = payload}
	assert(got.pong == payload, "Wrong payload: "..got.pong)
end

local function test()
	local TAP = require("tap")
	_M.ping()
end

if not FFTEMPL then --TEST
	local TAP = require("tap")
	local test = TAP.test("communicate")
	ploads = {123, "ahoj\nlidi", true, false, -123.329, {}, {1,2,3,"ctyri",false}, {{{"hahaha"}}}, }
	--test:plan(#ploads)
	for tnum, payload in ipairs(ploads) do
		local reply = _M.raw_request{ping = payload}
		test:is_deeply(reply.pong, payload, "pinging: "..tostring(payload))
	end
	local reply = test:ok(_M.raw_request({wat="do"}).error:match("what to do with table"), "Invalid table should return error")
	local reply = test:ok(_M.raw_request({}).error:match("empty table"), "Empty table should return error")
	local reply = test:ok(_M.raw_request(123).error:match("table but number"), "Sending number instead of table")
	local reply = test:ok(_M.raw_request({ping = function () return 1 end}).pong:match("encode function"), "Function encoded as error string")

end

return _M
